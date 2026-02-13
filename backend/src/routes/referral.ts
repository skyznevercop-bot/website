import { Router } from "express";
import { PrismaClient } from "@prisma/client";
import { AuthRequest, requireAuth } from "../middleware/auth";

const router = Router();
const prisma = new PrismaClient();

/** GET /api/referral/code — Get or generate referral code. */
router.get("/code", requireAuth, async (req: AuthRequest, res) => {
  const address = req.userAddress!;
  // Referral code = first 4 + last 4 characters of wallet address.
  const code =
    `${address.substring(0, 4)}${address.substring(address.length - 4)}`.toUpperCase();

  res.json({ code });
});

/** GET /api/referral/stats — Get referral statistics. */
router.get("/stats", requireAuth, async (req: AuthRequest, res) => {
  const referrals = await prisma.referral.findMany({
    where: { referrerAddress: req.userAddress! },
    include: {
      referee: {
        select: { gamerTag: true, walletAddress: true },
      },
    },
    orderBy: { createdAt: "desc" },
  });

  const totalEarned = referrals.reduce((sum, r) => sum + r.rewardPaid, 0);

  // Calculate pending reward (referees who deposited but reward not yet claimed).
  const pendingReferrals = referrals.filter(
    (r) => r.status === "DEPOSITED" || r.status === "PLAYED"
  );
  const pendingReward = pendingReferrals.reduce((sum, r) => {
    const maxReward = r.status === "PLAYED" ? 10 : 5;
    return sum + Math.max(0, maxReward - r.rewardPaid);
  }, 0);

  res.json({
    code: `${req.userAddress!.substring(0, 4)}${req.userAddress!.substring(req.userAddress!.length - 4)}`.toUpperCase(),
    referrals: referrals.map((r) => ({
      gamerTag: r.referee.gamerTag || r.referee.walletAddress.slice(0, 8),
      status: r.status,
      rewardEarned: r.rewardPaid,
      joinedAt: r.createdAt,
    })),
    totalEarned,
    pendingReward,
  });
});

/** POST /api/referral/apply — Apply a referral code (for new users). */
router.post("/apply", requireAuth, async (req: AuthRequest, res) => {
  const { code } = req.body;
  if (!code || typeof code !== "string" || code.length !== 8) {
    res.status(400).json({ error: "Invalid referral code" });
    return;
  }

  // Find the referrer by their code.
  const allUsers = await prisma.user.findMany({
    select: { walletAddress: true },
  });

  const referrer = allUsers.find((u) => {
    const userCode =
      `${u.walletAddress.substring(0, 4)}${u.walletAddress.substring(u.walletAddress.length - 4)}`.toUpperCase();
    return userCode === code.toUpperCase();
  });

  if (!referrer) {
    res.status(404).json({ error: "Referral code not found" });
    return;
  }

  if (referrer.walletAddress === req.userAddress) {
    res.status(400).json({ error: "Cannot refer yourself" });
    return;
  }

  // Check if already referred.
  const existing = await prisma.referral.findUnique({
    where: { refereeAddress: req.userAddress! },
  });

  if (existing) {
    res.status(409).json({ error: "Already referred" });
    return;
  }

  await prisma.referral.create({
    data: {
      referrerAddress: referrer.walletAddress,
      refereeAddress: req.userAddress!,
      status: "JOINED",
    },
  });

  res.json({ status: "applied", referrer: referrer.walletAddress });
});

/** POST /api/referral/claim — Claim pending referral rewards. */
router.post("/claim", requireAuth, async (req: AuthRequest, res) => {
  // Rewards are auto-credited by wallet-monitor when status changes.
  // This endpoint is for any manual claim logic if needed.
  res.json({ status: "ok", message: "Rewards are auto-credited on referral milestones" });
});

export default router;
