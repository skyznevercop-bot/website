import { Router } from "express";
import { PrismaClient } from "@prisma/client";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { getLatestPrices } from "../services/price-oracle";

const router = Router();
const prisma = new PrismaClient();

/** GET /api/match/:id — Get match details. */
router.get("/:id", async (req, res) => {
  const match = await prisma.match.findUnique({
    where: { id: req.params.id },
    include: {
      player1: { select: { walletAddress: true, gamerTag: true, eloRating: true } },
      player2: { select: { walletAddress: true, gamerTag: true, eloRating: true } },
      positions: true,
    },
  });

  if (!match) {
    res.status(404).json({ error: "Match not found" });
    return;
  }

  res.json(match);
});

/** GET /api/match/active/list — Get all active matches. */
router.get("/active/list", async (_req, res) => {
  const matches = await prisma.match.findMany({
    where: { status: "ACTIVE" },
    include: {
      player1: { select: { gamerTag: true, eloRating: true } },
      player2: { select: { gamerTag: true, eloRating: true } },
    },
    orderBy: { startTime: "desc" },
    take: 20,
  });

  res.json({ matches });
});

/** POST /api/match/:id/trade — Submit a trade (open position). */
router.post(
  "/:id/trade",
  requireAuth,
  async (req: AuthRequest, res) => {
    const { asset, isLong, size, leverage } = req.body;
    const matchId = req.params.id;

    // Validate match.
    const match = await prisma.match.findUnique({
      where: { id: matchId },
    });

    if (!match || match.status !== "ACTIVE") {
      res.status(400).json({ error: "Match not active" });
      return;
    }

    if (
      req.userAddress !== match.player1Address &&
      req.userAddress !== match.player2Address
    ) {
      res.status(403).json({ error: "Not a player in this match" });
      return;
    }

    const prices = getLatestPrices();
    const priceMap: Record<string, number> = {
      BTC: prices.btc,
      ETH: prices.eth,
      SOL: prices.sol,
    };

    const entryPrice = priceMap[asset];
    if (!entryPrice) {
      res.status(400).json({ error: "Unknown asset" });
      return;
    }

    const position = await prisma.position.create({
      data: {
        matchId,
        playerAddress: req.userAddress!,
        assetSymbol: asset,
        isLong,
        entryPrice,
        size,
        leverage,
        openedAt: new Date(),
      },
    });

    res.json({
      id: position.id,
      asset,
      isLong,
      entryPrice,
      size,
      leverage,
    });
  }
);

/** GET /api/match/:id/positions — Get positions for a match. */
router.get("/:id/positions", requireAuth, async (req: AuthRequest, res) => {
  const positions = await prisma.position.findMany({
    where: {
      matchId: req.params.id,
      playerAddress: req.userAddress!,
    },
    orderBy: { openedAt: "desc" },
  });

  res.json({ positions });
});

/** GET /api/match/history/:address — Get match history for a user. */
router.get("/history/:address", async (req, res) => {
  const { address } = req.params;
  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
  const skip = (page - 1) * limit;

  const [matches, total] = await Promise.all([
    prisma.match.findMany({
      where: {
        OR: [
          { player1Address: address },
          { player2Address: address },
        ],
        status: "COMPLETED",
      },
      include: {
        player1: { select: { gamerTag: true, eloRating: true } },
        player2: { select: { gamerTag: true, eloRating: true } },
      },
      orderBy: { settledAt: "desc" },
      skip,
      take: limit,
    }),
    prisma.match.count({
      where: {
        OR: [
          { player1Address: address },
          { player2Address: address },
        ],
        status: "COMPLETED",
      },
    }),
  ]);

  res.json({ matches, total, page, limit });
});

export default router;
