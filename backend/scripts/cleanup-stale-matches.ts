/**
 * One-time cleanup script: cancel all stuck "active" / "awaiting_deposits" matches.
 *
 * Usage:
 *   npx tsx backend/scripts/cleanup-stale-matches.ts
 *
 * Safe to run multiple times — already-cancelled matches are skipped.
 */

import "../src/services/firebase"; // initializes Firebase Admin
import { matchesRef } from "../src/services/firebase";

const STALE_STATUSES = ["active", "awaiting_deposits"] as const;

function ageString(createdAtMs: number): string {
  const ageMs = Date.now() - createdAtMs;
  const mins = Math.floor(ageMs / 60_000);
  const hours = Math.floor(mins / 60);
  const days = Math.floor(hours / 24);
  if (days > 0) return `${days}d ${hours % 24}h old`;
  if (hours > 0) return `${hours}h ${mins % 60}m old`;
  return `${mins}m old`;
}

async function run() {
  console.log("[cleanup] Querying stale matches from Firebase…\n");

  let cancelled = 0;
  let skipped = 0;

  for (const status of STALE_STATUSES) {
    const snap = await matchesRef
      .orderByChild("status")
      .equalTo(status)
      .once("value");

    if (!snap.exists()) {
      console.log(`[cleanup] No matches with status="${status}"`);
      continue;
    }

    const updates: Array<Promise<void>> = [];

    snap.forEach((child) => {
      const id = child.key!;
      const m = child.val();

      const age = ageString(m.startTime ?? m.depositDeadline ?? Date.now());
      console.log(
        `[cleanup] Cancelling ${id}  status=${m.status}  ` +
          `player1=${m.player1?.slice(0, 8)}…  player2=${m.player2?.slice(0, 8)}…  ${age}`
      );

      updates.push(
        matchesRef.child(id).update({
          status: "cancelled",
          escrowState: "refunded",
        })
      );

      cancelled++;
    });

    await Promise.all(updates);
  }

  console.log(
    `\n[cleanup] Done — cancelled ${cancelled} stale match(es), skipped ${skipped}.`
  );
  process.exit(0);
}

run().catch((err) => {
  console.error("[cleanup] Fatal error:", err);
  process.exit(1);
});
