import "../src/services/firebase";
import {
  fetchGameAccount, getGamePdaAndEscrow, GameStatus, getConnection,
  playerProfileExists, endGameOnChain, getAuthorityKeypair,
  getProgramId, getUsdcMint, getGamePDA,
} from "../src/utils/solana";
import { updateMatch } from "../src/services/firebase";
import {
  PublicKey, Transaction, TransactionInstruction, sendAndConfirmTransaction,
} from "@solana/web3.js";
import { getAssociatedTokenAddress, TOKEN_PROGRAM_ID } from "@solana/spl-token";
import { createHash } from "crypto";

const MATCH_ID = "-Olhrn_WiOifASbh6T43";
const GAME_ID = 19n;
const P1 = "4YXg6XK9b3gxNU11hWfo9w2YS5qL2QLM9tZgr1vWR7Zk";
const P2 = "FWhwe81GpJyiKb737uf8gSHR2wP6UzU7evrXwfmBB6wf";

function disc(name: string): Buffer {
  return createHash("sha256").update(`global:${name}`).digest().slice(0, 8);
}

async function run() {
  const [p1HasProfile, p2HasProfile] = await Promise.all([
    playerProfileExists(P1), playerProfileExists(P2),
  ]);
  console.log(`P1 profile: ${p1HasProfile}`);
  console.log(`P2 profile: ${p2HasProfile}`);
  if (!p1HasProfile || !p2HasProfile) {
    console.error("Missing profiles — cannot proceed"); process.exit(1);
  }

  console.log("\nCalling end_game (tie)...");
  const sig1 = await endGameOnChain(19, null, 0, 0, false);
  console.log(`✓ end_game: ${sig1}`);

  const conn = getConnection();
  const authority = getAuthorityKeypair();
  const [gamePda] = getGamePDA(GAME_ID);
  const { escrowTokenAccount } = await getGamePdaAndEscrow(GAME_ID);
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
  const sig2 = await sendAndConfirmTransaction(conn, new Transaction().add(ix), [authority], { commitment: "confirmed" });
  console.log(`✓ refund_escrow: ${sig2}`);

  await updateMatch(MATCH_ID, { status: "cancelled", onChainSettled: true, escrowState: "refunded" });
  console.log("✓ Firebase synced.");
  process.exit(0);
}
run().catch((e) => { console.error("FAILED:", e); process.exit(1); });
