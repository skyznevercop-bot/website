import { getConnection, getUsdcMint } from "../utils/solana";
import { PublicKey } from "@solana/web3.js";
import {
  getAssociatedTokenAddress,
  getAccount,
} from "@solana/spl-token";

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
