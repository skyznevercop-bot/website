import {
  usersRef,
  matchesRef,
  getUser,
  db,
} from "./firebase";
import { config } from "../config";
import {
  getConnection,
  getAuthorityKeypair,
  getUsdcMint,
} from "../utils/solana";
import {
  getAssociatedTokenAddress,
  createAssociatedTokenAccountInstruction,
  createTransferInstruction,
  getAccount,
} from "@solana/spl-token";
import {
  PublicKey,
  Transaction,
  sendAndConfirmTransaction,
} from "@solana/web3.js";

// ── Used deposit signatures (prevents replay attacks) ────────────
const usedDepositSigsRef = db.ref("solfight/used_deposit_sigs");

// ── Types ───────────────────────────────────────────────────────

export interface BalanceInfo {
  balance: number;
  frozenBalance: number;
  available: number;
}

export interface BalanceTransaction {
  type: "deposit" | "withdraw" | "match_win" | "match_loss" | "match_tie" | "match_freeze" | "match_unfreeze";
  amount: number;
  matchId?: string;
  txSignature?: string;
  timestamp: number;
}

// ── Balance reads ───────────────────────────────────────────────

/**
 * Get a user's current balance info.
 */
export async function getBalance(address: string): Promise<BalanceInfo> {
  const user = await getUser(address);
  const balance = user?.balance ?? 0;
  const frozenBalance = user?.frozenBalance ?? 0;
  return {
    balance,
    frozenBalance,
    available: balance - frozenBalance,
  };
}

// ── Balance mutations (atomic via Firebase transactions) ────────

/**
 * Freeze a bet amount when a user joins the queue.
 * Moves funds from available balance to frozen balance.
 * Returns true if successful, false if insufficient funds.
 */
export async function freezeForMatch(
  address: string,
  amount: number
): Promise<boolean> {
  const userRef = usersRef.child(address);

  const result = await userRef.transaction((current) => {
    if (!current) return current; // user doesn't exist

    const balance = current.balance ?? 0;
    const frozenBalance = current.frozenBalance ?? 0;
    const available = balance - frozenBalance;

    if (available < amount) {
      // Abort transaction — insufficient funds.
      return undefined;
    }

    return {
      ...current,
      frozenBalance: frozenBalance + amount,
    };
  });

  return result.committed;
}

/**
 * Unfreeze a bet amount when a user leaves the queue or match is cancelled.
 */
export async function unfreezeBalance(
  address: string,
  amount: number
): Promise<void> {
  const userRef = usersRef.child(address);

  await userRef.transaction((current) => {
    if (!current) return current;

    const frozenBalance = current.frozenBalance ?? 0;
    return {
      ...current,
      frozenBalance: Math.max(0, frozenBalance - amount),
    };
  });
}

/**
 * Settle a match: transfer frozen funds based on outcome.
 *
 * Winner: gets their frozen bet back + opponent's bet - rake
 * Loser: frozen bet is removed (already "spent")
 * Tie: both get frozen bet back
 */
/**
 * Idempotent balance settlement for a match.
 *
 * Uses per-player flags on the match record (`p1BalanceSettled`, `p2BalanceSettled`)
 * to ensure each player's balance is only updated once, even if this function
 * is called multiple times (crash recovery).
 */
export async function settleMatchBalances(
  matchId: string,
  winnerId: string | undefined,
  player1: string,
  player2: string,
  betAmount: number,
  isTie: boolean
): Promise<void> {
  const rake = config.rakePercent;
  const pot = betAmount * 2;
  const winnerPayout = pot * (1 - rake); // e.g. $20 * 0.90 = $18

  // Read current settlement flags to avoid double-pay on recovery.
  const matchSnap = await matchesRef.child(matchId).once("value");
  const matchData = matchSnap.exists() ? matchSnap.val() : {};
  const p1Done = !!matchData.p1BalanceSettled;
  const p2Done = !!matchData.p2BalanceSettled;

  if (isTie) {
    // Both get their frozen bet back.
    await Promise.all([
      p1Done ? Promise.resolve() : unfreezeBalance(player1, betAmount).then(() =>
        matchesRef.child(matchId).update({ p1BalanceSettled: true })
      ),
      p2Done ? Promise.resolve() : unfreezeBalance(player2, betAmount).then(() =>
        matchesRef.child(matchId).update({ p2BalanceSettled: true })
      ),
    ]);
    console.log(`[Balance] Tie settled: both players unfrozen $${betAmount}`);
  } else if (winnerId) {
    const loserId = winnerId === player1 ? player2 : player1;
    const winnerIsP1 = winnerId === player1;
    const winnerDone = winnerIsP1 ? p1Done : p2Done;
    const loserDone = winnerIsP1 ? p2Done : p1Done;

    // Winner: unfreeze their bet + add net winnings
    if (!winnerDone) {
      const winnerRef = usersRef.child(winnerId);
      await winnerRef.transaction((current) => {
        if (!current) return current;
        const frozenBalance = current.frozenBalance ?? 0;
        const balance = current.balance ?? 0;
        return {
          ...current,
          balance: balance + (winnerPayout - betAmount), // net gain
          frozenBalance: Math.max(0, frozenBalance - betAmount),
        };
      });
      await matchesRef.child(matchId).update({
        [winnerIsP1 ? "p1BalanceSettled" : "p2BalanceSettled"]: true,
      });
    }

    // Loser: remove frozen bet from total balance
    if (!loserDone) {
      const loserRef = usersRef.child(loserId);
      await loserRef.transaction((current) => {
        if (!current) return current;
        const frozenBalance = current.frozenBalance ?? 0;
        const balance = current.balance ?? 0;
        return {
          ...current,
          balance: balance - betAmount, // deduct the lost bet
          frozenBalance: Math.max(0, frozenBalance - betAmount),
        };
      });
      await matchesRef.child(matchId).update({
        [winnerIsP1 ? "p2BalanceSettled" : "p1BalanceSettled"]: true,
      });
    }

    const netWin = winnerPayout - betAmount;
    console.log(
      `[Balance] Match settled: winner ${winnerId.slice(0, 8)}… +$${netWin.toFixed(2)} | loser ${loserId.slice(0, 8)}… -$${betAmount}`
    );
  }
}

// ── Deposit: user sends USDC to platform vault ─────────────────

/**
 * Get the platform vault token account address.
 * This is the authority's USDC ATA where user deposits go.
 */
export async function getVaultAddress(): Promise<PublicKey> {
  const authority = getAuthorityKeypair();
  const usdcMint = getUsdcMint();
  return getAssociatedTokenAddress(usdcMint, authority.publicKey);
}

/**
 * Confirm a user's deposit transaction and credit their balance.
 *
 * Security checks:
 *  1. Reject duplicate tx signatures (replay attack prevention)
 *  2. Verify the sender's token account belongs to the authenticated user
 *  3. Verify the destination is our vault
 *  4. Verify the tx succeeded on-chain
 */
export async function confirmDeposit(
  address: string,
  txSignature: string
): Promise<{ success: boolean; newBalance: number; error?: string }> {
  const connection = getConnection();

  try {
    // ── 1. Replay protection: reject if this signature was already used ──
    const sigKey = txSignature.replace(/[.#$/\[\]]/g, "_"); // Firebase-safe key
    const existingSnap = await usedDepositSigsRef.child(sigKey).once("value");
    if (existingSnap.exists()) {
      return { success: false, newBalance: 0, error: "This transaction has already been credited" };
    }

    // Parse the transaction to extract transfer details.
    const txInfo = await connection.getParsedTransaction(txSignature, {
      commitment: "confirmed",
      maxSupportedTransactionVersion: 0,
    });

    if (!txInfo || !txInfo.meta) {
      return { success: false, newBalance: 0, error: "Transaction not found or not yet confirmed" };
    }

    // Check that the transaction succeeded.
    if (txInfo.meta.err) {
      return { success: false, newBalance: 0, error: "Transaction failed on-chain" };
    }

    // ── 2 & 3. Find the SPL token transfer to our vault AND verify sender ──
    const vaultAddress = await getVaultAddress();
    const vaultStr = vaultAddress.toBase58();
    const userPubkey = new PublicKey(address);
    const userAta = await getAssociatedTokenAddress(getUsdcMint(), userPubkey);
    const userAtaStr = userAta.toBase58();

    let depositAmount = 0;
    let senderVerified = false;

    // Helper to check a single parsed instruction.
    const checkInstruction = (ix: any): boolean => {
      if (!("parsed" in ix) || ix.program !== "spl-token") return false;
      const parsed = ix.parsed;
      if (parsed.type !== "transfer" && parsed.type !== "transferChecked") return false;

      const dest = parsed.info.destination || parsed.info.tokenAccount;
      if (dest !== vaultStr) return false;

      // Extract amount.
      const amount = parsed.info.amount
        ? Number(parsed.info.amount) / 1_000_000
        : parsed.info.tokenAmount?.uiAmount ?? 0;
      if (amount <= 0) return false;

      // Verify sender is the authenticated user's token account.
      const source = parsed.info.source;
      if (source !== userAtaStr) return false;

      depositAmount = amount;
      senderVerified = true;
      return true;
    };

    // Check top-level instructions.
    for (const ix of txInfo.transaction.message.instructions) {
      if (checkInstruction(ix)) break;
    }

    // Check inner instructions (for transferChecked via ATA creation).
    if (!senderVerified && txInfo.meta.innerInstructions) {
      for (const inner of txInfo.meta.innerInstructions) {
        for (const ix of inner.instructions) {
          if (checkInstruction(ix)) break;
        }
        if (senderVerified) break;
      }
    }

    if (!senderVerified || depositAmount <= 0) {
      return {
        success: false,
        newBalance: 0,
        error: "No valid USDC transfer from your wallet to vault found in this transaction",
      };
    }

    // ── 4. Atomically claim the signature to prevent concurrent replays ──
    const claimResult = await usedDepositSigsRef.child(sigKey).transaction((current) => {
      if (current !== null) return undefined; // Already claimed — abort
      return { address, amount: depositAmount, claimedAt: Date.now() };
    });

    if (!claimResult.committed) {
      return { success: false, newBalance: 0, error: "This transaction has already been credited" };
    }

    // ── 5. Credit the user's balance atomically ──
    const userRef = usersRef.child(address);
    let newBalance = 0;

    await userRef.transaction((current) => {
      if (!current) {
        return {
          balance: depositAmount,
          frozenBalance: 0,
          totalDeposited: depositAmount,
          totalWithdrawn: 0,
          wins: 0,
          losses: 0,
          ties: 0,
          totalPnl: 0,
          currentStreak: 0,
          gamesPlayed: 0,
          createdAt: Date.now(),
        };
      }

      const balance = (current.balance ?? 0) + depositAmount;
      const totalDeposited = (current.totalDeposited ?? 0) + depositAmount;
      newBalance = balance;

      return {
        ...current,
        balance,
        totalDeposited,
      };
    });

    // Re-read for the final balance (Firebase transaction may have been retried).
    const user = await getUser(address);
    newBalance = user?.balance ?? newBalance;

    // Record the transaction.
    await recordBalanceTransaction(address, {
      type: "deposit",
      amount: depositAmount,
      txSignature,
      timestamp: Date.now(),
    });

    console.log(
      `[Balance] Deposit confirmed: ${address.slice(0, 8)}… +$${depositAmount} USDC | sig: ${txSignature.slice(0, 20)}…`
    );

    return { success: true, newBalance };
  } catch (err) {
    console.error(`[Balance] Deposit confirmation failed:`, err);
    return { success: false, newBalance: 0, error: "Failed to confirm transaction" };
  }
}

// ── Withdraw: platform sends USDC back to user ─────────────────

/**
 * Process a withdrawal: debit user's balance and send USDC on-chain.
 *
 * Security: if the on-chain send throws but the tx actually landed,
 * we verify on-chain before rolling back to prevent double-spend.
 */
export async function processWithdrawal(
  address: string,
  amount: number
): Promise<{ success: boolean; txSignature?: string; error?: string }> {
  // Validate amount.
  if (amount < 1) {
    return { success: false, error: "Minimum withdrawal is $1 USDC" };
  }

  // Atomic balance deduction.
  const userRef = usersRef.child(address);

  const txResult = await userRef.transaction((current) => {
    if (!current) return current;

    const balance = current.balance ?? 0;
    const frozenBalance = current.frozenBalance ?? 0;
    const available = balance - frozenBalance;

    if (available < amount) {
      return undefined; // abort — insufficient available balance
    }

    return {
      ...current,
      balance: balance - amount,
      totalWithdrawn: (current.totalWithdrawn ?? 0) + amount,
    };
  });

  if (!txResult.committed) {
    return { success: false, error: "Insufficient available balance" };
  }

  // Send USDC on-chain.
  let sentSignature: string | null = null;

  try {
    const connection = getConnection();
    const authority = getAuthorityKeypair();
    const usdcMint = getUsdcMint();

    const userPubkey = new PublicKey(address);
    const vaultAta = await getAssociatedTokenAddress(usdcMint, authority.publicKey);
    const userAta = await getAssociatedTokenAddress(usdcMint, userPubkey);

    const amountLamports = Math.round(amount * 1_000_000);

    const tx = new Transaction();

    // Ensure user's ATA exists (create if needed).
    try {
      await getAccount(connection, userAta);
    } catch {
      tx.add(
        createAssociatedTokenAccountInstruction(
          authority.publicKey, // payer
          userAta,
          userPubkey,
          usdcMint
        )
      );
    }

    tx.add(
      createTransferInstruction(
        vaultAta,
        userAta,
        authority.publicKey,
        amountLamports
      )
    );

    const sig = await sendAndConfirmTransaction(connection, tx, [authority], {
      commitment: "confirmed",
    });

    sentSignature = sig;

    // Record the transaction.
    await recordBalanceTransaction(address, {
      type: "withdraw",
      amount,
      txSignature: sig,
      timestamp: Date.now(),
    });

    console.log(
      `[Balance] Withdrawal sent: ${address.slice(0, 8)}… -$${amount} USDC | sig: ${sig}`
    );

    return { success: true, txSignature: sig };
  } catch (err: any) {
    // The send threw, but the tx may have actually landed on-chain.
    // Check before rolling back to prevent double-spend.
    console.error(`[Balance] Withdrawal send threw:`, err?.message ?? err);

    // Try to extract the signature from the error or the pre-signed tx.
    // sendAndConfirmTransaction can throw AFTER broadcasting if confirmation times out.
    const sigFromError =
      sentSignature ??
      (typeof err?.signature === "string" ? err.signature : null);

    if (sigFromError) {
      try {
        const connection = getConnection();
        const status = await connection.getSignatureStatus(sigFromError);
        if (
          status?.value?.confirmationStatus === "confirmed" ||
          status?.value?.confirmationStatus === "finalized"
        ) {
          // Tx actually landed — do NOT refund.
          console.warn(
            `[Balance] Withdrawal tx ${sigFromError} actually confirmed on-chain — NOT refunding`
          );

          await recordBalanceTransaction(address, {
            type: "withdraw",
            amount,
            txSignature: sigFromError,
            timestamp: Date.now(),
          });

          return { success: true, txSignature: sigFromError };
        }
      } catch (checkErr) {
        console.error(`[Balance] Failed to check withdrawal tx status:`, checkErr);
        // Fall through to refund — safer to refund than to lose user funds.
      }
    }

    // Tx definitely did not land — safe to refund.
    console.log(`[Balance] Withdrawal tx did not land — refunding balance`);

    await userRef.transaction((current) => {
      if (!current) return current;
      return {
        ...current,
        balance: (current.balance ?? 0) + amount,
        totalWithdrawn: Math.max(0, (current.totalWithdrawn ?? 0) - amount),
      };
    });

    return { success: false, error: "On-chain transfer failed. Balance has been refunded." };
  }
}

// ── Balance transaction history ─────────────────────────────────

const balanceTransactionsRef = db.ref("solfight/balance_transactions");

async function recordBalanceTransaction(
  address: string,
  tx: BalanceTransaction
): Promise<void> {
  await balanceTransactionsRef.child(address).push(tx);
}

/**
 * Get recent balance transactions for a user.
 */
export async function getBalanceTransactions(
  address: string,
  limit: number = 50
): Promise<BalanceTransaction[]> {
  const snap = await balanceTransactionsRef
    .child(address)
    .orderByChild("timestamp")
    .limitToLast(limit)
    .once("value");

  if (!snap.exists()) return [];

  const txs: BalanceTransaction[] = [];
  snap.forEach((child) => {
    txs.push(child.val() as BalanceTransaction);
  });

  // Return newest first.
  return txs.reverse();
}
