/**
 * Quick script to check all user balances in Firebase.
 * Shows: total owed to users, number of users with balances, and frozen amounts.
 *
 * Usage: npx ts-node scripts/check-balances.ts
 */
import dotenv from "dotenv";
dotenv.config();

import admin from "firebase-admin";
import fs from "fs";

// ── Init Firebase ────────────────────────────────────────────────
const saJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
const saPath = process.env.FIREBASE_SERVICE_ACCOUNT || "./firebase-service-account.json";
const dbUrl =
  process.env.FIREBASE_DATABASE_URL ||
  "https://solfight-6e7d2-default-rtdb.firebaseio.com";

if (saJson) {
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(saJson)),
    databaseURL: dbUrl,
  });
} else if (fs.existsSync(saPath)) {
  admin.initializeApp({
    credential: admin.credential.cert(saPath),
    databaseURL: dbUrl,
  });
} else {
  admin.initializeApp({ databaseURL: dbUrl });
}

const usersRef = admin.database().ref("solfight/users");

async function main() {
  const snap = await usersRef.once("value");

  if (!snap.exists()) {
    console.log("No users found in database.");
    process.exit(0);
  }

  let totalBalance = 0;
  let totalFrozen = 0;
  let totalDeposited = 0;
  let totalWithdrawn = 0;
  let usersWithBalance = 0;
  let usersWithFrozen = 0;
  let totalUsers = 0;

  const topBalances: { address: string; balance: number; frozen: number }[] = [];

  snap.forEach((child) => {
    totalUsers++;
    const user = child.val();
    const bal = user.balance || 0;
    const frozen = user.frozenBalance || 0;
    const deposited = user.totalDeposited || 0;
    const withdrawn = user.totalWithdrawn || 0;

    totalBalance += bal;
    totalFrozen += frozen;
    totalDeposited += deposited;
    totalWithdrawn += withdrawn;

    if (bal > 0) usersWithBalance++;
    if (frozen > 0) usersWithFrozen++;

    if (bal > 0 || frozen > 0) {
      topBalances.push({ address: child.key!, balance: bal, frozen });
    }
  });

  // Sort by total (balance + frozen) descending.
  topBalances.sort((a, b) => b.balance + b.frozen - (a.balance + a.frozen));

  console.log("═══════════════════════════════════════════════════");
  console.log("  SOLFIGHT — User Balance Summary");
  console.log("═══════════════════════════════════════════════════");
  console.log(`  Total users:              ${totalUsers}`);
  console.log(`  Users with balance > 0:   ${usersWithBalance}`);
  console.log(`  Users with frozen > 0:    ${usersWithFrozen}`);
  console.log("───────────────────────────────────────────────────");
  console.log(`  Total balance (owed):     $${totalBalance.toFixed(2)}`);
  console.log(`  Total frozen:             $${totalFrozen.toFixed(2)}`);
  console.log(`  Total liability:          $${(totalBalance + totalFrozen).toFixed(2)}`);
  console.log("───────────────────────────────────────────────────");
  console.log(`  Total deposited (all-time): $${totalDeposited.toFixed(2)}`);
  console.log(`  Total withdrawn (all-time): $${totalWithdrawn.toFixed(2)}`);
  console.log("═══════════════════════════════════════════════════");

  if (topBalances.length > 0) {
    console.log("\n  Users with balances:");
    for (const u of topBalances.slice(0, 20)) {
      const addr = u.address.length > 12
        ? `${u.address.slice(0, 6)}…${u.address.slice(-4)}`
        : u.address;
      console.log(
        `    ${addr}  balance=$${u.balance.toFixed(2)}  frozen=$${u.frozen.toFixed(2)}`
      );
    }
    if (topBalances.length > 20) {
      console.log(`    ... and ${topBalances.length - 20} more`);
    }
  }

  console.log(
    "\n  → The vault needs at least $" +
      (totalBalance + totalFrozen).toFixed(2) +
      " USDC to cover all user balances.\n"
  );

  process.exit(0);
}

main().catch((err) => {
  console.error("Error:", err);
  process.exit(1);
});
