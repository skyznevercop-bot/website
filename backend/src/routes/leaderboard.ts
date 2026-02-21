import { Router } from "express";
import { usersRef } from "../services/firebase";
import { isValidSolanaAddress } from "../utils/validation";

const router = Router();

/** GET /api/leaderboard — Query the leaderboard. */
router.get("/", async (req, res) => {
  const sortBy = (req.query.sortBy as string) || "wins";
  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);

  const snap = await usersRef.once("value");
  if (!snap.exists()) {
    res.json({ players: [], total: 0, page, limit });
    return;
  }

  const players: Array<Record<string, unknown>> = [];
  snap.forEach((child) => {
    const u = child.val();
    const gamesPlayed = (u.wins || 0) + (u.losses || 0) + (u.ties || 0);
    if (gamesPlayed > 0) {
      players.push({
        walletAddress: child.key,
        gamerTag: u.gamerTag,
        wins: u.wins || 0,
        losses: u.losses || 0,
        ties: u.ties || 0,
        totalPnl: u.totalPnl || 0,
        currentStreak: u.currentStreak || 0,
        gamesPlayed,
        winRate:
          gamesPlayed > 0
            ? Math.round(((u.wins || 0) / gamesPlayed) * 100)
            : 0,
      });
    }
  });

  // Multi-level sort with tie-breakers so rankings are deterministic.
  const multiSort = (
    a: Record<string, unknown>,
    b: Record<string, unknown>,
    keys: Array<{ key: string; asc?: boolean }>
  ): number => {
    for (const { key, asc } of keys) {
      const diff = (b[key] as number) - (a[key] as number);
      if (diff !== 0) return asc ? -diff : diff;
    }
    return 0;
  };

  switch (sortBy) {
    case "pnl":
      players.sort((a, b) =>
        multiSort(a, b, [
          { key: "totalPnl" },
          { key: "wins" },
          { key: "winRate" },
        ])
      );
      break;
    case "streak":
      players.sort((a, b) =>
        multiSort(a, b, [
          { key: "currentStreak" },
          { key: "wins" },
          { key: "totalPnl" },
        ])
      );
      break;
    case "wins":
    default:
      players.sort((a, b) =>
        multiSort(a, b, [
          { key: "wins" },
          { key: "winRate" },
          { key: "losses", asc: true },
          { key: "totalPnl" },
        ])
      );
      break;
  }

  const total = players.length;
  const start = (page - 1) * limit;
  const paged = players.slice(start, start + limit);

  const ranked = paged.map((player, idx) => ({
    rank: start + idx + 1,
    ...player,
  }));

  res.json({ players: ranked, total, page, limit });
});

/** GET /api/leaderboard/rank/:address — Get a player's rank (by wins). */
router.get("/rank/:address", async (req, res) => {
  const address = req.params.address;
  if (!isValidSolanaAddress(address)) {
    res.status(400).json({ error: "Invalid wallet address" });
    return;
  }

  const snap = await usersRef.once("value");
  if (!snap.exists()) {
    res.json({ rank: null, total: 0 });
    return;
  }

  const players: Array<{ address: string; wins: number; winRate: number; losses: number; totalPnl: number }> = [];
  snap.forEach((child) => {
    const u = child.val();
    const gamesPlayed = (u.wins || 0) + (u.losses || 0) + (u.ties || 0);
    if (gamesPlayed > 0) {
      players.push({
        address: child.key!,
        wins: u.wins || 0,
        losses: u.losses || 0,
        winRate: gamesPlayed > 0 ? Math.round(((u.wins || 0) / gamesPlayed) * 100) : 0,
        totalPnl: u.totalPnl || 0,
      });
    }
  });

  // Sort by wins (same as default leaderboard).
  players.sort((a, b) => {
    if (b.wins !== a.wins) return b.wins - a.wins;
    if (b.winRate !== a.winRate) return b.winRate - a.winRate;
    if (a.losses !== b.losses) return a.losses - b.losses;
    return b.totalPnl - a.totalPnl;
  });

  const idx = players.findIndex((p) => p.address === address);
  res.json({ rank: idx >= 0 ? idx + 1 : null, total: players.length });
});

export default router;
