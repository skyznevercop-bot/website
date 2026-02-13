import { PrismaClient } from "@prisma/client";
import { getConnection, getUsdcMint } from "../utils/solana";
import { PublicKey } from "@solana/web3.js";
import {
  getAssociatedTokenAddress,
  getAccount,
} from "@solana/spl-token";

const prisma = new PrismaClient();

/**
 * Start monitoring for USDC deposits to the platform.
 * Uses Solana WebSocket subscription for token account changes.
 */
export function startWalletMonitor(): void {
  // In production, subscribe to token account changes via WebSocket:
  // connection.onAccountChange(platformTokenAccount, callback)

  // For now, poll every 10 seconds as a simpler approach.
  setInterval(async () => {
    try {
      await checkPendingDeposits();
    } catch (err) {
      console.error("[WalletMonitor] Error:", err);
    }
  }, 10000);

  console.log("[WalletMonitor] Started — polling every 10s");
}

/**
 * Check for pending deposit transactions and verify them on-chain.
 */
async function checkPendingDeposits(): Promise<void> {
  const pendingDeposits = await prisma.transaction.findMany({
    where: { type: "DEPOSIT", status: "PENDING" },
  });

  const connection = getConnection();

  for (const tx of pendingDeposits) {
    if (!tx.signature) continue;

    try {
      const status = await connection.getSignatureStatus(tx.signature);
      if (status.value?.confirmationStatus === "confirmed" ||
          status.value?.confirmationStatus === "finalized") {
        // Confirm the deposit.
        await prisma.$transaction([
          prisma.transaction.update({
            where: { id: tx.id },
            data: { status: "CONFIRMED" },
          }),
          prisma.user.update({
            where: { walletAddress: tx.userAddress },
            data: { balanceUsdc: { increment: tx.amount } },
          }),
        ]);

        console.log(
          `[WalletMonitor] Deposit confirmed: ${tx.amount} USDC for ${tx.userAddress}`
        );

        // Check if this user was referred — update referral status.
        await updateReferralStatus(tx.userAddress, "DEPOSITED");
      } else if (status.value?.err) {
        await prisma.transaction.update({
          where: { id: tx.id },
          data: { status: "FAILED" },
        });
      }
    } catch (err) {
      console.error(`[WalletMonitor] Error checking tx ${tx.id}:`, err);
    }
  }
}

/**
 * Update referral status when referee hits a milestone.
 */
async function updateReferralStatus(
  refereeAddress: string,
  newStatus: "DEPOSITED" | "PLAYED"
): Promise<void> {
  const referral = await prisma.referral.findUnique({
    where: { refereeAddress },
  });

  if (!referral) return;

  // Only advance status forward (JOINED → DEPOSITED → PLAYED).
  const statusOrder = ["JOINED", "DEPOSITED", "PLAYED"];
  const currentIdx = statusOrder.indexOf(referral.status);
  const newIdx = statusOrder.indexOf(newStatus);

  if (newIdx > currentIdx) {
    const reward = newStatus === "DEPOSITED" ? 5.0 : 10.0;

    await prisma.$transaction([
      prisma.referral.update({
        where: { refereeAddress },
        data: { status: newStatus, rewardPaid: { increment: reward } },
      }),
      prisma.user.update({
        where: { walletAddress: referral.referrerAddress },
        data: { balanceUsdc: { increment: reward } },
      }),
    ]);
  }
}

/**
 * Get the USDC balance of a wallet from on-chain.
 */
export async function getOnChainUsdcBalance(
  walletAddress: string
): Promise<number> {
  try {
    const connection = getConnection();
    const usdcMint = getUsdcMint();
    const owner = new PublicKey(walletAddress);
    const ata = await getAssociatedTokenAddress(usdcMint, owner);
    const account = await getAccount(connection, ata);
    // USDC has 6 decimals.
    return Number(account.amount) / 1_000_000;
  } catch {
    return 0;
  }
}
