/**
 * Lists ALL matches sorted by newest first, then refunds
 * the last N games that have on-chain funds (onChainGameId set).
 * Usage: node scripts/refund-last-games.js [count=2]
 */
require('dotenv').config();
const admin = require('firebase-admin');
const sa = JSON.parse(require('fs').readFileSync(require('path').resolve(process.env.FIREBASE_SERVICE_ACCOUNT), 'utf-8'));
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa), databaseURL: process.env.FIREBASE_DATABASE_URL });
const db = admin.database();

db.ref('solfight/matches').once('value').then(async snap => {
  if (!snap.exists()) { console.log('No matches.'); process.exit(0); }

  const matches = [];
  snap.forEach(c => {
    const m = c.val();
    // Use the newest available timestamp
    const ts = m.createdAt || m.startTime || m.depositDeadline || 0;
    matches.push({ id: c.key, ts, status: m.status, escrowState: m.escrowState, onChainGameId: m.onChainGameId, player1: m.player1, player2: m.player2, winner: m.winner });
  });
  matches.sort((a, b) => b.ts - a.ts);

  console.log('\n=== Last 5 matches (newest first) ===');
  matches.slice(0, 5).forEach(m => {
    const ts = m.ts ? new Date(m.ts).toISOString() : 'unknown';
    console.log(`[${ts}] ${m.id} | status=${m.status} escrow=${m.escrowState || 'n/a'} gameId=${m.onChainGameId || 'none'}`);
  });

  // Find the last N that have an onChainGameId (real funds involved)
  const count = parseInt(process.argv[2] || '2', 10);
  const toRefund = matches.filter(m => m.onChainGameId != null).slice(0, count);

  if (toRefund.length === 0) {
    console.log('\nNo on-chain games found to refund.');
    process.exit(0);
  }

  console.log(`\n=== Refunding ${toRefund.length} game(s) ===`);

  // Dynamically load the compiled solana utils
  // We need to call refundEscrowOnChain — use ts-node or pre-compiled JS
  // Since we can't import TS directly, we'll do it via the REST API instead
  // by marking the match for the retry loop to pick up with escrowState=refund_failed
  // Actually: just call the on-chain refund via the existing solana module

  for (const m of toRefund) {
    console.log(`\nMatch ${m.id}: status=${m.status}, escrow=${m.escrowState}, gameId=${m.onChainGameId}`);
    // Mark as tied + refund_failed so the on-chain retry loop will refund automatically
    await db.ref('solfight/matches/' + m.id).update({
      status: 'tied',
      escrowState: 'refund_failed',
      winner: null,
      settledAt: Date.now(),
      onChainSettled: false,
    });
    console.log(`  → Marked for auto-refund by retry loop (tied + refund_failed)`);
  }

  console.log('\nDone. The backend retry loop will process refunds within 30 seconds.');
  process.exit(0);
}).catch(err => { console.error(err); process.exit(1); });
