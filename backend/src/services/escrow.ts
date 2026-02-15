import { config } from "../config";
import {
  getMatch,
  updateMatch,
  matchesRef,
  getMatchesByStatus,
  DbMatch,
} from "./firebase";
import {
  verifyUsdcDeposit,
  sendUsdcPayoutWithRetry,
} from "../utils/solana";
import { broadcastToMatch, broadcastToUser } from "../ws/rooms";

/**
 * Confirm a player's deposit for a match.
 * Called from POST /api/match/:id/confirm-deposit.
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

  const alreadyVerified = isPlayer1
    ? match.player1DepositVerified
    : match.player2DepositVerified;
  if (alreadyVerified) {
    return { success: false, message: "Deposit already confirmed", matchNowActive: false };
  }

  if (match.depositDeadline && Date.now() > match.depositDeadline) {
    return { success: false, message: "Deposit deadline has passed", matchNowActive: false };
  }

  // Verify on-chain.
  const verification = await verifyUsdcDeposit(
    txSignature,
    playerAddress,
    match.betAmount
  );
  if (!verification.verified) {
    return {
      success: false,
      message: verification.error || "Deposit verification failed",
      matchNowActive: false,
    };
  }

  // Record the verified deposit.
  const now = Date.now();
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

  // Notify BOTH players directly (they haven't joined the match room yet).
  const depositNotification = {
    type: "deposit_confirmed",
    matchId,
    player: playerAddress,
  };
  broadcastToUser(match.player1, depositNotification);
  broadcastToUser(match.player2, depositNotification);

  // Re-read match from DB to get latest state (avoids race condition
  // when both players confirm deposits at nearly the same time).
  const freshMatch = await getMatch(matchId);
  if (!freshMatch) {
    return { success: true, message: "Deposit verified.", matchNowActive: false };
  }

  const bothVerified =
    freshMatch.player1DepositVerified && freshMatch.player2DepositVerified;

  if (bothVerified && freshMatch.status === "awaiting_deposits") {
    return await activateMatch(matchId, freshMatch);
  }

  return {
    success: true,
    message: "Deposit verified. Waiting for opponent.",
    matchNowActive: false,
  };
}

/**
 * Activate a match using a Firebase transaction for atomicity.
 */
async function activateMatch(
  matchId: string,
  match: DbMatch
): Promise<{ success: boolean; message: string; matchNowActive: boolean }> {
  const durationMs = parseDuration(match.duration);
  const matchRef = matchesRef.child(matchId);

  const result = await matchRef.transaction((current: DbMatch | null) => {
    if (!current || current.status !== "awaiting_deposits") return; // abort
    const now = Date.now();
    current.status = "active";
    current.escrowState = "deposits_received";
    current.startTime = now;
    current.endTime = now + durationMs;
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

  // Notify both players directly — they haven't joined the match room yet,
  // so broadcastToMatch would send to an empty room.
  broadcastToUser(match.player1, activationMsg);
  broadcastToUser(match.player2, activationMsg);
  // Also broadcast to match room for any observers already there.
  broadcastToMatch(matchId, activationMsg);

  console.log(`[Escrow] Match ${matchId} activated: both deposits verified`);

  return {
    success: true,
    message: "Both deposits verified. Match is now active!",
    matchNowActive: true,
  };
}

/**
 * Process payout after a match is settled.
 * Called from settlement.ts after winner/tie is determined.
 */
export async function processMatchPayout(
  matchId: string,
  match: DbMatch
): Promise<void> {
  const totalPot = match.betAmount * 2;

  if (match.status === "completed" && match.winner) {
    // Winner takes (1 - rake) of total pot.
    const payoutAmount = totalPot * (1 - config.rakePercent);
    const rakeAmount = totalPot * config.rakePercent;

    try {
      const payoutSig = await sendUsdcPayoutWithRetry(match.winner, payoutAmount);
      await updateMatch(matchId, {
        payoutSignature: payoutSig,
        payoutAmount,
        rakeAmount,
        escrowState: "payout_sent",
      });

      broadcastToMatch(matchId, {
        type: "payout_sent",
        winner: match.winner,
        amount: payoutAmount,
        signature: payoutSig,
      });

      console.log(
        `[Escrow] Payout: ${payoutAmount} USDC to ${match.winner} | rake: ${rakeAmount} | sig: ${payoutSig}`
      );
    } catch (err) {
      console.error(`[Escrow] PAYOUT FAILED for match ${matchId}:`, err);
      await updateMatch(matchId, { payoutAmount, rakeAmount });
    }
  } else if (match.status === "tied") {
    // Tie: refund both minus small fee.
    const feePerPlayer = match.betAmount * (config.tieFeePercent / 2);
    const refundAmount = match.betAmount - feePerPlayer;
    const refundSignatures: Record<string, string> = {};

    for (const player of [match.player1, match.player2]) {
      try {
        const sig = await sendUsdcPayoutWithRetry(player, refundAmount);
        refundSignatures[player] = sig;
        console.log(`[Escrow] Tie refund: ${refundAmount} USDC to ${player} | sig: ${sig}`);
      } catch (err) {
        console.error(`[Escrow] TIE REFUND FAILED for ${player} in match ${matchId}:`, err);
      }
    }

    await updateMatch(matchId, {
      refundSignatures,
      rakeAmount: feePerPlayer * 2,
      escrowState: "refunded",
    });
  } else if (match.status === "forfeited" && match.winner) {
    // Forfeit: same payout as a win.
    const payoutAmount = totalPot * (1 - config.rakePercent);
    const rakeAmount = totalPot * config.rakePercent;

    try {
      const payoutSig = await sendUsdcPayoutWithRetry(match.winner, payoutAmount);
      await updateMatch(matchId, {
        payoutSignature: payoutSig,
        payoutAmount,
        rakeAmount,
        escrowState: "payout_sent",
      });
      console.log(
        `[Escrow] Forfeit payout: ${payoutAmount} USDC to ${match.winner} | sig: ${payoutSig}`
      );
    } catch (err) {
      console.error(`[Escrow] FORFEIT PAYOUT FAILED for match ${matchId}:`, err);
    }
  }
}

/**
 * Check for deposit timeouts. Runs every 5s.
 * - Neither deposited → cancel.
 * - One deposited → FULL REFUND to the depositor, cancel match.
 */
export async function checkDepositTimeouts(): Promise<void> {
  const awaitingMatches = await getMatchesByStatus("awaiting_deposits");
  const now = Date.now();

  for (const { id, data: match } of awaitingMatches) {
    if (!match.depositDeadline || now < match.depositDeadline) continue;

    const p1Deposited = match.player1DepositVerified === true;
    const p2Deposited = match.player2DepositVerified === true;

    if (!p1Deposited && !p2Deposited) {
      // Neither deposited — just cancel.
      await updateMatch(id, { status: "cancelled", escrowState: "refunded" });
      const cancelMsg = { type: "match_cancelled", matchId: id, reason: "no_deposits" };
      broadcastToUser(match.player1, cancelMsg);
      broadcastToUser(match.player2, cancelMsg);
      console.log(`[Escrow] Match ${id} cancelled: no deposits received`);
    } else {
      // One deposited, other didn't — FULL REFUND (100%, no fee).
      const depositor = p1Deposited ? match.player1 : match.player2;
      const noShow = p1Deposited ? match.player2 : match.player1;

      try {
        const refundSig = await sendUsdcPayoutWithRetry(depositor, match.betAmount);
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
          `[Escrow] Match ${id} cancelled: ${noShow} didn't deposit | Full refund to ${depositor} | sig: ${refundSig}`
        );
      } catch (err) {
        console.error(`[Escrow] REFUND FAILED for ${depositor} in match ${id}:`, err);
        // Mark match as needing manual refund so it stops retrying every 5s
        // but still notify the user so they know.
        await updateMatch(id, {
          status: "cancelled",
          escrowState: "refund_failed",
        });
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

function parseDuration(tf: string): number {
  const m = tf.match(/^(\d+)(m|h)$/);
  if (!m) return 15 * 60 * 1000;
  const value = parseInt(m[1]);
  const unit = m[2];
  if (unit === "h") return value * 60 * 60 * 1000;
  return value * 60 * 1000;
}
