/**
 * SOL Recovery Script
 * ===================
 * Scans all on-chain Game PDA accounts and reclaims rent SOL from
 * settled/forfeited/tied/cancelled games.
 *
 * For games with empty escrow → close_game (reclaim ~0.008 SOL rent)
 * For games with funds in escrow → refund_and_close (refund players + reclaim rent)
 *
 * Usage:
 *   npx ts-node scripts/recover-sol.ts [--dry-run]
 *
 * Requires AUTHORITY_KEYPAIR, SOLANA_RPC_URL, PROGRAM_ID in .env
 */

import "../src/services/firebase";
import {
  fetchPlatformAccount,
  fetchGameAccount,
  getGamePDA,
  getGamePdaAndEscrow,
  getConnection,
  getAuthorityKeypair,
  GameStatus,
  closeGameOnChain,
  refundAndCloseOnChain,
} from "../src/utils/solana";
import { LAMPORTS_PER_SOL } from "@solana/web3.js";

const STATUS_NAMES: Record<number, string> = {
  0: "Pending",
  1: "Active",
  2: "Settled",
  3: "Cancelled",
  4: "Tied",
  5: "Forfeited",
};

// Closeable statuses (game is finished, can reclaim rent)
const CLOSEABLE = new Set([
  GameStatus.Settled,
  GameStatus.Cancelled,
  GameStatus.Tied,
  GameStatus.Forfeited,
]);

// Statuses that may still have funds in escrow that need refunding first
const NEEDS_REFUND = new Set([GameStatus.Tied, GameStatus.Cancelled]);

interface GameInfo {
  gameId: number;
  status: GameStatus;
  statusName: string;
  escrowBalance: number; // USDC in token units
  rentLamports: number; // Rent held by Game PDA
  escrowRentLamports: number; // Rent held by escrow token account
  player1: string;
  player2: string;
}

async function run() {
  const dryRun = process.argv.includes("--dry-run");
  const connection = getConnection();

  if (dryRun) {
    console.log("\n  🔍 DRY RUN MODE — no transactions will be sent\n");
  } else {
    // Verify authority keypair is available
    const authority = getAuthorityKeypair();
    console.log(`\n  🔑 Authority: ${authority.publicKey.toBase58()}`);
    const authBalance = await connection.getBalance(authority.publicKey);
    console.log(
      `  💰 Authority SOL balance: ${(authBalance / LAMPORTS_PER_SOL).toFixed(4)} SOL\n`
    );
  }

  // Step 1: Get total games from Platform account
  console.log("  📡 Fetching Platform account...");
  const platform = await fetchPlatformAccount();
  if (!platform) {
    console.error("  ❌ Platform account not found on-chain!");
    process.exit(1);
  }

  const totalGames = Number(platform.totalGames);
  console.log(`  📊 Total games created: ${totalGames}`);
  console.log(`  🔍 Scanning all game accounts...\n`);

  // Step 2: Scan all games
  const closeable: GameInfo[] = [];
  const needsRefund: GameInfo[] = [];
  const active: GameInfo[] = [];
  let alreadyClosed = 0;

  for (let i = 0; i < totalGames; i++) {
    const gameId = BigInt(i);
    const game = await fetchGameAccount(gameId);

    if (!game) {
      alreadyClosed++;
      continue;
    }

    const [gamePda] = getGamePDA(gameId);
    const { escrowTokenAccount } = await getGamePdaAndEscrow(gameId);

    // Get rent held by game PDA
    const gamePdaInfo = await connection.getAccountInfo(gamePda);
    const rentLamports = gamePdaInfo?.lamports ?? 0;

    // Get escrow token account balance + rent
    let escrowBalance = 0;
    let escrowRentLamports = 0;
    try {
      const escrowInfo = await connection.getAccountInfo(escrowTokenAccount);
      if (escrowInfo) {
        escrowRentLamports = escrowInfo.lamports;
        const balanceResp =
          await connection.getTokenAccountBalance(escrowTokenAccount);
        escrowBalance = Number(balanceResp.value.amount);
      }
    } catch {
      // Escrow already closed
    }

    const info: GameInfo = {
      gameId: i,
      status: game.status,
      statusName: STATUS_NAMES[game.status] ?? "Unknown",
      escrowBalance,
      rentLamports,
      escrowRentLamports,
      player1: game.playerOne.toBase58(),
      player2: game.playerTwo.toBase58(),
    };

    if (!CLOSEABLE.has(game.status)) {
      active.push(info);
      continue;
    }

    if (escrowBalance > 0 && NEEDS_REFUND.has(game.status)) {
      needsRefund.push(info);
    } else if (escrowBalance === 0) {
      closeable.push(info);
    } else {
      // Settled/Forfeited but escrow not empty — winner hasn't claimed yet
      // In the old system this would happen; in the new system it shouldn't
      console.log(
        `  ⚠️  Game #${i} (${info.statusName}) has ${escrowBalance / 1_000_000} USDC in escrow — skipping (unclaimed prize)`
      );
    }
  }

  // Step 3: Report findings
  console.log("  ═══════════════════════════════════════════════════");
  console.log("  SCAN RESULTS");
  console.log("  ═══════════════════════════════════════════════════");
  console.log(`  Already closed:          ${alreadyClosed}`);
  console.log(`  Active (skip):           ${active.length}`);
  console.log(`  Ready to close:          ${closeable.length}`);
  console.log(`  Needs refund + close:    ${needsRefund.length}`);

  const totalRentRecoverable = [...closeable, ...needsRefund].reduce(
    (sum, g) => sum + g.rentLamports + g.escrowRentLamports,
    0
  );
  console.log(
    `\n  💰 Estimated SOL recoverable: ${(totalRentRecoverable / LAMPORTS_PER_SOL).toFixed(4)} SOL`
  );

  if (closeable.length === 0 && needsRefund.length === 0) {
    console.log("\n  ✅ Nothing to recover — all games already closed!");
    process.exit(0);
  }

  // Print details
  if (closeable.length > 0) {
    console.log("\n  ── Games ready to close (empty escrow) ──");
    for (const g of closeable) {
      const rent = (g.rentLamports + g.escrowRentLamports) / LAMPORTS_PER_SOL;
      console.log(
        `  Game #${g.gameId} | ${g.statusName.padEnd(10)} | rent: ${rent.toFixed(6)} SOL`
      );
    }
  }

  if (needsRefund.length > 0) {
    console.log("\n  ── Games needing refund first ──");
    for (const g of needsRefund) {
      const rent = (g.rentLamports + g.escrowRentLamports) / LAMPORTS_PER_SOL;
      console.log(
        `  Game #${g.gameId} | ${g.statusName.padEnd(10)} | escrow: ${(g.escrowBalance / 1_000_000).toFixed(2)} USDC | rent: ${rent.toFixed(6)} SOL`
      );
    }
  }

  if (dryRun) {
    console.log("\n  🔍 Dry run complete. Run without --dry-run to execute.\n");
    process.exit(0);
  }

  // Step 4: Execute close transactions
  console.log("\n  ═══════════════════════════════════════════════════");
  console.log("  EXECUTING RECOVERY");
  console.log("  ═══════════════════════════════════════════════════\n");

  let recovered = 0;
  let failed = 0;
  let totalSolRecovered = 0;

  // Close games with empty escrow
  for (const g of closeable) {
    try {
      console.log(`  ⏳ Closing game #${g.gameId} (${g.statusName})...`);
      const sig = await closeGameOnChain(g.gameId);
      const sol = (g.rentLamports + g.escrowRentLamports) / LAMPORTS_PER_SOL;
      totalSolRecovered += sol;
      recovered++;
      console.log(`  ✅ Game #${g.gameId} closed | +${sol.toFixed(6)} SOL | tx: ${sig}`);
    } catch (e: any) {
      failed++;
      console.error(`  ❌ Game #${g.gameId} failed: ${e.message}`);
    }

    // Small delay to avoid rate limiting
    await sleep(500);
  }

  // Refund + close games with funds in escrow
  for (const g of needsRefund) {
    try {
      console.log(
        `  ⏳ Refunding + closing game #${g.gameId} (${g.statusName}, ${(g.escrowBalance / 1_000_000).toFixed(2)} USDC)...`
      );
      const sig = await refundAndCloseOnChain(g.gameId, g.player1, g.player2);
      const sol = (g.rentLamports + g.escrowRentLamports) / LAMPORTS_PER_SOL;
      totalSolRecovered += sol;
      recovered++;
      console.log(`  ✅ Game #${g.gameId} refunded + closed | +${sol.toFixed(6)} SOL | tx: ${sig}`);
    } catch (e: any) {
      failed++;
      console.error(`  ❌ Game #${g.gameId} failed: ${e.message}`);
    }

    await sleep(500);
  }

  // Step 5: Summary
  console.log("\n  ═══════════════════════════════════════════════════");
  console.log("  RECOVERY COMPLETE");
  console.log("  ═══════════════════════════════════════════════════");
  console.log(`  Games recovered:  ${recovered}`);
  console.log(`  Games failed:     ${failed}`);
  console.log(`  SOL recovered:    ~${totalSolRecovered.toFixed(4)} SOL`);
  console.log("");

  process.exit(0);
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
