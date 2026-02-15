/**
 * Initialize the SolFight platform PDA on mainnet.
 * Run after deploying the program:
 *   npx ts-node scripts/initialize_platform.ts
 */

import {
  Connection,
  Keypair,
  PublicKey,
  TransactionMessage,
  VersionedTransaction,
  TransactionInstruction,
} from "@solana/web3.js";
import { createHash } from "crypto";
import fs from "fs";
import path from "path";

const PROGRAM_ID = new PublicKey("268xoH5VPMgtcuaBgXimyRHebsubszqQzPUrU5duJLL8");
const TREASURY = new PublicKey("5NXJKzgx9FbR9jx6XXHLP9zdJdY8gfaLfr6wzo9eZdzJ");
const FEE_BPS = 1000; // 10%

const RPC_URL = process.env.SOLANA_RPC_URL || "https://api.mainnet-beta.solana.com";

function anchorDiscriminator(name: string): Buffer {
  return createHash("sha256")
    .update(`global:${name}`)
    .digest()
    .subarray(0, 8);
}

async function main() {
  // Load authority keypair.
  const keypairPath = process.env.AUTHORITY_KEYPAIR_PATH
    || path.join(process.env.HOME!, ".config", "solana", "id.json");
  const secretKey = JSON.parse(fs.readFileSync(keypairPath, "utf-8"));
  const authority = Keypair.fromSecretKey(Uint8Array.from(secretKey));

  console.log("Authority:", authority.publicKey.toBase58());
  console.log("Treasury:", TREASURY.toBase58());
  console.log("Fee BPS:", FEE_BPS, `(${FEE_BPS / 100}%)`);
  console.log("Program ID:", PROGRAM_ID.toBase58());
  console.log("");

  const connection = new Connection(RPC_URL, "confirmed");

  // Derive platform PDA.
  const [platformPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("platform")],
    PROGRAM_ID,
  );
  console.log("Platform PDA:", platformPda.toBase58());

  // Check if already initialized.
  const existing = await connection.getAccountInfo(platformPda);
  if (existing) {
    console.log("Platform PDA already exists! Skipping initialization.");
    return;
  }

  // Build initialize_platform instruction.
  const disc = anchorDiscriminator("initialize_platform");
  const data = Buffer.alloc(8 + 2);
  disc.copy(data, 0);
  data.writeUInt16LE(FEE_BPS, 8);

  const ix = new TransactionInstruction({
    programId: PROGRAM_ID,
    keys: [
      { pubkey: platformPda, isSigner: false, isWritable: true },
      { pubkey: authority.publicKey, isSigner: true, isWritable: true },
      { pubkey: TREASURY, isSigner: false, isWritable: false },
      { pubkey: new PublicKey("11111111111111111111111111111111"), isSigner: false, isWritable: false },
    ],
    data,
  });

  const { blockhash, lastValidBlockHeight } =
    await connection.getLatestBlockhash("confirmed");

  const message = new TransactionMessage({
    payerKey: authority.publicKey,
    recentBlockhash: blockhash,
    instructions: [ix],
  }).compileToV0Message();

  const tx = new VersionedTransaction(message);
  tx.sign([authority]);

  console.log("Sending initialize_platform transaction...");
  const sig = await connection.sendTransaction(tx, { skipPreflight: false });
  console.log("Signature:", sig);

  await connection.confirmTransaction(
    { signature: sig, blockhash, lastValidBlockHeight },
    "confirmed",
  );
  console.log("Platform initialized successfully!");
  console.log("");
  console.log("=== Environment Variables for Render ===");
  console.log(`PROGRAM_ID=268xoH5VPMgtcuaBgXimyRHebsubszqQzPUrU5duJLL8`);
  console.log(`TREASURY_ADDRESS=5NXJKzgx9FbR9jx6XXHLP9zdJdY8gfaLfr6wzo9eZdzJ`);
  console.log(`AUTHORITY_KEYPAIR=${JSON.stringify(Array.from(authority.secretKey))}`);
}

main().catch((err) => {
  console.error("Error:", err);
  process.exit(1);
});
