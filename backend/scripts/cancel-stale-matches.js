require('dotenv').config();
const admin = require('firebase-admin');
const sa = JSON.parse(require('fs').readFileSync(require('path').resolve(process.env.FIREBASE_SERVICE_ACCOUNT), 'utf-8'));
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa), databaseURL: process.env.FIREBASE_DATABASE_URL });
const db = admin.database();
const now = Date.now();

db.ref('solfight/matches').orderByChild('status').equalTo('awaiting_deposits').once('value').then(snap => {
  if (!snap.exists()) { console.log('No awaiting_deposits matches.'); process.exit(0); }
  const stale = [];
  snap.forEach(child => {
    const m = child.val();
    if (!m.depositDeadline || now > m.depositDeadline) {
      stale.push({ id: child.key, deadline: m.depositDeadline });
    }
  });
  if (stale.length === 0) { console.log('No stale matches found.'); process.exit(0); }
  console.log('Stale matches to cancel:', JSON.stringify(stale, null, 2));
  return Promise.all(stale.map(({ id }) =>
    db.ref('solfight/matches/' + id).update({ status: 'cancelled' })
  ));
}).then(() => { console.log('Done — stale matches cancelled.'); process.exit(0); })
  .catch(err => { console.error(err); process.exit(1); });
