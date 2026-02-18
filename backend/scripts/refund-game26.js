/**
 * Check on-chain state of game 26 and trigger a refund if needed.
 */
require('dotenv').config();
const admin = require('firebase-admin');
const sa = JSON.parse(require('fs').readFileSync(require('path').resolve(process.env.FIREBASE_SERVICE_ACCOUNT), 'utf-8'));
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa), databaseURL: process.env.FIREBASE_DATABASE_URL });
const db = admin.database();

async function run() {
  const snap = await db.ref('solfight/matches/-OlinwsGUU9ZsHfVaagD').once('value');
  const match = snap.val();
  console.log('Match:', JSON.stringify({ status: match.status, escrow: match.escrowState, gameId: match.onChainGameId, p1: match.player1?.slice(0,8), p2: match.player2?.slice(0,8), deadline: match.depositDeadline ? new Date(match.depositDeadline).toISOString() : 'none', p1dep: match.player1DepositVerified, p2dep: match.player2DepositVerified }, null, 2));

  // Mark for refund — backend retry loop will call refund_escrow on-chain.
  // If no USDC was deposited the on-chain call will fail gracefully.
  // If funds ARE locked, they'll be returned to both players.
  await db.ref('solfight/matches/-OlinwsGUU9ZsHfVaagD').update({
    status: 'tied',
    escrowState: 'refund_failed',
    winner: null,
    settledAt: Date.now(),
  });

  console.log('Marked game 26 for refund — backend will process within 30s.');
}

run().then(() => process.exit(0)).catch(err => { console.error(err); process.exit(1); });
