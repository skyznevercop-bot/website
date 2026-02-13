import { Router } from "express";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { getOnChainUsdcBalance } from "../services/wallet-monitor";

const router = Router();

/** GET /api/portfolio/balance — Get user on-chain USDC balance. */
router.get("/balance", requireAuth, async (req: AuthRequest, res) => {
  const onChainBalance = await getOnChainUsdcBalance(req.userAddress!);

  res.json({
    platformBalance: 0, // No platform balance in demo mode
    onChainBalance,
  });
});

export default router;
