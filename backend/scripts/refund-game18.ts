import "../src/services/firebase";
import {
  fetchGameAccount, getGamePdaAndEscrow, GameStatus, getConnection,
  getProgramId, getUsdcMint, getGamePDA,
  getAuthorityKeypair,
} from "../src/utils/solana";
import { updateMatch } from "../src/services/firebase";
import {
  PublicKey, Transaction, TransactionInstruction, sendAndConfirmTransaction,
} from "@solana/web3.js";
import { getAssociatedTokenAddress, TOKEN_PROGRAM_ID } from "@solana/spl-token";
import { createHash } from "crypto";

const MATCH_ID = "-OlhfETzGDRFiEjW6kWh";
const GAME_ID = 18n;
const P1 = "FWhwe81GpJyiKb737uf8gSHR2wP6UzU7evrXwfmBB6wf";
const P2 = "4YXg6XK9b3gxNU11hWfo9w2YS5qL2QLM9tZgr1vWR7Zk";

function disc(name: string): Buffer {
  return createHash("sha256").update(`global:${name}`).digest().slice(0, 8);
}

async function run() {
  // Verify game is now Tied
  const game = await fetchGameAccount(GAME_ID);
  if (!game) { console.error("Game account not found"); process.exit(1); }
  console.log(`On-chain status: ${game.status} (expected ${GameStatus.Tied} = Tied)`);
  if (game.status !== GameStatus.Tied) {
    console.error("Game is not Tied — cannot refund"); process.exit(1);
  }

  const conn = getConnection();
  const authority = getAuthorityKeypair();
  const mint = getUsdcMint();
  const [gamePda] = getGamePDA(GAME_ID);
  const { escrowTokenAccount } = await getGamePdaAndEscrow(GAME_ID);
  const p1Ata = await getAssociatedTokenAddress(mint, new PublicKey(P1));
  const p2Ata = await getAssociatedTokenAddress(mint, new PublicKey(P2));

  console.log(`\ngamePda:        ${gamePda.toBase58()}`);
  console.log(`escrow:         ${escrowTokenAccount.toBase58()}`);
  console.log(`p1Ata:          ${p1Ata.toBase58()}`);
  console.log(`p2Ata:          ${p2Ata.toBase58()}`);
  console.log(`caller:         ${authority.publicKey.toBase58()}`);

  const ix = new TransactionInstruction({
    programId: getProgramId(),
    keys: [
      { pubkey: gamePda,              isSigner: false, isWritable: true },
      { pubkey: escrowTokenAccount,   isSigner: false, isWritable: true },
      { pubkey: p1Ata,                isSigner: false, isWritable: true },
      { pubkey: p2Ata,                isSigner: false, isWritable: true },
      { pubkey: authority.publicKey,  isSigner: true,  isWritable: false },
      { pubkey: TOKEN_PROGRAM_ID,     isSigner: false, isWritable: false },
    ],
    data: disc("refund_escrow"),
  });

  console.log("\nSending refund_escrow transaction...");
  const tx = new Transaction().add(ix);
  const sig = await sendAndConfirmTransaction(conn, tx, [authority], { commitment: "confirmed" });
  console.log(`✓ refund_escrow OK: ${sig}`);

  await updateMatch(MATCH_ID, { onChainSettled: true, escrowState: "refunded" });
  console.log("✓ Firebase synced — match is fully refunded.");
  process.exit(0);
}
run().catch((e) => { console.error("FAILED:", e); process.exit(1); });
