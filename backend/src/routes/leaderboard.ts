import { Router } from "express";
import { PrismaClient } from "@prisma/client";

const router = Router();
const prisma = new PrismaClient();

/** GET /api/leaderboard — Query the leaderboard. */
router.get("/", async (req, res) => {
  const sortBy = (req.query.sortBy as string) || "elo";
  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);
  const skip = (page - 1) * limit;

  let orderBy: Record<string, string>;
  switch (sortBy) {
    case "wins":
      orderBy = { wins: "desc" };
      break;
    case "pnl":
      orderBy = { totalPnl: "desc" };
      break;
    case "streak":
      orderBy = { currentStreak: "desc" };
      break;
    case "elo":
    default:
      orderBy = { eloRating: "desc" };
      break;
  }

  const [players, total] = await Promise.all([
    prisma.user.findMany({
      where: {
        // Only include players who have played at least 1 game.
        OR: [{ wins: { gt: 0 } }, { losses: { gt: 0 } }],
      },
      select: {
        walletAddress: true,
        gamerTag: true,
        eloRating: true,
        wins: true,
        losses: true,
        totalPnl: true,
        currentStreak: true,
      },
      orderBy,
      skip,
      take: limit,
    }),
    prisma.user.count({
      where: {
        OR: [{ wins: { gt: 0 } }, { losses: { gt: 0 } }],
      },
    }),
  ]);

  // Add rank based on position in results.
  const ranked = players.map((player, idx) => ({
    rank: skip + idx + 1,
    ...player,
    gamesPlayed: player.wins + player.losses,
    winRate:
      player.wins + player.losses > 0
        ? Math.round(
            (player.wins / (player.wins + player.losses)) * 100
          )
        : 0,
  }));

  res.json({ players: ranked, total, page, limit });
});

export default router;
