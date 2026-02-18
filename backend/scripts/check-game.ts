import "../src/services/firebase";
import { fetchGameAccount, getGamePdaAndEscrow, GameStatus, getConnection } from "../src/utils/solana";
import { getMatch } from "../src/services/firebase";

const MATCH_ID = "-OlhfETzGDRFiEjW6kWh";
const GAME_ID = 18n;

async function run() {
  const match = await getMatch(MATCH_ID);
  console.log("Firebase match:", JSON.stringify(match, null, 2));

  const game = await fetchGameAccount(GAME_ID);
  if (!game) {
    console.log("\nOn-chain game account: NOT FOUND (may be closed)");
    return;
  }

  const statusNames: Record<number, string> = {
    0: "Pending", 1: "Active", 2: "Settled", 3: "Cancelled", 4: "Tied", 5: "Forfeited"
  };

  console.log("\nOn-chain game account:");
  console.log(`  status:             ${statusNames[game.status]} (${game.status})`);
  console.log(`  player1:            ${game.playerOne.toBase58()}`);
  console.log(`  player2:            ${game.playerTwo.toBase58()}`);
  console.log(`  betAmount:          ${Number(game.betAmount) / 1_000_000} USDC`);
  console.log(`  playerOneDeposited: ${game.playerOneDeposited}`);
  console.log(`  playerTwoDeposited: ${game.playerTwoDeposited}`);
  console.log(`  winner:             ${game.winner?.toBase58() ?? "none"}`);
  console.log(`  escrow:             ${(await getGamePdaAndEscrow(GAME_ID)).escrowTokenAccount.toBase58()}`);

  // Check escrow balance
  const { escrowTokenAccount } = await getGamePdaAndEscrow(GAME_ID);
  const conn = getConnection();
  try {
    const acct = await conn.getTokenAccountBalance(escrowTokenAccount);
    console.log(`  escrow balance:     ${acct.value.uiAmountString} USDC`);
  } catch {
    console.log(`  escrow balance:     (account closed or empty)`);
  }

  process.exit(0);
}
run().catch((e) => { console.error(e); process.exit(1); });
