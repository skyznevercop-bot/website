import { Router } from "express";
import { requireAuth, requireAdmin, AuthRequest } from "../middleware/auth";
import {
  getBalance,
  confirmDeposit,
  processWithdrawal,
  getBalanceTransactions,
  getVaultAddress,
  getPlatformStats,
  withdrawRake,
} from "../services/balance";
import { config } from "../config";

const router = Router();

/**
 * GET /api/balance
 * Get current user balance (requires auth).
 */
router.get("/balance", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const balanceInfo = await getBalance(address);
    res.json(balanceInfo);
  } catch (err) {
    console.error("[Balance] GET /balance error:", err);
    res.status(500).json({ error: "Failed to fetch balance" });
  }
});

/**
 * GET /api/balance/vault
 * Get the platform vault address for deposits (public).
 */
router.get("/balance/vault", async (_req, res) => {
  try {
    const vault = await getVaultAddress();
    res.json({ vaultAddress: vault.toBase58() });
  } catch (err) {
    console.error("[Balance] GET /balance/vault error:", err);
    res.status(500).json({ error: "Failed to get vault address" });
  }
});

/**
 * POST /api/balance/deposit
 * Confirm a deposit transaction and credit user's balance.
 * Body: { txSignature: string }
 */
router.post("/balance/deposit", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const { txSignature } = req.body;

    if (!txSignature || typeof txSignature !== "string") {
      res.status(400).json({ error: "txSignature is required" });
      return;
    }

    const result = await confirmDeposit(address, txSignature);

    if (!result.success) {
      res.status(400).json({ error: result.error });
      return;
    }

    res.json({
      success: true,
      newBalance: result.newBalance,
    });
  } catch (err) {
    console.error("[Balance] POST /balance/deposit error:", err);
    res.status(500).json({ error: "Failed to confirm deposit" });
  }
});

/**
 * POST /api/balance/withdraw
 * Withdraw USDC from platform balance to user's wallet.
 * Body: { amount: number }
 */
router.post("/balance/withdraw", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const { amount } = req.body;

    if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
      res.status(400).json({ error: "Valid amount is required" });
      return;
    }

    const result = await processWithdrawal(address, amount);

    if (!result.success) {
      res.status(400).json({ error: result.error });
      return;
    }

    res.json({
      success: true,
      txSignature: result.txSignature,
    });
  } catch (err) {
    console.error("[Balance] POST /balance/withdraw error:", err);
    res.status(500).json({ error: "Failed to process withdrawal" });
  }
});

/**
 * GET /api/balance/transactions
 * Get recent balance transactions.
 */
router.get("/balance/transactions", requireAuth, async (req: AuthRequest, res) => {
  try {
    const address = req.userAddress!;
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
    const transactions = await getBalanceTransactions(address, limit);
    res.json({ transactions });
  } catch (err) {
    console.error("[Balance] GET /balance/transactions error:", err);
    res.status(500).json({ error: "Failed to fetch transactions" });
  }
});

// ── Admin endpoints ──────────────────────────────────────────────

/**
 * GET /api/balance/admin/check
 * Check if the current user is an admin.
 */
router.get("/balance/admin/check", requireAuth, async (req: AuthRequest, res) => {
  const isAdmin = !!config.adminAddress && req.userAddress === config.adminAddress;
  res.json({ isAdmin });
});

/**
 * GET /api/balance/admin/stats
 * Get platform rake stats (admin only).
 */
router.get("/balance/admin/stats", requireAuth, requireAdmin, async (_req, res) => {
  try {
    const stats = await getPlatformStats();
    res.json(stats);
  } catch (err) {
    console.error("[Balance] GET /balance/admin/stats error:", err);
    res.status(500).json({ error: "Failed to fetch platform stats" });
  }
});

/**
 * POST /api/balance/admin/withdraw-rake
 * Withdraw accumulated rake to admin wallet (admin only).
 */
router.post("/balance/admin/withdraw-rake", requireAuth, requireAdmin, async (req: AuthRequest, res) => {
  try {
    const result = await withdrawRake(req.userAddress!);
    if (!result.success) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json({ success: true, txSignature: result.txSignature });
  } catch (err) {
    console.error("[Balance] POST /balance/admin/withdraw-rake error:", err);
    res.status(500).json({ error: "Failed to withdraw rake" });
  }
});

export default router;
