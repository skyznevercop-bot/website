import { Router } from "express";
import admin from "firebase-admin";
import { usersRef } from "../services/firebase";
import { isValidSolanaAddress } from "../utils/validation";

const router = Router();

// ── Leaderboard cache (avoids full-table scan on every request) ──

interface LeaderboardEntry {
  walletAddress: string;
  gamerTag: string | undefined;
  wins: number;
  losses: number;
  ties: number;
  totalPnl: number;
  currentStreak: number;
  gamesPlayed: number;
  winRate: number;
}

const CACHE_TTL_MS = 10_000; // 10 seconds

const leaderboardCache = new Map<
  string,
  { players: LeaderboardEntry[]; expiry: number }
>();

function buildPlayerList(snap: admin.database.DataSnapshot): LeaderboardEntry[] {
  const players: LeaderboardEntry[] = [];
  snap.forEach((child) => {
    const u = child.val();
    const gamesPlayed = (u.wins || 0) + (u.losses || 0) + (u.ties || 0);
    if (gamesPlayed > 0) {
      players.push({
        walletAddress: child.key!,
        gamerTag: u.gamerTag,
        wins: u.wins || 0,
        losses: u.losses || 0,
        ties: u.ties || 0,
        totalPnl: u.totalPnl || 0,
        currentStreak: u.currentStreak || 0,
        gamesPlayed,
        winRate: Math.round(((u.wins || 0) / gamesPlayed) * 100),
      });
    }
  });
  return players;
}

// Multi-level sort with tie-breakers so rankings are deterministic.
function multiSort(
  a: LeaderboardEntry,
  b: LeaderboardEntry,
  keys: Array<{ key: keyof LeaderboardEntry; asc?: boolean }>
): number {
  for (const { key, asc } of keys) {
    const diff = (b[key] as number) - (a[key] as number);
    if (diff !== 0) return asc ? -diff : diff;
  }
  return 0;
}

function sortPlayers(players: LeaderboardEntry[], sortBy: string): LeaderboardEntry[] {
  const sorted = [...players];

  switch (sortBy) {
    case "pnl":
      sorted.sort((a, b) =>
        multiSort(a, b, [
          { key: "totalPnl" },
          { key: "wins" },
          { key: "winRate" },
        ])
      );
      break;
    case "streak":
      sorted.sort((a, b) =>
        multiSort(a, b, [
          { key: "currentStreak" },
          { key: "wins" },
          { key: "totalPnl" },
        ])
      );
      break;
    case "wins":
    default:
      sorted.sort((a, b) =>
        multiSort(a, b, [
          { key: "wins" },
          { key: "winRate" },
          { key: "losses", asc: true },
          { key: "totalPnl" },
        ])
      );
      break;
  }

  return sorted;
}

async function getCachedLeaderboard(sortBy: string): Promise<LeaderboardEntry[]> {
  const now = Date.now();
  const cached = leaderboardCache.get(sortBy);

  if (cached && now < cached.expiry) {
    return cached.players;
  }

  const snap = await usersRef.once("value");
  if (!snap.exists()) return [];

  const players = buildPlayerList(snap);
  const sorted = sortPlayers(players, sortBy);

  leaderboardCache.set(sortBy, { players: sorted, expiry: now + CACHE_TTL_MS });
  return sorted;
}

/** GET /api/leaderboard — Query the leaderboard. */
router.get("/", async (req, res) => {
  const sortBy = (req.query.sortBy as string) || "wins";
  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);

  const players = await getCachedLeaderboard(sortBy);

  const total = players.length;
  const start = (page - 1) * limit;
  const paged = players.slice(start, start + limit);

  const ranked = paged.map((player, idx) => ({
    rank: start + idx + 1,
    ...player,
  }));

  res.json({ players: ranked, total, page, limit });
});

/** GET /api/leaderboard/rank/:address — Get a player's rank (by PnL). */
router.get("/rank/:address", async (req, res) => {
  const address = req.params.address;
  if (!isValidSolanaAddress(address)) {
    res.status(400).json({ error: "Invalid wallet address" });
    return;
  }

  const players = await getCachedLeaderboard("pnl");

  const idx = players.findIndex((p) => p.walletAddress === address);
  res.json({ rank: idx >= 0 ? idx + 1 : null, total: players.length });
});

export default router;
