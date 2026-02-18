/**
 * Marks stuck games for refund by the backend retry loop.
 * The backend's retryFailedRefunds() (runs every 30s) will call
 * refundEscrowOnChain() for any tied/cancelled match with escrowState=refund_failed.
 */
require('dotenv').config();
const admin = require('firebase-admin');
const sa = JSON.parse(require('fs').readFileSync(require('path').resolve(process.env.FIREBASE_SERVICE_ACCOUNT), 'utf-8'));
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa), databaseURL: process.env.FIREBASE_DATABASE_URL });
const db = admin.database();

// Games to handle:
// gameId=25 — today, awaiting_deposits (no deposits made since users were stuck in queue)
// gameId=17 — Feb 16, already refund_failed but backend was sleeping
// gameId=1  — oldest, settlement_pending (old DRAW issue)
const MATCH_IDS = [
  '-OlilAnvtcjZQ5QRr3Pn', // gameId=25 (today)
  // gameId=17 — find it below
  '-OlXJxFVQ_v00aV-VSnA', // gameId=1  (tied, settlement_pending)
];

async function run() {
  const snap = await db.ref('solfight/matches').once('value');
  const updates = [];

  snap.forEach(c => {
    const m = c.val();
    const id = c.key;

    // gameId=17: already has refund_failed state, just ensure status is correct
    if (m.onChainGameId === 17) {
      updates.push({ id, gameId: 17, current: m.escrowState });
      return;
    }

    // gameId=25: was awaiting_deposits — mark for refund attempt
    // (if no USDC was deposited, on-chain call will fail gracefully)
    if (m.onChainGameId === 25) {
      updates.push({ id, gameId: 25, current: m.escrowState });
    }

    // gameId=1: old tied match stuck in settlement_pending
    if (m.onChainGameId === 1) {
      updates.push({ id, gameId: 1, current: m.escrowState });
    }
  });

  for (const { id, gameId, current } of updates) {
    // Mark as tied + refund_failed → retry loop calls refundEscrowOnChain
    await db.ref('solfight/matches/' + id).update({
      status: 'tied',
      escrowState: 'refund_failed',
      winner: null,
      settledAt: Date.now(),
    });
    console.log(`gameId=${gameId} (${id}): ${current} → tied/refund_failed`);
  }

  console.log('\nDone. Backend retry loop will attempt refunds within 30s.');
  console.log('(If a game had no deposits, the on-chain call will fail gracefully.)');
}

run().then(() => process.exit(0)).catch(err => { console.error(err); process.exit(1); });
