import { Router } from "express";
import { usersRef } from "../services/firebase";

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

  switch (sortBy) {
    case "pnl":
      players.sort((a, b) => (b.totalPnl as number) - (a.totalPnl as number));
      break;
    case "streak":
      players.sort(
        (a, b) => (b.currentStreak as number) - (a.currentStreak as number)
      );
      break;
    case "wins":
    default:
      players.sort((a, b) => (b.wins as number) - (a.wins as number));
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

export default router;
