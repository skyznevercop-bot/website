import "../src/services/firebase";
import { fetchGameAccount, getGamePdaAndEscrow, getConnection, GameStatus } from "../src/utils/solana";

const statusNames: Record<number, string> = {
  0: "Pending", 1: "Active", 2: "Settled", 3: "Cancelled", 4: "Tied", 5: "Forfeited"
};

async function checkGame(id: bigint): Promise<void> {
  const g = await fetchGameAccount(id);
  if (!g) { console.log(`Game ${id}: NOT FOUND (closed)`); return; }
  const { escrowTokenAccount } = await getGamePdaAndEscrow(id);
  let bal = "unknown";
  try {
    const result = await getConnection().getTokenAccountBalance(escrowTokenAccount);
    bal = `${result.value.uiAmountString} USDC`;
  } catch { bal = "(closed/empty)"; }
  console.log(`Game ${id}: status=${statusNames[g.status]}  p1dep=${g.playerOneDeposited}  p2dep=${g.playerTwoDeposited}  escrow=${bal}`);
}

async function run() {
  await checkGame(20n);
  await checkGame(21n);
  process.exit(0);
}
run().catch(e => { console.error(e); process.exit(1); });
