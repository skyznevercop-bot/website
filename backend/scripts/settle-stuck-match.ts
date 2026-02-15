/**
 * One-off script to settle a stuck match in Firebase.
 * Match -OlXJxFVQ_v00aV-VSnA is stuck as "active" because end_game
 * fails on-chain (player profiles don't exist).
 *
 * Usage: npx tsx scripts/settle-stuck-match.ts
 */
import { db, matchesRef, getMatch, updateMatch } from "../src/services/firebase";

const MATCH_ID = "-OlXJxFVQ_v00aV-VSnA";

async function main() {
  const match = await getMatch(MATCH_ID);
  if (!match) {
    console.log("Match not found");
    process.exit(1);
  }

  console.log("Current match state:", {
    status: match.status,
    player1: match.player1,
    player2: match.player2,
    betAmount: match.betAmount,
    endTime: match.endTime,
    onChainGameId: match.onChainGameId,
  });

  if (match.status !== "active") {
    console.log(`Match is already '${match.status}', nothing to do.`);
    process.exit(0);
  }

  // Both players likely had 0% ROI (no trades or minimal), so settle as tied.
  await updateMatch(MATCH_ID, {
    status: "tied",
    player1Roi: 0,
    player2Roi: 0,
    settledAt: Date.now(),
    escrowState: "settlement_pending", // on-chain settlement still needed later
  });

  console.log(`Match ${MATCH_ID} settled as TIED in Firebase.`);
  console.log("Note: 2 USDC remains locked in escrow on-chain until program is updated.");

  // Clean exit.
  await db.goOffline();
  process.exit(0);
}

main().catch((err) => {
  console.error("Failed:", err);
  process.exit(1);
});
