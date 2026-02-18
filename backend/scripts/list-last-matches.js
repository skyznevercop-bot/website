require('dotenv').config();
const admin = require('firebase-admin');
const sa = JSON.parse(require('fs').readFileSync(require('path').resolve(process.env.FIREBASE_SERVICE_ACCOUNT), 'utf-8'));
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa), databaseURL: process.env.FIREBASE_DATABASE_URL });
const db = admin.database();

db.ref('solfight/matches').once('value').then(snap => {
  if (!snap.exists()) { console.log('No matches.'); process.exit(0); }
  const matches = [];
  snap.forEach(c => {
    const m = c.val();
    matches.push({ id: c.key, createdAt: m.createdAt || m.startTime || 0, status: m.status, escrowState: m.escrowState, onChainGameId: m.onChainGameId, player1: (m.player1 || '').slice(0,8), player2: (m.player2 || '').slice(0,8), winner: m.winner ? m.winner.slice(0,8) : null });
  });
  matches.sort((a, b) => b.createdAt - a.createdAt);
  matches.slice(0, 5).forEach(m => console.log(JSON.stringify(m, null, 2)));
  process.exit(0);
}).catch(err => { console.error(err); process.exit(1); });
