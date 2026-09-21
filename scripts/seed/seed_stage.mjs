// Runner: writes the pure seed docs from `seed_data.mjs` into the Firestore
// **stage** database via firebase-admin. Never touches `(default)` (prod).
//
// Usage (from scripts/seed/):
//   npm install
//   npm run seed     # write seed users + meals (idempotent, merge:true)
//   npm run wipe      # delete all docs whose id starts with "seed_"
//
// Requires scripts/seed/service-account.json (see README.md).

import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

import { buildSeedUsers, buildSeedMeals, restaurants } from './seed_data.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'service-account.json');
const STAGE_DATABASE_ID = 'stage';

function assertServiceAccountExists() {
  if (!existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error(
      [
        '',
        'Missing scripts/seed/service-account.json.',
        '',
        'Download it from the Firebase console:',
        '  Project settings -> Service accounts -> Generate new private key',
        `Save it to: ${SERVICE_ACCOUNT_PATH}`,
        '',
      ].join('\n'),
    );
    process.exit(1);
  }
}

function assertTargetIsStage(databaseId) {
  // Guard against accidentally seeding the default/prod database. This is
  // the single source of truth for which database we connect to below, so
  // asserting on it here (before it's ever passed to getFirestore) is what
  // stands between this script and writing into prod.
  if (databaseId !== STAGE_DATABASE_ID || databaseId === '(default)') {
    console.error(
      `Refusing to run: target database id is "${databaseId}", expected "${STAGE_DATABASE_ID}".`,
    );
    process.exit(1);
  }
}

function initFirestore() {
  assertTargetIsStage(STAGE_DATABASE_ID);

  const app = initializeApp({ credential: cert(SERVICE_ACCOUNT_PATH) });
  const db = getFirestore(app, STAGE_DATABASE_ID);

  // Defense in depth: if the admin SDK exposes the resolved database id at
  // runtime, re-check it too, in case a future edit passes a different
  // value into getFirestore than the constant above.
  if (typeof db.databaseId === 'string') {
    assertTargetIsStage(db.databaseId);
  }

  return db;
}

function toUserDoc(user) {
  return {
    ...user,
    dob: Timestamp.fromDate(user.dob),
    createdAt: Timestamp.fromDate(user.createdAt),
  };
}

function toMealDoc(meal) {
  return {
    ...meal,
    dateTime: Timestamp.fromDate(meal.dateTime),
    createdAt: Timestamp.fromDate(meal.createdAt),
  };
}

async function seed(db) {
  const users = buildSeedUsers();
  const meals = buildSeedMeals(restaurants, users);

  const batch = db.batch();
  for (const user of users) {
    const { id, ...doc } = toUserDoc(user);
    batch.set(db.collection('users').doc(id), doc, { merge: true });
  }
  for (const meal of meals) {
    const { id, ...doc } = toMealDoc(meal);
    batch.set(db.collection('meals').doc(id), doc, { merge: true });
  }
  await batch.commit();

  console.log('Seed complete (database: stage):');
  console.log(`  users written: ${users.length}`);
  console.log(`  meals written: ${meals.length}`);
}

async function wipeCollection(db, collectionName) {
  // '~' (0x7E) sorts after every character used in our seed ids, so bounding
  // the range with `< 'seed_~'` selects exactly the docs whose id starts
  // with "seed_" and nothing else — same trick the app's watchDiscoverable
  // query uses for geohash prefix bounds (see meal_repository_impl.dart).
  // ASCII '~' is used instead of a Unicode private-use sentinel so the bound
  // stays visible/unambiguous in diffs and terminals.
  const snapshot = await db
    .collection(collectionName)
    .where('__name__', '>=', 'seed_')
    .where('__name__', '<', 'seed_~')
    .get();

  if (snapshot.empty) {
    return 0;
  }

  const batch = db.batch();
  let count = 0;
  for (const doc of snapshot.docs) {
    if (doc.id.startsWith('seed_')) {
      batch.delete(doc.ref);
      count++;
    }
  }
  if (count > 0) {
    await batch.commit();
  }
  return count;
}

async function wipe(db) {
  const usersDeleted = await wipeCollection(db, 'users');
  const mealsDeleted = await wipeCollection(db, 'meals');

  console.log('Wipe complete (database: stage):');
  console.log(`  users deleted: ${usersDeleted}`);
  console.log(`  meals deleted: ${mealsDeleted}`);
}

async function main() {
  assertServiceAccountExists();
  const db = initFirestore();

  const wipeRequested = process.argv.includes('--wipe');
  if (wipeRequested) {
    await wipe(db);
  } else {
    await seed(db);
  }
}

main().catch((error) => {
  console.error('Seed script failed:', error);
  process.exit(1);
});
