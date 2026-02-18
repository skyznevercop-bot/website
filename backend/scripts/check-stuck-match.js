/**
 * Find and show the most recent active/stuck match.
 */
require('dotenv').config();
const admin = require('firebase-admin');
const sa = JSON.parse(require('fs').readFileSync(require('path').resolve(process.env.FIREBASE_SERVICE_ACCOUNT), 'utf-8'));
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa), databaseURL: process.env.FIREBASE_DATABASE_URL });
const db = admin.database();

async function run() {
  const snap = await db.ref('solfight/matches').once('value');
  const matches = [];
  snap.forEach(c => {
    const m = c.val();
    const ts = m.createdAt || m.startTime || m.depositDeadline || 0;
    matches.push({ id: c.key, ts, ...m });
  });
  matches.sort((a, b) => b.ts - a.ts);

  // Show all recent matches that might be stuck
  const recent = matches.slice(0, 8);
  recent.forEach(m => {
    const ts = m.ts ? new Date(m.ts).toISOString().slice(0,16) : 'unknown';
    console.log(`[${ts}] ${m.id} | status=${m.status} escrow=${m.escrowState||'n/a'} gameId=${m.onChainGameId||'none'} settled=${m.onChainSettled||false} winner=${m.winner ? m.winner.slice(0,8) : 'none'} p1Roi=${m.player1Roi != null ? (m.player1Roi*100).toFixed(2)+'%' : 'n/a'} p2Roi=${m.player2Roi != null ? (m.player2Roi*100).toFixed(2)+'%' : 'n/a'}`);
  });
}

run().then(() => process.exit(0)).catch(err => { console.error(err); process.exit(1); });
