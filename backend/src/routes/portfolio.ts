import { Router } from "express";
import { PrismaClient } from "@prisma/client";
import { AuthRequest, requireAuth } from "../middleware/auth";
import { getOnChainUsdcBalance } from "../services/wallet-monitor";

const router = Router();
const prisma = new PrismaClient();

/** POST /api/portfolio/deposit — Notify of a deposit. */
router.post("/deposit", requireAuth, async (req: AuthRequest, res) => {
  const { signature, amount } = req.body;

  if (!signature || typeof amount !== "number" || amount <= 0) {
    res.status(400).json({ error: "Invalid signature or amount" });
    return;
  }

  // Create a pending transaction — wallet monitor will confirm on-chain.
  const tx = await prisma.transaction.create({
    data: {
      userAddress: req.userAddress!,
      type: "DEPOSIT",
      amount,
      status: "PENDING",
      signature,
    },
  });

  res.json({
    transactionId: tx.id,
    status: "PENDING",
    message: "Deposit will be confirmed after on-chain verification",
  });
});

/** POST /api/portfolio/withdraw — Request a withdrawal. */
router.post("/withdraw", requireAuth, async (req: AuthRequest, res) => {
  const { amount, destinationAddress } = req.body;

  if (typeof amount !== "number" || amount <= 0) {
    res.status(400).json({ error: "Invalid amount" });
    return;
  }

  const user = await prisma.user.findUnique({
    where: { walletAddress: req.userAddress! },
  });

  if (!user || user.balanceUsdc < amount) {
    res.status(400).json({ error: "Insufficient balance" });
    return;
  }

  // Deduct balance and create withdrawal transaction.
  const [tx] = await prisma.$transaction([
    prisma.transaction.create({
      data: {
        userAddress: req.userAddress!,
        type: "WITHDRAW",
        amount,
        status: "PENDING",
      },
    }),
    prisma.user.update({
      where: { walletAddress: req.userAddress! },
      data: { balanceUsdc: { decrement: amount } },
    }),
  ]);

  // TODO: Actually send USDC SPL transfer to destination address.
  // For now, mark as confirmed immediately (devnet).
  await prisma.transaction.update({
    where: { id: tx.id },
    data: { status: "CONFIRMED", signature: `devnet_withdraw_${tx.id}` },
  });

  res.json({
    transactionId: tx.id,
    status: "CONFIRMED",
    amount,
  });
});

/** GET /api/portfolio/transactions — Get transaction history. */
router.get(
  "/transactions",
  requireAuth,
  async (req: AuthRequest, res) => {
    const page = parseInt(req.query.page as string) || 1;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);
    const skip = (page - 1) * limit;

    const [transactions, total] = await Promise.all([
      prisma.transaction.findMany({
        where: { userAddress: req.userAddress! },
        orderBy: { createdAt: "desc" },
        skip,
        take: limit,
      }),
      prisma.transaction.count({
        where: { userAddress: req.userAddress! },
      }),
    ]);

    res.json({ transactions, total, page, limit });
  }
);

/** GET /api/portfolio/balance — Get user balance (on-chain + platform). */
router.get("/balance", requireAuth, async (req: AuthRequest, res) => {
  const user = await prisma.user.findUnique({
    where: { walletAddress: req.userAddress! },
  });

  const onChainBalance = await getOnChainUsdcBalance(req.userAddress!);

  res.json({
    platformBalance: user?.balanceUsdc || 0,
    onChainBalance,
  });
});

export default router;
