import "../src/services/firebase";
import { matchesRef } from "../src/services/firebase";

async function run() {
  // Grab the last 30 matches by push key (key order = insertion order)
  const snap = await matchesRef.limitToLast(30).once("value");
  const matches: Array<{ id: string; data: Record<string, unknown> }> = [];
  if (snap.exists()) {
    snap.forEach((child) => {
      matches.push({ id: child.key!, data: child.val() });
    });
  }
  matches.reverse(); // most recent first

  const today = new Date("2026-02-17");
  today.setHours(0, 0, 0, 0);

  console.log("Last 30 matches (most recent push key first):\n");
  for (const { id, data: m } of matches) {
    const ts = (m.startTime ?? m.depositDeadline ?? m.endTime) as number | undefined;
    const dateStr = ts ? new Date(ts).toISOString() : "no timestamp";
    const createdTs = parseInt(id.replace(/[^0-9]/g, '').slice(0, 13), 10) || 0;
    const createdStr = new Date(createdTs).toISOString().slice(0, 16);
    console.log(`Match: ${id}`);
    console.log(`  Created (est): ${createdStr}`);
    console.log(`  Status:        ${m.status}`);
    console.log(`  Players:       ${String(m.player1).slice(0,8)}… vs ${String(m.player2 ?? '?').slice(0,8)}…`);
    console.log(`  Bet:           ${m.betAmount ?? '?'} USDC`);
    console.log(`  Timestamp:     ${dateStr}`);
    console.log(`  onChainSettled: ${m.onChainSettled ?? false}`);
    console.log(`  onChainGameId:  ${m.onChainGameId ?? "—"}`);
    console.log(`  escrowState:    ${m.escrowState ?? "—"}`);
    console.log();
  }
  process.exit(0);
}
run().catch((e) => { console.error(e); process.exit(1); });
