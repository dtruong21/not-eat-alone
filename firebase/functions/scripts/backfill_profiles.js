#!/usr/bin/env node
/**
 * One-off backfill for the private/public profile split.
 *
 *   node scripts/backfill_profiles.js --database "(default)"            # dry run
 *   node scripts/backfill_profiles.js --database stage --apply
 *
 * For every `users/{uid}` doc: writes `profiles/{uid}` (name, photos, bio, rating
 * aggregate, derived age) and removes those public fields from `users/{uid}`, so the
 * tightened rules (which only allow private keys on `users`) accept later writes.
 * Idempotent. Needs Admin credentials (GOOGLE_APPLICATION_CREDENTIALS or gcloud ADC).
 * Run it BEFORE deploying the new rules (see docs/RELEASE.md).
 */
const { initializeApp, getApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { splitLegacyUser } = require('../lib/lib/profile_split');

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const value = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

async function main() {
  const database = value('--database', '(default)');
  const apply = flag('--apply');
  initializeApp({ projectId: value('--project', 'not-eat-alone') });
  const db = getFirestore(getApp(), database);
  const snap = await db.collection('users').get();
  const now = Date.now();
  let migrated = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const dob = data.dob instanceof Timestamp ? data.dob.toMillis() : null;
    const { profile, deleteFromUser } = splitLegacyUser(doc.id, data, dob, now);
    console.log(`${apply ? 'MIGRATE' : 'would migrate'} ${doc.id}: profile keys [${Object.keys(profile)}] remove [${deleteFromUser}]`);
    if (!apply) continue;
    const batch = db.batch();
    batch.set(db.collection('profiles').doc(doc.id), profile, { merge: true });
    if (deleteFromUser.length > 0) {
      batch.update(doc.ref, Object.fromEntries(deleteFromUser.map((f) => [f, FieldValue.delete()])));
    }
    await batch.commit();
    migrated += 1;
  }
  console.log(`${apply ? 'Migrated' : 'Dry run:'} ${apply ? migrated : snap.size} of ${snap.size} users in "${database}".`);
}

main().catch((e) => { console.error(e); process.exit(1); });
