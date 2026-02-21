import { queuesRef, createMatch as createDbMatch, getUser, DbMatch, hasActiveMatch } from "./firebase";
import { broadcastToUser } from "../ws/handler";
import { isUserConnected } from "../ws/rooms";
import { freezeForMatch, unfreezeBalance } from "./balance";
import { config } from "../config";

/** Guard against double-matching: addresses currently being matched. */
const _matchingPlayers = new Set<string>();

/**
 * Add a player to the FIFO matchmaking queue.
 * Freezes their bet amount before adding to the queue.
 * Returns false if insufficient balance.
 */
export async function joinQueue(
  address: string,
  duration: string,
  bet: number
): Promise<boolean> {
  // Freeze the bet amount.
  const frozen = await freezeForMatch(address, bet);
  if (!frozen) {
    return false;
  }

  const queueKey = `${duration}_${bet}`;
  await queuesRef.child(queueKey).child(address).set({
    joinedAt: Date.now(),
  });

  return true;
}

/**
 * Remove a player from the queue and unfreeze their bet.
 */
export async function leaveQueue(
  address: string,
  duration: string,
  bet: number
): Promise<void> {
  const queueKey = `${duration}_${bet}`;

  // Check if they're actually in this queue before unfreezing.
  const snap = await queuesRef.child(queueKey).child(address).once("value");
  if (snap.exists()) {
    await queuesRef.child(queueKey).child(address).remove();
    await unfreezeBalance(address, bet);
  }
}

/**
 * Remove a player from ALL queues they may be in and unfreeze their balance.
 * Used on WS disconnect and as a safe fallback for leave_queue.
 */
export async function removeFromAllQueues(address: string): Promise<void> {
  const snap = await queuesRef.once("value");
  if (!snap.exists()) return;

  const removals: Promise<void>[] = [];

  snap.forEach((queueChild) => {
    if (queueChild.hasChild(address)) {
      const queueKey = queueChild.key!;
      const parts = queueKey.split("_");
      const bet = parseFloat(parts[1]);

      removals.push(
        queuesRef.child(queueKey).child(address).remove()
          .then(() => unfreezeBalance(address, bet))
      );
    }
  });

  if (removals.length > 0) {
    await Promise.all(removals);
    console.log(`[Matchmaking] Removed ${address} from ${removals.length} queue(s) — balance unfrozen`);
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
 * NO on-chain calls — matching is instant.
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

        // Find the first pair where neither player is already being matched.
        for (let i = 0; i < entries.length - 1; i++) {
          const p1 = entries[i].address;
          const p2 = entries[i + 1].address;
          if (_matchingPlayers.has(p1) || _matchingPlayers.has(p2)) continue;

          _matchingPlayers.add(p1);
          _matchingPlayers.add(p2);
          void matchPair(queueKey, p1, p2).finally(() => {
            _matchingPlayers.delete(p1);
            _matchingPlayers.delete(p2);
          });
          break;
        }
      });
    } catch (err) {
      console.error("[Matchmaking] Error:", err);
    }
  }, config.matchmakingIntervalMs);

  console.log(`[Matchmaking] Started — FIFO matching every ${config.matchmakingIntervalMs}ms (instant, no on-chain)`);
}

/**
 * Create a match between two players — instant, no on-chain TX.
 * Both players already have their bet frozen from joinQueue.
 */
async function matchPair(
  queueKey: string,
  player1: string,
  player2: string
): Promise<void> {
  const parts = queueKey.split("_");
  const bet = parseFloat(parts[1]);

  // Guard: check connection BEFORE removing from queue so the connected
  // player keeps their queue position if the other is offline.
  const p1Connected = isUserConnected(player1);
  const p2Connected = isUserConnected(player2);

  if (!p1Connected || !p2Connected) {
    // Only remove the disconnected player(s) — the connected one stays queued.
    if (!p1Connected) {
      await queuesRef.child(queueKey).child(player1).remove();
      await unfreezeBalance(player1, bet);
      console.log(`[Matchmaking] Removed offline ${player1.slice(0, 8)}… from queue — balance unfrozen`);
    }
    if (!p2Connected) {
      await queuesRef.child(queueKey).child(player2).remove();
      await unfreezeBalance(player2, bet);
      console.log(`[Matchmaking] Removed offline ${player2.slice(0, 8)}… from queue — balance unfrozen`);
    }
    return;
  }

  // Both players are connected — remove from queue and proceed.
  await Promise.all([
    queuesRef.child(queueKey).child(player1).remove(),
    queuesRef.child(queueKey).child(player2).remove(),
  ]);

  // Guard: if either player is already in an active match, abort.
  const [p1Active, p2Active] = await Promise.all([
    hasActiveMatch(player1),
    hasActiveMatch(player2),
  ]);
  if (p1Active || p2Active) {
    await Promise.all([
      unfreezeBalance(player1, bet),
      unfreezeBalance(player2, bet),
    ]);
    const busy = p1Active ? player1 : player2;
    console.log(
      `[Matchmaking] Aborted match: ${busy.slice(0, 8)}… already in active match — balance unfrozen`
    );
    return;
  }

  const duration = parts[0];

  const durationSeconds = parseDurationToSeconds(duration);
  const now = Date.now();

  // Create Firebase match record — starts immediately.
  const matchData: DbMatch = {
    player1,
    player2,
    duration,
    betAmount: bet,
    status: "active",
    startTime: now,
    endTime: now + durationSeconds * 1000,
  };

  const matchId = await createDbMatch(matchData);

  const [p1User, p2User] = await Promise.all([
    getUser(player1),
    getUser(player2),
  ]);

  console.log(
    `[Matchmaking] Match created: ${matchId} | ${player1.slice(0, 8)}… vs ${player2.slice(0, 8)}… | ${duration} | $${bet} | INSTANT`
  );

  // Send match_found to both players — match is already active.
  broadcastToUser(player1, {
    type: "match_found",
    matchId,
    opponent: {
      address: player2,
      gamerTag: p2User?.gamerTag || player2.slice(0, 8),
    },
    duration,
    durationSeconds,
    bet,
    startTime: now,
    endTime: now + durationSeconds * 1000,
  });

  broadcastToUser(player2, {
    type: "match_found",
    matchId,
    opponent: {
      address: player1,
      gamerTag: p1User?.gamerTag || player1.slice(0, 8),
    },
    duration,
    durationSeconds,
    bet,
    startTime: now,
    endTime: now + durationSeconds * 1000,
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
