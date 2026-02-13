import Redis from "ioredis";
import { PrismaClient } from "@prisma/client";
import { config } from "../config";
import { broadcastToUser } from "../ws/handler";

const prisma = new PrismaClient();
const redis = new Redis(config.redisUrl);

interface QueueEntry {
  address: string;
  elo: number;
  joinedAt: number;
}

/**
 * Add a player to the matchmaking queue.
 * Queue key format: "queue:{timeframe}:{bet}"
 */
export async function joinQueue(
  address: string,
  timeframe: string,
  bet: number,
  elo: number
): Promise<void> {
  const key = `queue:${timeframe}:${bet}`;
  const entry: QueueEntry = { address, elo, joinedAt: Date.now() };
  // Use ELO as score for sorted set so we can match by proximity.
  await redis.zadd(key, elo, JSON.stringify(entry));
}

/**
 * Remove a player from the queue.
 */
export async function leaveQueue(
  address: string,
  timeframe: string,
  bet: number
): Promise<void> {
  const key = `queue:${timeframe}:${bet}`;
  const members = await redis.zrange(key, 0, -1);
  for (const member of members) {
    const entry: QueueEntry = JSON.parse(member);
    if (entry.address === address) {
      await redis.zrem(key, member);
      break;
    }
  }
}

/**
 * Get queue statistics for all active queues.
 */
export async function getQueueStats(): Promise<
  Array<{ timeframe: string; bet: number; count: number }>
> {
  const keys = await redis.keys("queue:*");
  const stats: Array<{ timeframe: string; bet: number; count: number }> = [];

  for (const key of keys) {
    const parts = key.split(":");
    const count = await redis.zcard(key);
    if (count > 0) {
      stats.push({
        timeframe: parts[1],
        bet: parseFloat(parts[2]),
        count,
      });
    }
  }

  return stats;
}

/**
 * Matchmaking loop — runs every 500ms.
 * Finds pairs of players in the same queue with ELO within range.
 */
export function startMatchmakingLoop(): void {
  const ELO_RANGE_INITIAL = 200;
  const ELO_RANGE_EXPANSION_PER_SEC = 10;
  const MAX_ELO_RANGE = 1000;

  setInterval(async () => {
    try {
      const keys = await redis.keys("queue:*");

      for (const key of keys) {
        const members = await redis.zrange(key, 0, -1, "WITHSCORES");
        if (members.length < 4) continue; // Need at least 2 entries (value+score pairs)

        const entries: Array<QueueEntry & { raw: string }> = [];
        for (let i = 0; i < members.length; i += 2) {
          const entry: QueueEntry = JSON.parse(members[i]);
          entries.push({ ...entry, raw: members[i] });
        }

        // Sort by join time (oldest first for fairness).
        entries.sort((a, b) => a.joinedAt - b.joinedAt);

        const matched = new Set<string>();

        for (let i = 0; i < entries.length; i++) {
          if (matched.has(entries[i].address)) continue;

          const waitSeconds = (Date.now() - entries[i].joinedAt) / 1000;
          const eloRange = Math.min(
            ELO_RANGE_INITIAL + waitSeconds * ELO_RANGE_EXPANSION_PER_SEC,
            MAX_ELO_RANGE
          );

          for (let j = i + 1; j < entries.length; j++) {
            if (matched.has(entries[j].address)) continue;

            const eloDiff = Math.abs(entries[i].elo - entries[j].elo);
            if (eloDiff <= eloRange) {
              // Match found!
              matched.add(entries[i].address);
              matched.add(entries[j].address);

              // Remove from queue.
              await redis.zrem(key, entries[i].raw, entries[j].raw);

              // Create match in database.
              const parts = key.split(":");
              const timeframe = parts[1];
              const bet = parseFloat(parts[2]);

              await createMatch(
                entries[i].address,
                entries[j].address,
                timeframe,
                bet
              );
              break;
            }
          }
        }
      }
    } catch (err) {
      console.error("[Matchmaking] Error:", err);
    }
  }, 500);
}

/**
 * Create a match record in the database and notify both players.
 */
async function createMatch(
  player1: string,
  player2: string,
  timeframe: string,
  bet: number
): Promise<void> {
  const match = await prisma.match.create({
    data: {
      player1Address: player1,
      player2Address: player2,
      timeframe,
      betAmount: bet,
      status: "PENDING",
    },
  });

  console.log(
    `[Matchmaking] Match created: ${match.id} | ${player1} vs ${player2} | ${timeframe} | $${bet}`
  );

  // Notify both players via WebSocket.
  const p1User = await prisma.user.findUnique({
    where: { walletAddress: player1 },
  });
  const p2User = await prisma.user.findUnique({
    where: { walletAddress: player2 },
  });

  broadcastToUser(player1, {
    type: "match_found",
    matchId: match.id,
    opponent: {
      address: player2,
      gamerTag: p2User?.gamerTag || player2.slice(0, 8),
      elo: p2User?.eloRating || 1200,
    },
    timeframe,
    bet,
  });

  broadcastToUser(player2, {
    type: "match_found",
    matchId: match.id,
    opponent: {
      address: player1,
      gamerTag: p1User?.gamerTag || player1.slice(0, 8),
      elo: p1User?.eloRating || 1200,
    },
    timeframe,
    bet,
  });
}
