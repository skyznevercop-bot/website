import { Connection, Keypair, PublicKey } from "@solana/web3.js";
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
