import "../src/services/firebase";
import { fetchGameAccount, getGamePdaAndEscrow, GameStatus, getConnection } from "../src/utils/solana";
import { getMatch } from "../src/services/firebase";

const MATCH_ID = "-Olhrn_WiOifASbh6T43";
const GAME_ID = 19n;
const statusNames: Record<number, string> = {
  0: "Pending", 1: "Active", 2: "Settled", 3: "Cancelled", 4: "Tied", 5: "Forfeited"
};

async function run() {
  const match = await getMatch(MATCH_ID);
  console.log("Firebase match:", JSON.stringify(match, null, 2));

  const game = await fetchGameAccount(GAME_ID);
  if (!game) { console.log("\nOn-chain: NOT FOUND (closed)"); return; }

  console.log("\nOn-chain:");
  console.log(`  status:             ${statusNames[game.status]} (${game.status})`);
  console.log(`  playerOneDeposited: ${game.playerOneDeposited}`);
  console.log(`  playerTwoDeposited: ${game.playerTwoDeposited}`);

  const { escrowTokenAccount } = await getGamePdaAndEscrow(GAME_ID);
  try {
    const bal = await getConnection().getTokenAccountBalance(escrowTokenAccount);
    console.log(`  escrow balance:     ${bal.value.uiAmountString} USDC`);
  } catch { console.log(`  escrow balance:     (closed/empty)`); }

  process.exit(0);
}
run().catch((e) => { console.error(e); process.exit(1); });
