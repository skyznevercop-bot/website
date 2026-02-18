import "../src/services/firebase";
import { matchesRef } from "../src/services/firebase";

async function run() {
  const snap = await matchesRef.orderByChild("startTime").limitToLast(15).once("value");
  const matches: Array<{ id: string; data: Record<string, unknown> }> = [];
  if (snap.exists()) {
    snap.forEach((child) => {
      matches.push({ id: child.key!, data: child.val() });
    });
  }
  matches.reverse();
  console.log("Last 15 matches (most recent first):\n");
  for (const { id, data: m } of matches) {
    const started = m.startTime ? new Date(m.startTime as number).toISOString() : "—";
    console.log(`Match: ${id}`);
    console.log(`  Status:        ${m.status}`);
    console.log(`  Players:       ${String(m.player1).slice(0,8)}… vs ${String(m.player2).slice(0,8)}…`);
    console.log(`  Bet:           ${m.betAmount} USDC`);
    console.log(`  Started:       ${started}`);
    console.log(`  onChainSettled: ${m.onChainSettled ?? false}`);
    console.log(`  onChainGameId:  ${m.onChainGameId ?? "—"}`);
    console.log();
  }
  process.exit(0);
}
run().catch((e) => { console.error(e); process.exit(1); });
