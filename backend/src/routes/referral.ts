import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { referralsRef, usersRef, getUser } from "../services/firebase";

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
  const address = req.userAddress!;

  const snap = await referralsRef
    .orderByChild("referrerAddress")
    .equalTo(address)
    .once("value");

  const referrals: Array<Record<string, unknown>> = [];
  let totalEarned = 0;

  if (snap.exists()) {
    const fetchTasks: Array<Promise<void>> = [];

    snap.forEach((child) => {
      const r = child.val();
      const refereeAddress = child.key!;

      fetchTasks.push(
        getUser(refereeAddress).then((user) => {
          const earned = r.rewardPaid || 0;
          referrals.push({
            refereeAddress,
            gamerTag: user?.gamerTag || refereeAddress.slice(0, 8),
            status: r.status || "JOINED",
            gamesPlayed: r.gamesPlayed || 0,
            rewardEarned: earned,
            joinedAt: r.createdAt,
          });
          totalEarned += earned;
        })
      );
    });

    await Promise.all(fetchTasks);
  }

  // Get the referrer's claimable referral balance.
  const user = await getUser(address);
  const referralBalance = user?.referralBalance || 0;

  res.json({
    code: `${address.substring(0, 4)}${address.substring(address.length - 4)}`.toUpperCase(),
    referrals,
    totalEarned,
    referralBalance,
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
    gamesPlayed: 0,
    createdAt: Date.now(),
  });

  res.json({ status: "applied", referrer: referrerAddress });
});

/** POST /api/referral/claim — Claim accumulated referral rewards to main balance. */
router.post("/claim", requireAuth, async (req: AuthRequest, res) => {
  const address = req.userAddress!;

  try {
    let claimedAmount = 0;

    await usersRef.child(address).transaction((current: Record<string, unknown> | null) => {
      if (!current) return current;
      const referralBalance = (current.referralBalance as number) || 0;
      if (referralBalance <= 0) return current;

      claimedAmount = referralBalance;
      return {
        ...current,
        balance: ((current.balance as number) || 0) + referralBalance,
        referralBalance: 0,
      };
    });

    if (claimedAmount <= 0) {
      res.status(400).json({ error: "No referral rewards to claim" });
      return;
    }

    res.json({ success: true, amount: claimedAmount });
  } catch (err) {
    console.error("[Referral] POST /claim error:", err);
    res.status(500).json({ error: "Failed to claim rewards" });
  }
});

export default router;
