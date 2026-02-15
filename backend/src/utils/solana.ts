import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  sendAndConfirmTransaction,
} from "@solana/web3.js";
import {
  createTransferInstruction,
  getAssociatedTokenAddress,
  createAssociatedTokenAccountIdempotentInstruction,
} from "@solana/spl-token";
import { config } from "../config";

let connectionInstance: Connection | null = null;

export function getConnection(): Connection {
  if (!connectionInstance) {
    connectionInstance = new Connection(config.solanaRpcUrl, "confirmed");
  }
  return connectionInstance;
}

let authorityKeypairInstance: Keypair | null = null;

export function getAuthorityKeypair(): Keypair {
  if (!authorityKeypairInstance) {
    if (!config.authorityKeypair) {
      throw new Error("AUTHORITY_KEYPAIR environment variable is not set");
    }
    authorityKeypairInstance = Keypair.fromSecretKey(
      Uint8Array.from(config.authorityKeypair)
    );
  }
  return authorityKeypairInstance;
}

export function getProgramId(): PublicKey {
  return new PublicKey(config.programId);
}

export function getUsdcMint(): PublicKey {
  return new PublicKey(config.usdcMint);
}

/** Derive a PDA given seeds and the program ID. */
export function findPDA(seeds: Buffer[]): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(seeds, getProgramId());
}

/** Derive the Platform PDA. */
export function getPlatformPDA(): [PublicKey, number] {
  return findPDA([Buffer.from("platform")]);
}

/** Derive a PlayerProfile PDA. */
export function getPlayerProfilePDA(player: PublicKey): [PublicKey, number] {
  return findPDA([Buffer.from("player"), player.toBuffer()]);
}

/** Derive a Game PDA from the game ID. */
export function getGamePDA(gameId: bigint): [PublicKey, number] {
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64LE(gameId);
  return findPDA([Buffer.from("game"), buf]);
}

// ── Deposit Verification ─────────────────────────────────────────

export interface DepositVerification {
  verified: boolean;
  amount: number;
  sender: string;
  error?: string;
}

/**
 * Verify a USDC deposit on-chain by parsing the transaction.
 * Checks that the tx exists, succeeded, and contains an SPL token transfer
 * from the expected sender to the escrow wallet's ATA of the expected amount.
 */
export async function verifyUsdcDeposit(
  txSignature: string,
  expectedSender: string,
  expectedAmount: number
): Promise<DepositVerification> {
  const connection = getConnection();

  // Derive the escrow wallet's USDC ATA to verify recipient.
  // Use the authority keypair (= the escrow wallet) as source of truth,
  // falling back to the config address if keypair isn't available.
  const escrowPubkey = config.authorityKeypair
    ? getAuthorityKeypair().publicKey
    : new PublicKey(config.escrowWalletAddress);
  const escrowAta = await getAssociatedTokenAddress(getUsdcMint(), escrowPubkey);
  const escrowAtaStr = escrowAta.toBase58();

  const parsedTx = await connection.getParsedTransaction(txSignature, {
    maxSupportedTransactionVersion: 0,
    commitment: "confirmed",
  });

  if (!parsedTx) {
    return { verified: false, amount: 0, sender: "", error: "Transaction not found on-chain" };
  }

  if (parsedTx.meta?.err) {
    return { verified: false, amount: 0, sender: "", error: "Transaction failed on-chain" };
  }

  // Search all instructions (including inner) for SPL token transfers.
  const allInstructions = [
    ...parsedTx.transaction.message.instructions,
    ...(parsedTx.meta?.innerInstructions?.flatMap((ii) => ii.instructions) || []),
  ];

  for (const ix of allInstructions) {
    if (!("parsed" in ix)) continue;
    if (ix.program !== "spl-token") continue;
    if (ix.parsed.type !== "transfer" && ix.parsed.type !== "transferChecked") continue;

    const info = ix.parsed.info;
    const amountRaw =
      ix.parsed.type === "transferChecked"
        ? parseInt(info.tokenAmount?.amount || "0")
        : parseInt(info.amount || "0");
    const amountUsdc = amountRaw / 1_000_000;

    // Verify sender, recipient (escrow ATA), and amount all match.
    if (
      info.authority === expectedSender &&
      info.destination === escrowAtaStr &&
      Math.abs(amountUsdc - expectedAmount) < 0.01
    ) {
      return { verified: true, amount: amountUsdc, sender: info.authority };
    }
  }

  return {
    verified: false,
    amount: 0,
    sender: "",
    error: "No matching USDC transfer to escrow found in transaction",
  };
}

// ── USDC Payout ──────────────────────────────────────────────────

/**
 * Send USDC from the escrow wallet to a recipient.
 * Creates the recipient's ATA idempotently if it doesn't exist.
 */
export async function sendUsdcPayout(
  recipientAddress: string,
  amountUsdc: number
): Promise<string> {
  const connection = getConnection();
  const authority = getAuthorityKeypair();
  const usdcMint = getUsdcMint();

  const escrowAta = await getAssociatedTokenAddress(usdcMint, authority.publicKey);
  const recipientPubkey = new PublicKey(recipientAddress);
  const recipientAta = await getAssociatedTokenAddress(usdcMint, recipientPubkey);

  const amountSmallest = BigInt(Math.round(amountUsdc * 1_000_000));

  const tx = new Transaction();

  // Create recipient ATA idempotently (payer = escrow wallet).
  tx.add(
    createAssociatedTokenAccountIdempotentInstruction(
      authority.publicKey,
      recipientAta,
      recipientPubkey,
      usdcMint
    )
  );

  // Transfer USDC from escrow to recipient.
  tx.add(
    createTransferInstruction(
      escrowAta,
      recipientAta,
      authority.publicKey,
      amountSmallest
    )
  );

  const signature = await sendAndConfirmTransaction(connection, tx, [authority], {
    commitment: "confirmed",
  });

  return signature;
}

/**
 * Send USDC payout with retry logic for transient failures.
 */
export async function sendUsdcPayoutWithRetry(
  recipientAddress: string,
  amountUsdc: number,
  maxRetries: number = config.payoutRetryAttempts,
  delayMs: number = config.payoutRetryDelayMs
): Promise<string> {
  let lastError: Error | null = null;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const sig = await sendUsdcPayout(recipientAddress, amountUsdc);
      console.log(
        `[Escrow] Payout sent: ${amountUsdc} USDC to ${recipientAddress} | sig: ${sig} | attempt ${attempt}`
      );
      return sig;
    } catch (err) {
      lastError = err as Error;
      console.error(
        `[Escrow] Payout attempt ${attempt}/${maxRetries} failed for ${recipientAddress}:`,
        err
      );
      if (attempt < maxRetries) {
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }

  throw new Error(`Payout failed after ${maxRetries} attempts: ${lastError?.message}`);
}
