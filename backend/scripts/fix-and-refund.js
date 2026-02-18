/**
 * Fixes the bad state set by refund-last-games.js and shows real game status.
 */
require('dotenv').config();
const admin = require('firebase-admin');
const sa = JSON.parse(require('fs').readFileSync(require('path').resolve(process.env.FIREBASE_SERVICE_ACCOUNT), 'utf-8'));
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa), databaseURL: process.env.FIREBASE_DATABASE_URL });
const db = admin.database();

async function run() {
  // Fix the 2 matches that were incorrectly updated
  // -OlilAnvtcjZQ5QRr3Pn was cancelled/awaiting_deposits (no funds deposited)
  await db.ref('solfight/matches/-OlilAnvtcjZQ5QRr3Pn').update({ status: 'cancelled', escrowState: 'awaiting_deposits', winner: null });
  // -OliEczAeN-CrBdnBBci was already refunded — put it back
  await db.ref('solfight/matches/-OliEczAeN-CrBdnBBci').update({ status: 'cancelled', escrowState: 'refunded', winner: null });

  console.log('Fixed incorrect state on 2 matches.');

  // Show full picture of all games that ever had on-chain funds
  const snap = await db.ref('solfight/matches').once('value');
  const matches = [];
  snap.forEach(c => {
    const m = c.val();
    if (!m.onChainGameId) return; // skip matches with no on-chain game (no funds)
    const ts = m.createdAt || m.startTime || m.depositDeadline || 0;
    matches.push({ id: c.key, ts, status: m.status, escrowState: m.escrowState, onChainGameId: m.onChainGameId, player1: (m.player1||'').slice(0,8), player2: (m.player2||'').slice(0,8), winner: m.winner ? m.winner.slice(0,8) : null });
  });
  matches.sort((a, b) => b.ts - a.ts);

  console.log('\n=== All on-chain games (newest first) ===');
  matches.forEach(m => {
    const ts = m.ts ? new Date(m.ts).toISOString() : 'unknown';
    const needsAction = !['refunded', 'payout_sent', 'partial_refund'].includes(m.escrowState || '');
    console.log(`${needsAction ? '⚠️ ' : '✓ '}[${ts.slice(0,16)}] gameId=${m.onChainGameId} status=${m.status} escrow=${m.escrowState||'n/a'} ${m.player1} vs ${m.player2}`);
  });
}

run().then(() => process.exit(0)).catch(err => { console.error(err); process.exit(1); });
