import { queuesRef, createMatch as createDbMatch, getUser, updateMatch, DbMatch } from "./firebase";
import { broadcastToUser } from "../ws/handler";
import { isUserConnected } from "../ws/rooms";
import { config } from "../config";
import { startGameOnChain, getGamePdaAndEscrow } from "../utils/solana";

/**
 * Add a player to the FIFO matchmaking queue.
 * Queue key: "queues/{duration}_{bet}/{walletAddress}"
 */
export async function joinQueue(
  address: string,
  duration: string,
  bet: number
): Promise<void> {
  const queueKey = `${duration}_${bet}`;
  await queuesRef.child(queueKey).child(address).set({
    joinedAt: Date.now(),
  });
}

/**
 * Remove a player from the queue.
 */
export async function leaveQueue(
  address: string,
  duration: string,
  bet: number
): Promise<void> {
  const queueKey = `${duration}_${bet}`;
  await queuesRef.child(queueKey).child(address).remove();
}

/**
 * Remove a player from ALL queues they may be in.
 * Used on WS disconnect and as a safe fallback for leave_queue.
 */
export async function removeFromAllQueues(address: string): Promise<void> {
  const snap = await queuesRef.once("value");
  if (!snap.exists()) return;

  const removals: Promise<void>[] = [];
  snap.forEach((queueChild) => {
    if (queueChild.hasChild(address)) {
      removals.push(queuesRef.child(queueChild.key!).child(address).remove());
    }
  });

  if (removals.length > 0) {
    await Promise.all(removals);
    console.log(`[Matchmaking] Removed ${address} from ${removals.length} queue(s)`);
  }
}

/**
 * Get queue statistics for all active queues.
 */
export async function getQueueStats(): Promise<
  Array<{ duration: string; bet: number; count: number }>
> {
  const snap = await queuesRef.once("value");
  const stats: Array<{ duration: string; bet: number; count: number }> = [];

  if (snap.exists()) {
    snap.forEach((child) => {
      const key = child.key!;
      const parts = key.split("_");
      if (parts.length >= 2) {
        const count = child.numChildren();
        if (count > 0) {
          stats.push({
            duration: parts[0],
            bet: parseFloat(parts[1]),
            count,
          });
        }
      }
    });
  }

  return stats;
}

/**
 * FIFO Matchmaking loop — runs every 500ms.
 * Pairs the two oldest players in each queue (first-come-first-served).
 */
export function startMatchmakingLoop(): void {
  setInterval(async () => {
    try {
      const snap = await queuesRef.once("value");
      if (!snap.exists()) return;

      snap.forEach((queueChild) => {
        const queueKey = queueChild.key!;
        const entries: Array<{ address: string; joinedAt: number }> = [];

        queueChild.forEach((playerChild) => {
          entries.push({
            address: playerChild.key!,
            joinedAt: playerChild.val().joinedAt || 0,
          });
        });

        if (entries.length < 2) return;

        // Sort by joinedAt (oldest first) for FIFO.
        entries.sort((a, b) => a.joinedAt - b.joinedAt);

        void matchPair(queueKey, entries[0].address, entries[1].address);
      });
    } catch (err) {
      console.error("[Matchmaking] Error:", err);
    }
  }, 500);

  console.log("[Matchmaking] Started — FIFO matching every 500ms");
}

/**
 * Create a match between two players and remove them from the queue.
 * Also creates the game on-chain so each match gets its own PDA-owned escrow.
 */
async function matchPair(
  queueKey: string,
  player1: string,
  player2: string
): Promise<void> {
  // Remove both from queue first (prevents duplicate matching).
  await Promise.all([
    queuesRef.child(queueKey).child(player1).remove(),
    queuesRef.child(queueKey).child(player2).remove(),
  ]);

  // Guard: if either player has disconnected since they joined the queue,
  // abort without creating an on-chain game (saves SOL on rent + fees).
  if (!isUserConnected(player1) || !isUserConnected(player2)) {
    console.log(
      `[Matchmaking] Aborted match: ${!isUserConnected(player1) ? player1 : player2} is offline`
    );
    return;
  }

  const parts = queueKey.split("_");
  const duration = parts[0];
  const bet = parseFloat(parts[1]);

  const now = Date.now();

  // Parse duration string (e.g. "5m", "1h") to seconds for on-chain.
  const durationSeconds = parseDurationToSeconds(duration);

  // Create Firebase match record.
  const matchData: DbMatch = {
    player1,
    player2,
    duration,
    betAmount: bet,
    status: "awaiting_deposits",
    escrowState: "awaiting_deposits",
    depositDeadline: now + config.depositTimeoutMs,
  };

  const matchId = await createDbMatch(matchData);

  // Create the game on-chain (creates Game PDA + escrow token account).
  let onChainGameId: number | undefined;
  let gamePdaStr: string | undefined;
  let escrowTokenAccountStr: string | undefined;

  try {
    onChainGameId = await startGameOnChain(player1, player2, bet, durationSeconds);

    // Derive the addresses to send to frontend.
    const { gamePda, escrowTokenAccount } = await getGamePdaAndEscrow(
      BigInt(onChainGameId)
    );
    gamePdaStr = gamePda.toBase58();
    escrowTokenAccountStr = escrowTokenAccount.toBase58();

    // Store on-chain game ID in Firebase.
    await updateMatch(matchId, { onChainGameId });

    console.log(
      `[Matchmaking] Match created: ${matchId} | onChainGame=${onChainGameId} | ${player1} vs ${player2} | ${duration} | $${bet}`
    );
  } catch (err) {
    console.error(`[Matchmaking] Failed to create on-chain game for match ${matchId}:`, err);
    // Cancel the Firebase match — can't proceed without on-chain game.
    await updateMatch(matchId, { status: "cancelled" });
    broadcastToUser(player1, {
      type: "match_cancelled",
      matchId,
      reason: "system_error",
    });
    broadcastToUser(player2, {
      type: "match_cancelled",
      matchId,
      reason: "system_error",
    });
    return;
  }

  const [p1User, p2User] = await Promise.all([
    getUser(player1),
    getUser(player2),
  ]);

  broadcastToUser(player1, {
    type: "match_found",
    matchId,
    opponent: {
      address: player2,
      gamerTag: p2User?.gamerTag || player2.slice(0, 8),
    },
    duration,
    bet,
    onChainGameId,
    gamePda: gamePdaStr,
    escrowTokenAccount: escrowTokenAccountStr,
  });

  broadcastToUser(player2, {
    type: "match_found",
    matchId,
    opponent: {
      address: player1,
      gamerTag: p1User?.gamerTag || player1.slice(0, 8),
    },
    duration,
    bet,
    onChainGameId,
    gamePda: gamePdaStr,
    escrowTokenAccount: escrowTokenAccountStr,
  });
}

function parseDurationToSeconds(duration: string): number {
  const m = duration.match(/^(\d+)(m|h)$/);
  if (!m) return 15 * 60; // default 15 minutes
  const value = parseInt(m[1]);
  const unit = m[2];
  if (unit === "h") return value * 60 * 60;
  return value * 60;
}
