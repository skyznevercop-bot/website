import "../src/services/firebase";
import {
  fetchGameAccount, getGamePdaAndEscrow, GameStatus, getConnection,
  playerProfileExists, endGameOnChain, getAuthorityKeypair,
  getProgramId, getUsdcMint, getGamePDA,
} from "../src/utils/solana";
import { getMatch, updateMatch } from "../src/services/firebase";
import {
  PublicKey, Transaction, TransactionInstruction, sendAndConfirmTransaction,
} from "@solana/web3.js";
import { getAssociatedTokenAddress, TOKEN_PROGRAM_ID } from "@solana/spl-token";
import { createHash } from "crypto";

const MATCH_ID = "-OliAFK0UaI3HL8XKTcF";
const GAME_ID = 21n;

function disc(name: string): Buffer {
  return createHash("sha256").update(`global:${name}`).digest().slice(0, 8);
}

async function run() {
  const match = await getMatch(MATCH_ID);
  if (!match) { console.error("Match not found"); process.exit(1); }
  const P1 = match.player1;
  const P2 = match.player2;
  console.log(`P1: ${P1}`);
  console.log(`P2: ${P2}`);

  const game = await fetchGameAccount(GAME_ID);
  if (!game) { console.log("Game not found on-chain — nothing to do"); process.exit(0); }

  const statusNames: Record<number, string> = {
    0: "Pending", 1: "Active", 2: "Settled", 3: "Cancelled", 4: "Tied", 5: "Forfeited"
  };
  console.log(`\nOn-chain status: ${statusNames[game.status]} (${game.status})`);
  const { escrowTokenAccount } = await getGamePdaAndEscrow(GAME_ID);
  const conn = getConnection();
  try {
    const bal = await conn.getTokenAccountBalance(escrowTokenAccount);
    console.log(`Escrow balance: ${bal.value.uiAmountString} USDC`);
  } catch { console.log("Escrow balance: (closed/empty)"); }

  if (game.status !== GameStatus.Active) {
    console.log("Game is not Active — skipping end_game");
  } else {
    const [p1HasProfile, p2HasProfile] = await Promise.all([
      playerProfileExists(P1), playerProfileExists(P2),
    ]);
    console.log(`\nP1 profile: ${p1HasProfile}`);
    console.log(`P2 profile: ${p2HasProfile}`);

    if (!p1HasProfile || !p2HasProfile) {
      console.error("Missing profiles — cannot call end_game. Attempting direct refund_escrow...");
      // Fall through to direct refund_escrow below without end_game
    } else {
      console.log("\nCalling end_game (tie)...");
      const sig1 = await endGameOnChain(Number(GAME_ID), null, 0, 0, false);
      console.log(`✓ end_game: ${sig1}`);
    }
  }

  // Call refund_escrow
  const authority = getAuthorityKeypair();
  const [gamePda] = getGamePDA(GAME_ID);
  const mint = getUsdcMint();
  const p1Ata = await getAssociatedTokenAddress(mint, new PublicKey(P1));
  const p2Ata = await getAssociatedTokenAddress(mint, new PublicKey(P2));

  const ix = new TransactionInstruction({
    programId: getProgramId(),
    keys: [
      { pubkey: gamePda,             isSigner: false, isWritable: true },
      { pubkey: escrowTokenAccount,  isSigner: false, isWritable: true },
      { pubkey: p1Ata,               isSigner: false, isWritable: true },
      { pubkey: p2Ata,               isSigner: false, isWritable: true },
      { pubkey: authority.publicKey, isSigner: true,  isWritable: false },
      { pubkey: TOKEN_PROGRAM_ID,    isSigner: false, isWritable: false },
    ],
    data: disc("refund_escrow"),
  });

  console.log("\nCalling refund_escrow...");
  try {
    const sig2 = await sendAndConfirmTransaction(conn, new Transaction().add(ix), [authority], { commitment: "confirmed" });
    console.log(`✓ refund_escrow: ${sig2}`);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    if (msg.includes("already been processed") || msg.includes("0x0")) {
      console.log("refund_escrow already done (idempotent)");
    } else {
      throw e;
    }
  }

  await updateMatch(MATCH_ID, { status: "cancelled", onChainSettled: true, escrowState: "refunded" });
  console.log("✓ Firebase synced.");
  process.exit(0);
}
run().catch(e => { console.error("FAILED:", e); process.exit(1); });
