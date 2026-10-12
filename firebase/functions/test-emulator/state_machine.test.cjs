// QA sweep 2026-10-12: the meal state machine across cancelMatchedMeal, deleteAccount's
// releaseMatchedMeals, mealReminder and postMealReminder, run against the Firestore emulator
// with the COMPILED functions (Admin SDK, rules bypassed). Not part of `npm test` (jest) or CI:
//
//   cd firebase/functions && npm run build && cd ../.. &&
//   firebase emulators:exec --only firestore --project demo-convyve-fn \
//     "node --test --test-concurrency=1 firebase/functions/test-emulator/*.test.cjs"
//
// No device tokens exist in these fixtures, so `sendToUser` returns before touching FCM.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');

process.env.GCLOUD_PROJECT = 'demo-convyve-fn';
const lib = (p) => require(path.join(__dirname, '..', 'lib', p));
const { initializeApp, getApp } = require(path.join(__dirname, '..', 'node_modules', 'firebase-admin', 'lib', 'app'));
const { getFirestore, Timestamp } = require(path.join(__dirname, '..', 'node_modules', 'firebase-admin', 'lib', 'firestore'));

initializeApp({ projectId: 'demo-convyve-fn' });
const db = getFirestore(getApp(), '(default)');
const HOUR = 3_600_000;
const at = (ms) => Timestamp.fromMillis(Date.now() + ms);

async function wipe() {
  for (const c of ['meals', 'requests', 'matches', 'users', 'profiles', 'ratings']) {
    const s = await db.collection(c).get();
    for (const d of s.docs) {
      for (const sub of await d.ref.listCollections()) {
        for (const x of (await sub.get()).docs) await x.ref.delete();
      }
      await d.ref.delete();
    }
  }
}

async function matchedMeal(id, offsetMs, extra = {}) {
  await db.doc(`meals/${id}`).set({
    id, hostId: 'H', guestId: 'G', status: 'matched', dateTime: at(offsetMs),
    restaurant: { name: 'Chez X' }, womenOnly: false, seats: 1, ...extra,
  });
  await db.doc(`requests/${id}_G`).set({ id: `${id}_G`, mealId: id, guestId: 'G', hostId: 'H', status: 'approved' });
  await db.doc(`matches/${id}`).set({ id, mealId: id, hostId: 'H', guestId: 'G', participants: ['H', 'G'] });
  await db.doc(`matches/${id}/messages/m1`).set({ senderId: 'G', text: 'hi' });
  await db.doc(`matches/${id}/reads/H`).set({ uid: 'H' });
}

const runReminder = async () => {
  await lib('scheduled/meal_reminder.js').makeMealReminder('(default)').run({});
};
const runPostMeal = async () => {
  await lib('scheduled/post_meal_reminder.js').makePostMealReminder('(default)').run({});
};
const { applyCancel } = lib('callable/cancel_matched_meal.js');
const { releaseMatchedMeals } = lib('callable/delete_account.js');

test('guest withdraws: meal reopens, flags cleared, request + chat gone, reminders start fresh', async () => {
  await wipe();
  await matchedMeal('m1', 23 * HOUR, { reminder24hSent: true, reminder2hSent: true, postMealNotified: true });
  const d = await applyCancel(db, '(default)', 'G', 'm1');
  assert.equal(d.ok, true);
  const meal = (await db.doc('meals/m1').get()).data();
  assert.equal(meal.status, 'open');
  assert.equal(meal.guestId, null);
  for (const f of ['reminder24hSent', 'reminder2hSent', 'postMealNotified']) assert.ok(!(f in meal), f);
  assert.equal((await db.doc('requests/m1_G').get()).exists, false);
  assert.equal((await db.doc('matches/m1').get()).exists, false);
  assert.equal((await db.collection('matches/m1/messages').get()).size, 0);
  // an open meal is never reminded
  await runReminder();
  assert.ok(!('reminder24hSent' in (await db.doc('meals/m1').get()).data()));
});

test('host cancels: meal cancelled, never reminded or completed afterwards', async () => {
  await wipe();
  await matchedMeal('m2', 23 * HOUR);
  assert.equal((await applyCancel(db, '(default)', 'H', 'm2')).ok, true);
  assert.equal((await db.doc('meals/m2').get()).data().status, 'cancelled');
  await runReminder();
  await runPostMeal();
  const meal = (await db.doc('meals/m2').get()).data();
  assert.equal(meal.status, 'cancelled');
  assert.ok(!('reminder24hSent' in meal));
});

test('double tap / both sides cancel at once: exactly one wins', async () => {
  await wipe();
  await matchedMeal('m3', 5 * HOUR);
  const [a, b] = await Promise.all([
    applyCancel(db, '(default)', 'H', 'm3'),
    applyCancel(db, '(default)', 'G', 'm3'),
  ]);
  assert.equal([a, b].filter((x) => x.ok).length, 1);
});

test('after the meal time: cancel is refused, postMealReminder completes it once', async () => {
  await wipe();
  await matchedMeal('m4', -HOUR / 2);
  const d = await applyCancel(db, '(default)', 'G', 'm4');
  assert.equal(d.ok, false);
  assert.equal(d.code, 'failed-precondition');
  await runPostMeal();
  const meal = (await db.doc('meals/m4').get()).data();
  assert.equal(meal.status, 'completed');
  assert.equal(meal.postMealNotified, true);
  assert.equal((await applyCancel(db, '(default)', 'G', 'm4')).ok, false);
});

test('mealReminder flags a meal exactly once; 24h and 2h are independent', async () => {
  await wipe();
  await matchedMeal('m5', 23 * HOUR);
  await runReminder();
  let meal = (await db.doc('meals/m5').get()).data();
  assert.equal(meal.reminder24hSent, true);
  assert.ok(!('reminder2hSent' in meal));
  await db.doc('meals/m5').update({ dateTime: at(90 * 60_000) });
  await runReminder();
  meal = (await db.doc('meals/m5').get()).data();
  assert.equal(meal.reminder2hSent, true);
});

test('deleteAccount (releaseMatchedMeals): a guest leaving reopens a future meal and cancels a past one', async () => {
  await wipe();
  await matchedMeal('f1', 30 * HOUR, { reminder24hSent: true });
  await matchedMeal('p1', -2 * HOUR);
  await releaseMatchedMeals(db, '(default)', 'G');
  const future = (await db.doc('meals/f1').get()).data();
  assert.equal(future.status, 'open');
  assert.equal(future.guestId, null);
  assert.ok(!('reminder24hSent' in future));
  const past = (await db.doc('meals/p1').get()).data();
  assert.equal(past.status, 'cancelled');
  assert.equal(past.guestId, null);
});

test('KNOWN GAP: a guest who is released by deleteAccount leaves the host chat (match) behind until the later cascade step', async () => {
  await wipe();
  await matchedMeal('f2', 30 * HOUR);
  await releaseMatchedMeals(db, '(default)', 'G');
  // releaseMatchedMeals alone reopens the meal but the match + chat still exist; deleteAccount removes
  // them a few statements later (no transaction). If the function dies between the two, the reopened
  // meal keeps a stale matches/{mealId} doc and rules forbid creating it again (see rules test
  // "a failed deleteMatchTree ... blocks every future approval" and
  // docs/bugs/2026-10-12-cancel-meal-can-leave-a-stale-match-that-blocks-rematching.md).
  assert.equal((await db.doc('matches/f2').get()).exists, true);
  assert.equal((await db.doc('meals/f2').get()).data().status, 'open');
});
