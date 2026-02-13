import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { referralsRef, usersRef } from "../services/firebase";

const router = Router();

/** GET /api/referral/code — Get or generate referral code. */
router.get("/code", requireAuth, async (req: AuthRequest, res) => {
  const address = req.userAddress!;
  const code =
    `${address.substring(0, 4)}${address.substring(address.length - 4)}`.toUpperCase();
  res.json({ code });
});

/** GET /api/referral/stats — Get referral statistics. */
router.get("/stats", requireAuth, async (req: AuthRequest, res) => {
  const snap = await referralsRef
    .orderByChild("referrerAddress")
    .equalTo(req.userAddress!)
    .once("value");

  const referrals: Array<Record<string, unknown>> = [];
  let totalEarned = 0;

  if (snap.exists()) {
    snap.forEach((child) => {
      const r = child.val();
      referrals.push({
        refereeAddress: child.key,
        status: r.status,
        rewardEarned: r.rewardPaid || 0,
        joinedAt: r.createdAt,
      });
      totalEarned += r.rewardPaid || 0;
    });
  }

  const address = req.userAddress!;
  res.json({
    code: `${address.substring(0, 4)}${address.substring(address.length - 4)}`.toUpperCase(),
    referrals,
    totalEarned,
    pendingReward: 0,
  });
});

/** POST /api/referral/apply — Apply a referral code (for new users). */
router.post("/apply", requireAuth, async (req: AuthRequest, res) => {
  const { code } = req.body;
  if (!code || typeof code !== "string" || code.length !== 8) {
    res.status(400).json({ error: "Invalid referral code" });
    return;
  }

  // Find the referrer by scanning users.
  const usersSnap = await usersRef.once("value");
  let referrerAddress: string | null = null;

  if (usersSnap.exists()) {
    usersSnap.forEach((child) => {
      const addr = child.key!;
      const userCode =
        `${addr.substring(0, 4)}${addr.substring(addr.length - 4)}`.toUpperCase();
      if (userCode === code.toUpperCase()) {
        referrerAddress = addr;
      }
    });
  }

  if (!referrerAddress) {
    res.status(404).json({ error: "Referral code not found" });
    return;
  }

  if (referrerAddress === req.userAddress) {
    res.status(400).json({ error: "Cannot refer yourself" });
    return;
  }

  // Check if already referred.
  const existingSnap = await referralsRef.child(req.userAddress!).once("value");
  if (existingSnap.exists()) {
    res.status(409).json({ error: "Already referred" });
    return;
  }

  await referralsRef.child(req.userAddress!).set({
    referrerAddress,
    status: "JOINED",
    rewardPaid: 0,
    createdAt: Date.now(),
  });

  res.json({ status: "applied", referrer: referrerAddress });
});

/** POST /api/referral/claim — Claim pending referral rewards. */
router.post("/claim", requireAuth, async (_req: AuthRequest, res) => {
  res.json({ status: "ok", message: "Rewards are auto-credited on referral milestones" });
});

export default router;
