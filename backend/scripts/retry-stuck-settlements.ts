/**
 * Admin script: retry on-chain settlement for matches that are settled in
 * Firebase (tied/completed/forfeited) but have onChainSettled=false.
 *
 * Root cause: end_game requires both player profile PDAs to exist on-chain.
 * If a player skipped profile creation before depositing, end_game fails and
 * the match stays stuck with funds in escrow.
 *
 * This script:
 *   1. Finds all stuck matches.
 *   2. Checks if player profiles exist.
 *   3. If profiles exist → calls end_game + processMatchPayout.
 *   4. If profiles missing → reports which player must create a profile.
 *
 * NOTE: The backend cannot create player profiles — create_profile requires
 * the player as a Signer. Affected players must visit the app and complete
 * profile creation. Once they do, this script (or the auto-retry loop) will
 * settle the match automatically.
 *
 * Usage:
 *   FIREBASE_SERVICE_ACCOUNT=./backend/firebase-service-account.json \
 *   AUTHORITY_KEYPAIR='[...]' \
 *   npx tsx backend/scripts/retry-stuck-settlements.ts
 */

import "../src/services/firebase"; // initialise Firebase Admin
import { getMatchesByStatus, getMatch, updateMatch } from "../src/services/firebase";
import {
  playerProfileExists,
  fetchGameAccount,
  endGameOnChain,
  GameStatus,
} from "../src/utils/solana";
import { processMatchPayout } from "../src/services/escrow";

const SETTLED_STATUSES = ["tied", "completed", "forfeited"] as const;

interface MatchResult {
  id: string;
  status: string;
  outcome: "settled" | "already_settled" | "missing_profiles" | "failed" | "no_game_id";
  detail?: string;
  missingProfiles?: string[];
}

async function run() {
  console.log("[retry-settlements] Scanning for stuck matches…\n");

  const results: MatchResult[] = [];
  let settledCount = 0;
  let skippedCount = 0;
  let blockedCount = 0;
  let failedCount = 0;

  for (const status of SETTLED_STATUSES) {
    const matches = await getMatchesByStatus(status);
    const stuck = matches.filter((m) => !m.data.onChainSettled && m.data.onChainGameId);

    if (stuck.length === 0) {
      console.log(`[retry-settlements] No stuck '${status}' matches.`);
      continue;
    }

    console.log(`[retry-settlements] Found ${stuck.length} stuck '${status}' match(es):`);

    for (const { id, data: match } of stuck) {
      console.log(`\n  → Match ${id}`);
      console.log(`     Players: ${match.player1?.slice(0, 8)}… vs ${match.player2?.slice(0, 8)}…`);
      console.log(`     onChainGameId: ${match.onChainGameId}`);

      if (!match.onChainGameId) {
        console.log(`     ✗ No onChainGameId — skipping`);
        results.push({ id, status, outcome: "no_game_id" });
        skippedCount++;
        continue;
      }

      // Check player profiles.
      const [p1HasProfile, p2HasProfile] = await Promise.all([
        playerProfileExists(match.player1),
        playerProfileExists(match.player2),
      ]);

      if (!p1HasProfile || !p2HasProfile) {
        const missing = [
          !p1HasProfile ? match.player1 : null,
          !p2HasProfile ? match.player2 : null,
        ].filter((x): x is string => x !== null);

        console.log(`     ✗ Missing on-chain profile(s):`);
        for (const addr of missing) {
          console.log(`       - ${addr}`);
        }
        console.log(`     → Player(s) must visit the app to create their profile.`);
        console.log(`       The auto-retry loop will settle once profiles exist.`);

        results.push({ id, status, outcome: "missing_profiles", missingProfiles: missing });
        blockedCount++;
        continue;
      }

      // Check on-chain game status.
      const onChainGame = await fetchGameAccount(BigInt(match.onChainGameId));
      if (!onChainGame) {
        console.log(`     ✗ On-chain game account not found — may have been closed already`);
        await updateMatch(id, { onChainSettled: true });
        console.log(`     ✓ Marked onChainSettled=true in Firebase`);
        results.push({ id, status, outcome: "already_settled", detail: "game account not found, marked settled" });
        skippedCount++;
        continue;
      }

      if (onChainGame.status !== GameStatus.Active) {
        // Already settled on-chain — sync Firebase.
        console.log(`     ✓ Already settled on-chain (status=${onChainGame.status}) — syncing Firebase`);
        await updateMatch(id, { onChainSettled: true });
        const updatedMatch = await getMatch(id);
        if (updatedMatch) {
          try {
            await processMatchPayout(id, updatedMatch);
            console.log(`     ✓ Payout processed`);
          } catch (err) {
            console.warn(`     ⚠ Payout failed (may already be processed): ${err}`);
          }
        }
        results.push({ id, status, outcome: "already_settled" });
        settledCount++;
        continue;
      }

      // Game is Active — call end_game.
      try {
        const isForfeit = status === "forfeited";
        const p1PnlBps = Math.round((match.player1Roi || 0) * 10000);
        const p2PnlBps = Math.round((match.player2Roi || 0) * 10000);

        console.log(`     Calling end_game (winner=${match.winner || "tie"}, isForfeit=${isForfeit})…`);
        const sig = await endGameOnChain(
          match.onChainGameId,
          match.winner || null,
          p1PnlBps,
          p2PnlBps,
          isForfeit
        );
        console.log(`     ✓ end_game succeeded | sig: ${sig}`);

        await updateMatch(id, { onChainSettled: true });

        const updatedMatch = await getMatch(id);
        if (updatedMatch) {
          await processMatchPayout(id, updatedMatch);
          console.log(`     ✓ Payout processed`);
        }

        results.push({ id, status, outcome: "settled", detail: sig });
        settledCount++;
      } catch (err) {
        console.error(`     ✗ end_game failed: ${err}`);
        results.push({ id, status, outcome: "failed", detail: String(err) });
        failedCount++;
      }
    }
  }

  console.log("\n═══════════════════════════════════════");
  console.log("[retry-settlements] Summary:");
  console.log(`  Settled:          ${settledCount}`);
  console.log(`  Skipped/synced:   ${skippedCount}`);
  console.log(`  Blocked (no profile): ${blockedCount}`);
  console.log(`  Failed:           ${failedCount}`);

  if (blockedCount > 0) {
    console.log("\n[retry-settlements] BLOCKED MATCHES (players need to create profiles):");
    for (const r of results.filter((r) => r.outcome === "missing_profiles")) {
      console.log(`  Match ${r.id}:`);
      for (const addr of r.missingProfiles ?? []) {
        console.log(`    - ${addr} must visit the app to create their on-chain profile`);
      }
    }
  }

  process.exit(failedCount > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error("[retry-settlements] Fatal error:", err);
  process.exit(1);
});
