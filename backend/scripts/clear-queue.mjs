/**
 * One-off script: wipes the entire solfight/queues node in Firebase.
 * Run from the backend/ directory:
 *   node scripts/clear-queue.mjs
 */
import { createRequire } from 'module';
import { readFileSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Load .env
import('dotenv').then(async ({ default: dotenv }) => {
  dotenv.config({ path: path.resolve(__dirname, '../.env') });

  const admin = require('firebase-admin');

  if (!admin.apps.length) {
    const inlineJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
    const dbUrl = process.env.FIREBASE_DATABASE_URL || 'https://solfight-6e7d2-default-rtdb.firebaseio.com';

    if (inlineJson) {
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(inlineJson)),
        databaseURL: dbUrl,
      });
    } else if (serviceAccountPath) {
      const sa = JSON.parse(readFileSync(path.resolve(serviceAccountPath), 'utf-8'));
      admin.initializeApp({ credential: admin.credential.cert(sa), databaseURL: dbUrl });
    } else {
      admin.initializeApp({ databaseURL: dbUrl });
    }
  }

  const db = admin.database();
  const queuesRef = db.ref('solfight/queues');

  const snap = await queuesRef.once('value');
  if (!snap.exists()) {
    console.log('Queue is already empty.');
    process.exit(0);
  }

  console.log('Current queue contents:');
  console.log(JSON.stringify(snap.val(), null, 2));

  await queuesRef.remove();
  console.log('\n✓ All queues cleared.');
  process.exit(0);
}).catch(err => {
  console.error(err);
  process.exit(1);
});
