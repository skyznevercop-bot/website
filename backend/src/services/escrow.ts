import {
  getMatch,
  updateMatch,
  matchesRef,
  getMatchesByStatus,
  DbMatch,
} from "./firebase";
import {
  fetchGameAccount,
  getConnection,
  GameStatus,
  cancelPendingGameOnChain,
  refundEscrowOnChain,
  closeGameOnChain,
} from "../utils/solana";
import { broadcastToMatch, broadcastToUser } from "../ws/rooms";

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Confirm a player's deposit for a match.
 * Instead of parsing the on-chain tx, we read the Game PDA to check deposit flags.
 * The program's deposit_to_escrow instruction validates & records deposits atomically.
 */
export async function confirmDeposit(
  matchId: string,
  playerAddress: string,
  txSignature: string
): Promise<{ success: boolean; message: string; matchNowActive: boolean }> {
  const match = await getMatch(matchId);
  if (!match) {
    return { success: false, message: "Match not found", matchNowActive: false };
  }

  if (match.status !== "awaiting_deposits") {
    return {
      success: false,
      message: `Match status is '${match.status}', not awaiting deposits`,
      matchNowActive: false,
    };
  }

  const isPlayer1 = playerAddress === match.player1;
  const isPlayer2 = playerAddress === match.player2;
  if (!isPlayer1 && !isPlayer2) {
    return { success: false, message: "You are not a player in this match", matchNowActive: false };
  }

  if (match.depositDeadline && Date.now() > match.depositDeadline) {
    return { success: false, message: "Deposit deadline has passed", matchNowActive: false };
  }

  if (!match.onChainGameId) {
    return { success: false, message: "No on-chain game ID for this match", matchNowActive: false };
  }

  // Confirm the deposit tx on the backend's RPC node (10s cap so we don't
  // stall the HTTP response; the PDA retry loop below handles slower cases).
  try {
    const connection = getConnection();
    const latestBlockhash = await connection.getLatestBlockhash("confirmed");
    await Promise.race([
      connection.confirmTransaction(
        {
          signature: txSignature,
          blockhash: latestBlockhash.blockhash,
          lastValidBlockHeight: latestBlockhash.lastValidBlockHeight,
        },
        "confirmed"
      ),
      sleep(10_000),
    ]);
  } catch (err) {
    console.warn(`[Escrow] Tx ${txSignature} not yet confirmed on backend RPC, proceeding to PDA check`);
  }

  // Read Game PDA to check deposit status, with retries for RPC propagation delay.
  let game = await fetchGameAccount(BigInt(match.onChainGameId));
  if (!game) {
    return { success: false, message: "On-chain game not found", matchNowActive: false };
  }

  let playerDeposited = isPlayer1
    ? game.playerOneDeposited
    : game.playerTwoDeposited;

  // Retry up to 10 times (1s apart) if the deposit flag hasn't propagated yet.
  if (!playerDeposited) {
    for (let attempt = 0; attempt < 10; attempt++) {
      await sleep(1000);
      game = await fetchGameAccount(BigInt(match.onChainGameId));
      if (!game) break;
      playerDeposited = isPlayer1
        ? game.playerOneDeposited
        : game.playerTwoDeposited;
      if (playerDeposited) break;
    }
  }

  if (!game) {
    return { success: false, message: "On-chain game not found", matchNowActive: false };
  }

  if (!playerDeposited) {
    return {
      success: false,
      message: "Deposit transaction may have failed on-chain. Check your wallet and try again.",
      matchNowActive: false,
    };
  }

  // Record the verified deposit in Firebase.
  const update: Partial<DbMatch> = isPlayer1
    ? {
        player1DepositSignature: txSignature,
        player1DepositVerified: true,
      }
    : {
        player2DepositSignature: txSignature,
        player2DepositVerified: true,
      };

  await updateMatch(matchId, update);

  // Notify both players.
  const depositNotification = {
    type: "deposit_confirmed",
    matchId,
    player: playerAddress,
  };
  broadcastToUser(match.player1, depositNotification);
  broadcastToUser(match.player2, depositNotification);

  // Re-read Firebase so we see the updated deposit flags after our write.
  const updatedMatch = (await getMatch(matchId)) ?? match;

  // Check if both players have deposited and the on-chain game is Active.
  // Use Firebase flags as fallback for when the on-chain RPC lags behind
  // and hasn't yet reflected the OTHER player's deposit.
  const bothOnChain = game.playerOneDeposited && game.playerTwoDeposited;
  const bothFirebase =
    !!updatedMatch.player1DepositVerified && !!updatedMatch.player2DepositVerified;

  if ((bothOnChain || bothFirebase) && game.status === GameStatus.Active) {
    return await activateMatch(matchId, updatedMatch, game);
  }

  return {
    success: true,
    message: "Deposit verified. Waiting for opponent.",
    matchNowActive: false,
  };
}

/**
 * Activate a match using a Firebase transaction for atomicity.
 * The on-chain program already set the game to Active; this syncs Firebase.
 */
export async function activateMatch(
  matchId: string,
  match: DbMatch,
  game: { startTime: bigint; endTime: bigint }
): Promise<{ success: boolean; message: string; matchNowActive: boolean }> {
  const matchRef = matchesRef.child(matchId);

  const result = await matchRef.transaction((current: DbMatch | null) => {
    if (!current || current.status !== "awaiting_deposits") return; // abort
    current.status = "active";
    current.escrowState = "deposits_received";
    // On-chain timestamps are in unix seconds; Firebase uses ms.
    current.startTime = Number(game.startTime) * 1000;
    current.endTime = Number(game.endTime) * 1000;
    return current;
  });

  if (!result.committed) {
    return { success: true, message: "Match already activated", matchNowActive: true };
  }

  const snap = result.snapshot.val();
  const activationMsg = {
    type: "match_activated",
    matchId,
    startTime: snap.startTime,
    endTime: snap.endTime,
  };

  broadcastToUser(match.player1, activationMsg);
  broadcastToUser(match.player2, activationMsg);
  broadcastToMatch(matchId, activationMsg);

  console.log(`[Escrow] Match ${matchId} activated: both deposits verified on-chain`);

  return {
    success: true,
    message: "Both deposits verified. Match is now active!",
    matchNowActive: true,
  };
}

/**
 * Process payout after a match is settled on-chain.
 *   - Wins/forfeits: Winner claims via frontend (permissionless claim_winnings).
 *   - Ties: Backend calls refund_escrow to return funds immediately.
 */
export async function processMatchPayout(
  matchId: string,
  match: DbMatch
): Promise<void> {
  if (!match.onChainGameId) {
    console.error(`[Escrow] Match ${matchId} has no onChainGameId — skipping payout`);
    return;
  }

  // Guard: skip if payout already processed (prevents double-call race).
  if (match.escrowState === "payout_sent" || match.escrowState === "refunded") {
    console.log(`[Escrow] Match ${matchId} already processed (${match.escrowState}) — skipping`);
    return;
  }

  const gameId = match.onChainGameId;

  if (match.status === "completed" && match.winner) {
    // Winner: end_game on-chain sets status to Settled.
    // Winner claims their payout from the frontend via claim_winnings.
    await updateMatch(matchId, {
      escrowState: "payout_sent",
    });

    broadcastToMatch(matchId, {
      type: "claim_available",
      matchId,
      winner: match.winner,
      gameId,
    });

    console.log(
      `[Escrow] Match ${matchId} settled on-chain | Winner ${match.winner} can claim`
    );
  } else if (match.status === "tied") {
    // Tie: call refund_escrow to return funds to both players immediately.
    try {
      const refundSig = await refundEscrowOnChain(gameId, match.player1, match.player2);
      await updateMatch(matchId, {
        escrowState: "refunded",
        refundSignatures: { refund: refundSig },
      });

      broadcastToMatch(matchId, {
        type: "escrow_refunded",
        matchId,
        signature: refundSig,
      });

      console.log(`[Escrow] Tie refund for match ${matchId} | sig: ${refundSig}`);

      // Close the game account to reclaim rent.
      tryCloseGame(gameId, matchId);
    } catch (err) {
      console.error(`[Escrow] Tie refund failed for match ${matchId}:`, err);
      await updateMatch(matchId, { escrowState: "refund_failed" });
    }
  } else if (match.status === "forfeited" && match.winner) {
    // Forfeit: same as win — winner claims from frontend.
    await updateMatch(matchId, {
      escrowState: "payout_sent",
    });

    broadcastToMatch(matchId, {
      type: "claim_available",
      matchId,
      winner: match.winner,
      gameId,
    });

    console.log(
      `[Escrow] Match ${matchId} forfeited on-chain | Winner ${match.winner} can claim`
    );
  }
}

/**
 * Try to close a game account to reclaim rent. Fire-and-forget.
 */
function tryCloseGame(gameId: number, matchId: string): void {
  closeGameOnChain(gameId)
    .then(() => {
      console.log(`[Escrow] Game ${gameId} closed (match ${matchId}) — rent reclaimed`);
    })
    .catch((err) => {
      console.warn(`[Escrow] Failed to close game ${gameId} (match ${matchId}):`, err);
    });
}

/**
 * Check for deposit timeouts. Runs every 5s.
 * - Neither deposited → cancel on-chain.
 * - One deposited → cancel on-chain, then refund via refund_escrow.
 */
export async function checkDepositTimeouts(): Promise<void> {
  const awaitingMatches = await getMatchesByStatus("awaiting_deposits");
  const now = Date.now();

  for (const { id, data: match } of awaitingMatches) {
    if (!match.depositDeadline || now < match.depositDeadline) continue;
    if (!match.onChainGameId) continue;

    const gameId = match.onChainGameId;

    // Read on-chain state to check who deposited.
    let game;
    try {
      game = await fetchGameAccount(BigInt(gameId));
    } catch {
      console.error(`[Escrow] Failed to read game ${gameId} for timeout check`);
      continue;
    }

    if (!game || game.status !== GameStatus.Pending) continue;

    const p1Deposited = game.playerOneDeposited;
    const p2Deposited = game.playerTwoDeposited;

    try {
      // Cancel the game on-chain first.
      await cancelPendingGameOnChain(gameId);

      if (!p1Deposited && !p2Deposited) {
        // Neither deposited — just cancel.
        await updateMatch(id, { status: "cancelled", escrowState: "refunded" });
        const cancelMsg = { type: "match_cancelled", matchId: id, reason: "no_deposits" };
        broadcastToUser(match.player1, cancelMsg);
        broadcastToUser(match.player2, cancelMsg);
        console.log(`[Escrow] Match ${id} cancelled: no deposits`);

        // Close the game account to reclaim rent.
        tryCloseGame(gameId, id);
      } else {
        // One deposited — refund on-chain.
        const depositor = p1Deposited ? match.player1 : match.player2;
        const noShow = p1Deposited ? match.player2 : match.player1;

        const refundSig = await refundEscrowOnChain(gameId, match.player1, match.player2);
        await updateMatch(id, {
          status: "cancelled",
          escrowState: "partial_refund",
          refundSignatures: { [depositor]: refundSig },
        });

        broadcastToUser(depositor, {
          type: "match_cancelled",
          matchId: id,
          reason: "opponent_no_deposit",
          refundSignature: refundSig,
          refundAmount: match.betAmount,
        });

        broadcastToUser(noShow, {
          type: "match_cancelled",
          matchId: id,
          reason: "deposit_timeout",
        });

        console.log(
          `[Escrow] Match ${id} cancelled: ${noShow} didn't deposit | Refunded ${depositor} on-chain | sig: ${refundSig}`
        );

        // Close the game account to reclaim rent.
        tryCloseGame(gameId, id);
      }
    } catch (err) {
      console.error(`[Escrow] Timeout handling failed for match ${id}:`, err);
      await updateMatch(id, {
        status: "cancelled",
        escrowState: "refund_failed",
      });

      const depositor = p1Deposited ? match.player1 : match.player2;
      const noShow = p1Deposited ? match.player2 : match.player1;
      broadcastToUser(depositor, {
        type: "match_cancelled",
        matchId: id,
        reason: "opponent_no_deposit",
        refundFailed: true,
      });
      broadcastToUser(noShow, {
        type: "match_cancelled",
        matchId: id,
        reason: "deposit_timeout",
      });
    }
  }
}

/**
 * Start the deposit timeout loop.
 */
export function startDepositTimeoutLoop(): void {
  setInterval(async () => {
    try {
      await checkDepositTimeouts();
    } catch (err) {
      console.error("[Escrow] Deposit timeout check error:", err);
    }
  }, 5000);

  console.log("[Escrow] Deposit timeout monitor started (5s interval)");
}
