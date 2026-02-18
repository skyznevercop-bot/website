import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  TransactionInstruction,
  sendAndConfirmTransaction,
  SystemProgram,
  ComputeBudgetProgram,
} from "@solana/web3.js";
import {
  getAssociatedTokenAddress,
  TOKEN_PROGRAM_ID,
  ASSOCIATED_TOKEN_PROGRAM_ID,
} from "@solana/spl-token";
import { createHash } from "crypto";
import { config } from "../config";

// ── Connection & Keys ───────────────────────────────────────────

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

// ── Compute Budget Optimization ─────────────────────────────────

/**
 * Compute unit limits per instruction type.
 * These are set conservatively above actual usage to avoid failures,
 * but well below the 200k default to reduce base fees.
 */
const COMPUTE_UNITS: Record<string, number> = {
  start_game: 80_000,       // Account creation + init (~40-60k actual)
  end_game: 40_000,         // State updates + profile writes (~20-30k actual)
  cancel_pending_game: 20_000, // Simple state update (~10k actual)
  refund_escrow: 50_000,    // Token transfers + state (~30-40k actual)
  close_game: 30_000,       // Account close + token close (~15-20k actual)
  refund_and_close: 80_000, // Combined refund + close (~50-60k actual)
};

/**
 * Get the recent median priority fee from the cluster.
 * Returns a value in micro-lamports per compute unit.
 * Falls back to 1 micro-lamport if the RPC call fails.
 */
async function getRecentPriorityFee(): Promise<number> {
  try {
    const connection = getConnection();
    const fees = await connection.getRecentPrioritizationFees();
    if (!fees.length) return 1;

    // Use the median of recent fees, clamped to a reasonable max.
    const sorted = fees
      .map((f) => f.prioritizationFee)
      .filter((f) => f > 0)
      .sort((a, b) => a - b);

    if (!sorted.length) return 1;

    const median = sorted[Math.floor(sorted.length / 2)];
    // Cap at 50,000 micro-lamports/CU to avoid overpaying during spikes.
    return Math.min(median, 50_000);
  } catch {
    return 1; // 1 micro-lamport fallback
  }
}

/**
 * Add compute budget instructions (unit limit + priority fee) to a transaction.
 */
async function addComputeBudget(tx: Transaction, instructionName: string): Promise<void> {
  const units = COMPUTE_UNITS[instructionName] || 100_000;
  const priorityFee = await getRecentPriorityFee();

  // Prepend compute budget instructions (must come before program instructions).
  tx.instructions.unshift(
    ComputeBudgetProgram.setComputeUnitLimit({ units }),
    ComputeBudgetProgram.setComputeUnitPrice({ microLamports: priorityFee })
  );
}

// ── PDA Derivation ──────────────────────────────────────────────

export function findPDA(seeds: Buffer[]): [PublicKey, number] {
  return PublicKey.findProgramAddressSync(seeds, getProgramId());
}

export function getPlatformPDA(): [PublicKey, number] {
  return findPDA([Buffer.from("platform")]);
}

export function getPlayerProfilePDA(player: PublicKey): [PublicKey, number] {
  return findPDA([Buffer.from("player"), player.toBuffer()]);
}

export function getGamePDA(gameId: bigint): [PublicKey, number] {
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64LE(gameId);
  return findPDA([Buffer.from("game"), buf]);
}

/** Derive the Game PDA and its escrow token account (ATA of the game PDA for USDC). */
export async function getGamePdaAndEscrow(
  gameId: bigint
): Promise<{ gamePda: PublicKey; escrowTokenAccount: PublicKey }> {
  const [gamePda] = getGamePDA(gameId);
  const escrowTokenAccount = await getAssociatedTokenAddress(
    getUsdcMint(),
    gamePda,
    true // allowOwnerOffCurve — PDA is not on the ed25519 curve
  );
  return { gamePda, escrowTokenAccount };
}

// ── Anchor Instruction Discriminator ────────────────────────────

function anchorDiscriminator(methodName: string): Buffer {
  return createHash("sha256")
    .update(`global:${methodName}`)
    .digest()
    .slice(0, 8);
}

// ── On-chain Game Account Types ─────────────────────────────────

/** GameStatus enum values matching the Rust enum order. */
export enum GameStatus {
  Pending = 0,
  Active = 1,
  Settled = 2,
  Cancelled = 3,
  Tied = 4,
  Forfeited = 5,
}

export interface OnChainGame {
  gameId: bigint;
  playerOne: PublicKey;
  playerTwo: PublicKey;
  betAmount: bigint;
  timeframeSeconds: number;
  escrowTokenAccount: PublicKey;
  status: GameStatus;
  winner: PublicKey | null;
  playerOnePnl: bigint;
  playerTwoPnl: bigint;
  playerOneDeposited: boolean;
  playerTwoDeposited: boolean;
  startTime: bigint;
  endTime: bigint;
  settledAt: bigint;
  bump: number;
}

export interface OnChainPlatform {
  authority: PublicKey;
  feeBps: number;
  treasury: PublicKey;
  totalGames: bigint;
  totalVolume: bigint;
  bump: number;
}

// ── Account Deserialization ─────────────────────────────────────

function deserializePlatform(data: Buffer): OnChainPlatform {
  let offset = 8; // skip 8-byte Anchor discriminator

  const authority = new PublicKey(data.slice(offset, offset + 32));
  offset += 32;
  const feeBps = data.readUInt16LE(offset);
  offset += 2;
  const treasury = new PublicKey(data.slice(offset, offset + 32));
  offset += 32;
  const totalGames = data.readBigUInt64LE(offset);
  offset += 8;
  const totalVolume = data.readBigUInt64LE(offset);
  offset += 8;
  const bump = data[offset];

  return { authority, feeBps, treasury, totalGames, totalVolume, bump };
}

function deserializeGame(data: Buffer): OnChainGame {
  let offset = 8; // skip 8-byte Anchor discriminator

  const gameId = data.readBigUInt64LE(offset);
  offset += 8;
  const playerOne = new PublicKey(data.slice(offset, offset + 32));
  offset += 32;
  const playerTwo = new PublicKey(data.slice(offset, offset + 32));
  offset += 32;
  const betAmount = data.readBigUInt64LE(offset);
  offset += 8;
  const timeframeSeconds = data.readUInt32LE(offset);
  offset += 4;
  const escrowTokenAccount = new PublicKey(data.slice(offset, offset + 32));
  offset += 32;
  const status: GameStatus = data[offset];
  offset += 1;

  // Borsh Option<Pubkey>: variable length
  //   None = 0x00 (1 byte total)
  //   Some = 0x01 + 32 bytes (33 bytes total)
  const hasWinner = data[offset] === 1;
  offset += 1;
  let winner: PublicKey | null = null;
  if (hasWinner) {
    winner = new PublicKey(data.slice(offset, offset + 32));
    offset += 32;
  }

  const playerOnePnl = data.readBigInt64LE(offset);
  offset += 8;
  const playerTwoPnl = data.readBigInt64LE(offset);
  offset += 8;
  const playerOneDeposited = data[offset] === 1;
  offset += 1;
  const playerTwoDeposited = data[offset] === 1;
  offset += 1;
  const startTime = data.readBigInt64LE(offset);
  offset += 8;
  const endTime = data.readBigInt64LE(offset);
  offset += 8;
  const settledAt = data.readBigInt64LE(offset);
  offset += 8;
  const bump = data[offset];

  return {
    gameId,
    playerOne,
    playerTwo,
    betAmount,
    timeframeSeconds,
    escrowTokenAccount,
    status,
    winner,
    playerOnePnl,
    playerTwoPnl,
    playerOneDeposited,
    playerTwoDeposited,
    startTime,
    endTime,
    settledAt,
    bump,
  };
}

// ── Account Reads ───────────────────────────────────────────────

export async function fetchPlatformAccount(): Promise<OnChainPlatform | null> {
  const connection = getConnection();
  const [platformPda] = getPlatformPDA();
  const info = await connection.getAccountInfo(platformPda);
  if (!info) return null;
  return deserializePlatform(info.data as Buffer);
}

export async function fetchGameAccount(
  gameId: bigint
): Promise<OnChainGame | null> {
  const connection = getConnection();
  const [gamePda] = getGamePDA(gameId);
  const info = await connection.getAccountInfo(gamePda);
  if (!info) return null;
  return deserializeGame(info.data as Buffer);
}

/** Check if a player profile PDA exists on-chain. */
export async function playerProfileExists(player: string): Promise<boolean> {
  const connection = getConnection();
  const playerPubkey = new PublicKey(player);
  const [profilePda] = getPlayerProfilePDA(playerPubkey);
  const info = await connection.getAccountInfo(profilePda);
  return info !== null;
}

// ── On-Chain Instructions ───────────────────────────────────────

/**
 * Create a new game on-chain. Called by the backend after matchmaking.
 * Returns the on-chain game ID.
 */
export async function startGameOnChain(
  player1: string,
  player2: string,
  betAmountUsdc: number,
  timeframeSeconds: number
): Promise<number> {
  const connection = getConnection();
  const authority = getAuthorityKeypair();
  const programId = getProgramId();
  const usdcMint = getUsdcMint();

  // Read Platform to determine the next game_id.
  const platform = await fetchPlatformAccount();
  if (!platform) {
    throw new Error("Platform account not found — has initialize_platform been called?");
  }

  const nextGameId = platform.totalGames + 1n;
  const [platformPda] = getPlatformPDA();
  const [gamePda] = getGamePDA(nextGameId);
  const escrowTokenAccount = await getAssociatedTokenAddress(
    usdcMint,
    gamePda,
    true
  );

  const player1Pubkey = new PublicKey(player1);
  const player2Pubkey = new PublicKey(player2);

  // Serialize arguments: bet_amount (u64) + timeframe_seconds (u32)
  const betAmountLamports = BigInt(Math.round(betAmountUsdc * 1_000_000));
  const argsBuf = Buffer.alloc(12);
  argsBuf.writeBigUInt64LE(betAmountLamports, 0);
  argsBuf.writeUInt32LE(timeframeSeconds, 8);

  const data = Buffer.concat([anchorDiscriminator("start_game"), argsBuf]);

  const ix = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: platformPda, isSigner: false, isWritable: true },
      { pubkey: gamePda, isSigner: false, isWritable: true },
      { pubkey: escrowTokenAccount, isSigner: false, isWritable: true },
      { pubkey: usdcMint, isSigner: false, isWritable: false },
      { pubkey: authority.publicKey, isSigner: true, isWritable: true },
      { pubkey: player1Pubkey, isSigner: false, isWritable: false },
      { pubkey: player2Pubkey, isSigner: false, isWritable: false },
      { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
      { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
      { pubkey: ASSOCIATED_TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    ],
    data,
  });

  const tx = new Transaction().add(ix);
  await addComputeBudget(tx, "start_game");
  const sig = await sendAndConfirmTransaction(connection, tx, [authority], {
    commitment: "confirmed",
  });

  console.log(
    `[Solana] start_game: gameId=${nextGameId} | ${player1} vs ${player2} | ${betAmountUsdc} USDC | sig: ${sig}`
  );

  return Number(nextGameId);
}

/**
 * Settle a game on-chain. Called by the backend after determining the winner.
 */
export async function endGameOnChain(
  gameId: number,
  winner: string | null,
  p1PnlBps: number,
  p2PnlBps: number,
  isForfeit: boolean
): Promise<string> {
  const connection = getConnection();
  const authority = getAuthorityKeypair();
  const programId = getProgramId();

  const bigGameId = BigInt(gameId);
  const [platformPda] = getPlatformPDA();
  const [gamePda] = getGamePDA(bigGameId);

  // Read the game to get player addresses for profile PDAs.
  const game = await fetchGameAccount(bigGameId);
  if (!game) throw new Error(`Game ${gameId} not found on-chain`);

  const [p1ProfilePda] = getPlayerProfilePDA(game.playerOne);
  const [p2ProfilePda] = getPlayerProfilePDA(game.playerTwo);

  // Serialize arguments:
  //   winner: Option<Pubkey> (1 byte + 32 bytes if Some)
  //   player_one_pnl: i64 (8 bytes)
  //   player_two_pnl: i64 (8 bytes)
  //   is_forfeit: bool (1 byte)
  const argParts: Buffer[] = [];

  // Option<Pubkey>
  if (winner) {
    const optBuf = Buffer.alloc(33);
    optBuf[0] = 1;
    new PublicKey(winner).toBuffer().copy(optBuf, 1);
    argParts.push(optBuf);
  } else {
    argParts.push(Buffer.from([0]));
  }

  // i64 player_one_pnl
  const p1PnlBuf = Buffer.alloc(8);
  p1PnlBuf.writeBigInt64LE(BigInt(p1PnlBps));
  argParts.push(p1PnlBuf);

  // i64 player_two_pnl
  const p2PnlBuf = Buffer.alloc(8);
  p2PnlBuf.writeBigInt64LE(BigInt(p2PnlBps));
  argParts.push(p2PnlBuf);

  // bool is_forfeit
  argParts.push(Buffer.from([isForfeit ? 1 : 0]));

  const data = Buffer.concat([anchorDiscriminator("end_game"), ...argParts]);

  const ix = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: platformPda, isSigner: false, isWritable: false },
      { pubkey: gamePda, isSigner: false, isWritable: true },
      { pubkey: p1ProfilePda, isSigner: false, isWritable: true },
      { pubkey: p2ProfilePda, isSigner: false, isWritable: true },
      { pubkey: authority.publicKey, isSigner: true, isWritable: false },
    ],
    data,
  });

  const tx = new Transaction().add(ix);
  await addComputeBudget(tx, "end_game");
  const sig = await sendAndConfirmTransaction(connection, tx, [authority], {
    commitment: "confirmed",
  });

  console.log(
    `[Solana] end_game: gameId=${gameId} | winner=${winner || "tie"} | forfeit=${isForfeit} | sig: ${sig}`
  );

  return sig;
}

/**
 * Cancel a pending game on-chain (deposit timeout).
 */
export async function cancelPendingGameOnChain(
  gameId: number
): Promise<string> {
  const connection = getConnection();
  const authority = getAuthorityKeypair();
  const programId = getProgramId();

  const bigGameId = BigInt(gameId);
  const [platformPda] = getPlatformPDA();
  const [gamePda] = getGamePDA(bigGameId);

  const data = anchorDiscriminator("cancel_pending_game");

  const ix = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: platformPda, isSigner: false, isWritable: false },
      { pubkey: gamePda, isSigner: false, isWritable: true },
      { pubkey: authority.publicKey, isSigner: true, isWritable: false },
    ],
    data,
  });

  const tx = new Transaction().add(ix);
  await addComputeBudget(tx, "cancel_pending_game");
  const sig = await sendAndConfirmTransaction(connection, tx, [authority], {
    commitment: "confirmed",
  });

  console.log(`[Solana] cancel_pending_game: gameId=${gameId} | sig: ${sig}`);
  return sig;
}

/**
 * Refund escrow to both players on-chain (for Tied or Cancelled games).
 * Permissionless — backend signs as caller.
 */
export async function refundEscrowOnChain(
  gameId: number,
  player1: string,
  player2: string
): Promise<string> {
  const connection = getConnection();
  const authority = getAuthorityKeypair();
  const programId = getProgramId();
  const usdcMint = getUsdcMint();

  const bigGameId = BigInt(gameId);
  const [gamePda] = getGamePDA(bigGameId);
  const escrowTokenAccount = await getAssociatedTokenAddress(
    usdcMint,
    gamePda,
    true
  );

  const player1Pubkey = new PublicKey(player1);
  const player2Pubkey = new PublicKey(player2);
  const p1TokenAccount = await getAssociatedTokenAddress(usdcMint, player1Pubkey);
  const p2TokenAccount = await getAssociatedTokenAddress(usdcMint, player2Pubkey);

  const data = anchorDiscriminator("refund_escrow");

  const ix = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: gamePda, isSigner: false, isWritable: true },
      { pubkey: escrowTokenAccount, isSigner: false, isWritable: true },
      { pubkey: p1TokenAccount, isSigner: false, isWritable: true },
      { pubkey: p2TokenAccount, isSigner: false, isWritable: true },
      { pubkey: authority.publicKey, isSigner: true, isWritable: false },
      { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    ],
    data,
  });

  const tx = new Transaction().add(ix);
  await addComputeBudget(tx, "refund_escrow");
  const sig = await sendAndConfirmTransaction(connection, tx, [authority], {
    commitment: "confirmed",
  });

  console.log(`[Solana] refund_escrow: gameId=${gameId} | sig: ${sig}`);
  return sig;
}

/**
 * Close a fully-settled game account on-chain to reclaim rent.
 * Escrow token account must be empty (all funds claimed/refunded).
 * Authority only.
 */
export async function closeGameOnChain(gameId: number): Promise<string> {
  const connection = getConnection();
  const authority = getAuthorityKeypair();
  const programId = getProgramId();
  const usdcMint = getUsdcMint();

  const bigGameId = BigInt(gameId);
  const [platformPda] = getPlatformPDA();
  const [gamePda] = getGamePDA(bigGameId);
  const escrowTokenAccount = await getAssociatedTokenAddress(
    usdcMint,
    gamePda,
    true
  );

  const data = anchorDiscriminator("close_game");

  const ix = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: platformPda, isSigner: false, isWritable: false },
      { pubkey: gamePda, isSigner: false, isWritable: true },
      { pubkey: escrowTokenAccount, isSigner: false, isWritable: true },
      { pubkey: authority.publicKey, isSigner: true, isWritable: true },
      { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    ],
    data,
  });

  const tx = new Transaction().add(ix);
  await addComputeBudget(tx, "close_game");
  const sig = await sendAndConfirmTransaction(connection, tx, [authority], {
    commitment: "confirmed",
  });

  console.log(`[Solana] close_game: gameId=${gameId} | rent reclaimed | sig: ${sig}`);
  return sig;
}

/**
 * Refund escrow AND close game in a single transaction.
 * Saves one transaction fee vs doing them separately.
 * Used for ties and cancellations where the backend controls the full flow.
 */
export async function refundAndCloseOnChain(
  gameId: number,
  player1: string,
  player2: string
): Promise<string> {
  const connection = getConnection();
  const authority = getAuthorityKeypair();
  const programId = getProgramId();
  const usdcMint = getUsdcMint();

  const bigGameId = BigInt(gameId);
  const [platformPda] = getPlatformPDA();
  const [gamePda] = getGamePDA(bigGameId);
  const escrowTokenAccount = await getAssociatedTokenAddress(
    usdcMint,
    gamePda,
    true
  );

  const player1Pubkey = new PublicKey(player1);
  const player2Pubkey = new PublicKey(player2);
  const p1TokenAccount = await getAssociatedTokenAddress(usdcMint, player1Pubkey);
  const p2TokenAccount = await getAssociatedTokenAddress(usdcMint, player2Pubkey);

  // Instruction 1: refund_escrow
  const refundIx = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: gamePda, isSigner: false, isWritable: true },
      { pubkey: escrowTokenAccount, isSigner: false, isWritable: true },
      { pubkey: p1TokenAccount, isSigner: false, isWritable: true },
      { pubkey: p2TokenAccount, isSigner: false, isWritable: true },
      { pubkey: authority.publicKey, isSigner: true, isWritable: false },
      { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    ],
    data: anchorDiscriminator("refund_escrow"),
  });

  // Instruction 2: close_game
  const closeIx = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: platformPda, isSigner: false, isWritable: false },
      { pubkey: gamePda, isSigner: false, isWritable: true },
      { pubkey: escrowTokenAccount, isSigner: false, isWritable: true },
      { pubkey: authority.publicKey, isSigner: true, isWritable: true },
      { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
    ],
    data: anchorDiscriminator("close_game"),
  });

  const tx = new Transaction().add(refundIx, closeIx);
  await addComputeBudget(tx, "refund_and_close");
  const sig = await sendAndConfirmTransaction(connection, tx, [authority], {
    commitment: "confirmed",
  });

  console.log(`[Solana] refund_and_close: gameId=${gameId} | refunded + rent reclaimed | sig: ${sig}`);
  return sig;
}
