import { Router } from "express";
import {
  AuthRequest,
  requireAuth,
  getOrCreateNonce,
  verifyWalletSignature,
  issueToken,
} from "../middleware/auth";
import { getUser, updateUser, noncesRef } from "../services/firebase";

const router = Router();

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
  const storedNonceSnap = await noncesRef.child(address).once("value");
  const storedNonce = storedNonceSnap.val();

  if (!storedNonce || storedNonce !== nonce) {
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
  await noncesRef.child(address).remove();

  const token = issueToken(address);
  res.json({ token, address });
});

/** GET /api/user/:address — Get user profile. */
router.get("/user/:address", async (req, res) => {
  const user = await getUser(req.params.address);

  if (!user) {
    res.status(404).json({ error: "User not found" });
    return;
  }

  res.json({
    walletAddress: req.params.address,
    gamerTag: user.gamerTag,
    wins: user.wins,
    losses: user.losses,
    ties: user.ties,
    totalPnl: user.totalPnl,
    currentStreak: user.currentStreak,
    gamesPlayed: user.gamesPlayed,
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

    await updateUser(req.userAddress!, { gamerTag });
    res.json({ gamerTag });
  }
);

export default router;
