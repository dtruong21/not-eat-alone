// Defence-in-depth rules: reports, message timestamps, rating keys.
const test = require('node:test');
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc, addDoc, collection, serverTimestamp, Timestamp } = require('firebase/firestore');

let env;
test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-convyve-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});
test.after(async () => env.cleanup());

const as = (uid) => env.authenticatedContext(uid).firestore();

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'meals/mm'), {
      id: 'mm', hostId: 'alice', guestId: 'bob', status: 'matched',
      dateTime: Timestamp.fromMillis(Date.now() - 3600e3),
    });
    await setDoc(doc(db, 'matches/mm'), {
      id: 'mm', mealId: 'mm', hostId: 'alice', guestId: 'bob', participants: ['alice', 'bob'],
    });
  });
}

test('reports: whitelisted keys and size caps', async () => {
  await seed();
  const base = { reporterId: 'bob', targetType: 'user', targetId: 'alice', reason: 'spam', status: 'open', createdAt: serverTimestamp() };
  await assertSucceeds(addDoc(collection(as('bob'), 'reports'), base));
  await assertSucceeds(addDoc(collection(as('bob'), 'reports'), { ...base, reason: null }));
  await assertFails(addDoc(collection(as('bob'), 'reports'), { ...base, note: 'extra key' }));
  await assertFails(addDoc(collection(as('bob'), 'reports'), { ...base, reason: 'z'.repeat(501) }));
  await assertFails(addDoc(collection(as('bob'), 'reports'), { ...base, targetId: 'x'.repeat(129) }));
  await assertFails(addDoc(collection(as('bob'), 'reports'), { ...base, reporterId: 'alice' }));
});

test('messages: server createdAt only, no extra keys', async () => {
  await seed();
  const col = (uid) => collection(as(uid), 'matches/mm/messages');
  const msg = { matchId: 'mm', senderId: 'bob', text: 'hi', createdAt: serverTimestamp() };
  await assertSucceeds(addDoc(col('bob'), msg));
  await assertFails(addDoc(col('bob'), { ...msg, createdAt: Timestamp.fromMillis(0) }));
  await assertFails(addDoc(col('bob'), { ...msg, createdAt: Timestamp.fromMillis(Date.now() + 86400e3 * 365) }));
  await assertFails(addDoc(col('bob'), { ...msg, extra: 1 }));
  await assertFails(addDoc(col('bob'), { ...msg, senderId: 'alice' }));
});

test('ratings: exact keys (no client-set aggregated) and server createdAt', async () => {
  await seed();
  const rating = {
    id: 'mm_bob', matchId: 'mm', raterUid: 'bob', targetUid: 'alice',
    stars: 5, showedUp: true, createdAt: serverTimestamp(),
  };
  await assertFails(setDoc(doc(as('bob'), 'ratings/mm_bob'), { ...rating, aggregated: true }));
  await assertFails(setDoc(doc(as('bob'), 'ratings/mm_bob'), { ...rating, createdAt: Timestamp.fromMillis(0) }));
  await assertSucceeds(setDoc(doc(as('bob'), 'ratings/mm_bob'), { ...rating, comment: 'great' }));
});
