import { queuesRef, createMatch as createDbMatch, getUser, DbMatch } from "./firebase";
import { broadcastToUser } from "../ws/handler";

/**
 * Add a player to the FIFO matchmaking queue.
 * Queue key: "queues/{timeframe}_{bet}/{walletAddress}"
 */
export async function joinQueue(
  address: string,
  timeframe: string,
  bet: number
): Promise<void> {
  const queueKey = `${timeframe}_${bet}`;
  await queuesRef.child(queueKey).child(address).set({
    joinedAt: Date.now(),
  });
}

/**
 * Remove a player from the queue.
 */
export async function leaveQueue(
  address: string,
  timeframe: string,
  bet: number
): Promise<void> {
  const queueKey = `${timeframe}_${bet}`;
  await queuesRef.child(queueKey).child(address).remove();
}

/**
 * Get queue statistics for all active queues.
 */
export async function getQueueStats(): Promise<
  Array<{ timeframe: string; bet: number; count: number }>
> {
  const snap = await queuesRef.once("value");
  const stats: Array<{ timeframe: string; bet: number; count: number }> = [];

  if (snap.exists()) {
    snap.forEach((child) => {
      const key = child.key!;
      const parts = key.split("_");
      if (parts.length >= 2) {
        const count = child.numChildren();
        if (count > 0) {
          stats.push({
            timeframe: parts[0],
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
 */
async function matchPair(
  queueKey: string,
  player1: string,
  player2: string
): Promise<void> {
  // Remove both from queue first.
  await Promise.all([
    queuesRef.child(queueKey).child(player1).remove(),
    queuesRef.child(queueKey).child(player2).remove(),
  ]);

  const parts = queueKey.split("_");
  const timeframe = parts[0];
  const bet = parseFloat(parts[1]);

  const durationMs = parseDuration(timeframe);
  const now = Date.now();

  const matchData: DbMatch = {
    player1,
    player2,
    timeframe,
    betAmount: bet,
    status: "pending",
    startTime: now,
    endTime: now + durationMs,
  };

  const matchId = await createDbMatch(matchData);

  console.log(
    `[Matchmaking] Match created: ${matchId} | ${player1} vs ${player2} | ${timeframe} | $${bet}`
  );

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
    timeframe,
    bet,
  });

  broadcastToUser(player2, {
    type: "match_found",
    matchId,
    opponent: {
      address: player1,
      gamerTag: p1User?.gamerTag || player1.slice(0, 8),
    },
    timeframe,
    bet,
  });
}

/** Parse timeframe string to duration in ms. */
function parseDuration(tf: string): number {
  const match = tf.match(/^(\d+)(m|h)$/);
  if (!match) return 15 * 60 * 1000;
  const value = parseInt(match[1]);
  const unit = match[2];
  if (unit === "h") return value * 60 * 60 * 1000;
  return value * 60 * 1000;
}
