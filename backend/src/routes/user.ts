import { Router } from "express";
import { PrismaClient } from "@prisma/client";
import {
  AuthRequest,
  requireAuth,
  getOrCreateNonce,
  verifyWalletSignature,
  issueToken,
} from "../middleware/auth";

const router = Router();
const prisma = new PrismaClient();

/** GET /api/auth/nonce?address=... — Get a nonce for wallet signature. */
router.get("/auth/nonce", async (req, res) => {
  const { address } = req.query;
  if (typeof address !== "string" || address.length < 32) {
    res.status(400).json({ error: "Invalid wallet address" });
    return;
  }

  const nonce = await getOrCreateNonce(address);
  res.json({ nonce, message: `Sign this message to verify your wallet: ${nonce}` });
});

/** POST /api/auth/verify — Verify wallet signature and issue JWT. */
router.post("/auth/verify", async (req, res) => {
  const { address, signature, nonce } = req.body;

  if (!address || !signature || !nonce) {
    res.status(400).json({ error: "Missing address, signature, or nonce" });
    return;
  }

  // Verify the nonce matches what we stored.
  const user = await prisma.user.findUnique({
    where: { walletAddress: address },
  });

  if (!user || user.nonce !== nonce) {
    res.status(401).json({ error: "Invalid nonce" });
    return;
  }

  // Verify the signature.
  const message = `Sign this message to verify your wallet: ${nonce}`;
  const valid = verifyWalletSignature(address, signature, message);

  if (!valid) {
    res.status(401).json({ error: "Invalid signature" });
    return;
  }

  // Clear nonce (single-use) and issue token.
  await prisma.user.update({
    where: { walletAddress: address },
    data: { nonce: null },
  });

  const token = issueToken(address);
  res.json({ token, address });
});

/** GET /api/user/:address — Get user profile. */
router.get("/user/:address", async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { walletAddress: req.params.address },
    include: { clanMember: { include: { clan: true } } },
  });

  if (!user) {
    res.status(404).json({ error: "User not found" });
    return;
  }

  res.json({
    walletAddress: user.walletAddress,
    gamerTag: user.gamerTag,
    eloRating: user.eloRating,
    wins: user.wins,
    losses: user.losses,
    totalPnl: user.totalPnl,
    currentStreak: user.currentStreak,
    balanceUsdc: user.balanceUsdc,
    clan: user.clanMember
      ? { id: user.clanMember.clan.id, name: user.clanMember.clan.name, tag: user.clanMember.clan.tag }
      : null,
    createdAt: user.createdAt,
  });
});

/** PUT /api/user/gamer-tag — Set or update gamer tag. */
router.put(
  "/user/gamer-tag",
  requireAuth,
  async (req: AuthRequest, res) => {
    const { gamerTag } = req.body;
    if (
      !gamerTag ||
      typeof gamerTag !== "string" ||
      gamerTag.length > 16 ||
      gamerTag.length < 1
    ) {
      res.status(400).json({ error: "Gamer tag must be 1-16 characters" });
      return;
    }

    try {
      const user = await prisma.user.update({
        where: { walletAddress: req.userAddress! },
        data: { gamerTag },
      });
      res.json({ gamerTag: user.gamerTag });
    } catch {
      res.status(409).json({ error: "Gamer tag already taken" });
    }
  }
);

export default router;
