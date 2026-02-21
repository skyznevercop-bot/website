import { Connection, Keypair, PublicKey } from "@solana/web3.js";
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

export function getUsdcMint(): PublicKey {
  return new PublicKey(config.usdcMint);
}
