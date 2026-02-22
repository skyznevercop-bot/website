import { Router } from "express";
import { requireAuth, AuthRequest } from "../middleware/auth";
import {
  getBalance,
  confirmDeposit,
  processWithdrawal,
  getBalanceTransactions,
  getVaultAddress,
} from "../services/balance";

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

export default router;
