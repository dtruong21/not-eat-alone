// Private `users/{uid}` vs public `profiles/{uid}` (PRD: Private vs public profile).
const test = require('node:test');
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, setDoc, updateDoc, collection, query, where, Timestamp,
} = require('firebase/firestore');

const dob = (s) => Timestamp.fromDate(new Date(s));
let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-convyve-rules',
    firestore: {
      // host/port come from FIRESTORE_EMULATOR_HOST (set by `emulators:exec`).
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});
test.after(async () => env.cleanup());

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), { uid: 'alice', dob: dob('1990-01-01'), ageVerified: true, gender: 'woman' });
    await setDoc(doc(db, 'users/bob'), { uid: 'bob', dob: dob('1991-02-02'), ageVerified: true, gender: 'man' });
    await setDoc(doc(db, 'users/dan'), { uid: 'dan', dob: dob('1999-05-05'), ageVerified: false });
    await setDoc(doc(db, 'profiles/alice'), { uid: 'alice', displayName: 'Alice', photoUrls: [], age: 36, ratingSum: 9, ratingCount: 2, ratingAvg: 4.5 });
    await setDoc(doc(db, 'profiles/bob'), { uid: 'bob', displayName: 'Bob', photoUrls: [], age: 35 });
    await setDoc(doc(db, 'meals/mw'), {
      id: 'mw', hostId: 'alice', womenOnly: true, status: 'open',
      dateTime: Timestamp.fromMillis(Date.now() + 3 * 86400e3),
    });
  });
}
const as = (uid) => env.authenticatedContext(uid).firestore();

test('private users doc: owner reads; others cannot get or list', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(as('alice'), 'users/alice')));
  await assertFails(getDoc(doc(as('bob'), 'users/alice')));
  await assertFails(getDocs(collection(as('bob'), 'users')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/alice')));
});

test('private users doc: create shape, no public fields', async () => {
  await seed();
  const db = as('carol');
  await assertSucceeds(setDoc(doc(db, 'users/carol'), { uid: 'carol', dob: dob('2000-01-01'), ageVerified: true }));
  await seed();
  await assertFails(setDoc(doc(as('carol'), 'users/carol'), { uid: 'carol', dob: dob('2000-01-01'), ageVerified: true, displayName: 'C' }));
  await assertFails(setDoc(doc(as('carol'), 'users/zed'), { uid: 'zed', dob: dob('2000-01-01'), ageVerified: true }));
});

test('private users doc: dob/ageVerified are locked once verified', async () => {
  await seed();
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { dob: dob('1980-01-01') }));
  await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { ageVerified: false }));
  await assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), { gender: 'woman' }));
  // not verified yet (age-gate retry) -> allowed
  await assertSucceeds(updateDoc(doc(as('dan'), 'users/dan'), { dob: dob('1990-05-05'), ageVerified: true }));
  // another user can never write it
  await assertFails(updateDoc(doc(as('bob'), 'users/alice'), { gender: 'man' }));
});

test('public profile: any signed-in user can get one, nobody can list', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(as('bob'), 'profiles/alice')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'profiles/alice')));
  await assertFails(getDocs(collection(as('bob'), 'profiles')));
  await assertFails(getDocs(query(collection(as('bob'), 'profiles'), where('displayName', '==', 'Alice'))));
});

test('public profile: only the owner writes; shape and rating fields guarded', async () => {
  await seed();
  const alice = as('alice');
  await assertSucceeds(updateDoc(doc(alice, 'profiles/alice'), { displayName: 'Ali', bio: 'hi', age: 37 }));
  await assertFails(updateDoc(doc(as('bob'), 'profiles/alice'), { displayName: 'x' }));
  // never dob/gender in the public doc
  await assertFails(updateDoc(doc(alice, 'profiles/alice'), { dob: dob('1990-01-01') }));
  await assertFails(updateDoc(doc(alice, 'profiles/alice'), { gender: 'woman' }));
  // rating fields are server-only
  await assertFails(updateDoc(doc(alice, 'profiles/alice'), { ratingAvg: 5 }));
  await assertFails(updateDoc(doc(alice, 'profiles/alice'), { ratingCount: 99 }));
  // age sanity
  await assertFails(updateDoc(doc(alice, 'profiles/alice'), { age: 17 }));
  await assertFails(updateDoc(doc(alice, 'profiles/alice'), { age: 36.5 }));
  await assertFails(updateDoc(doc(alice, 'profiles/alice'), { age: 121 }));
});

test('public profile: create must be own uid with zero ratings', async () => {
  await seed();
  const carol = as('carol');
  await assertSucceeds(setDoc(doc(carol, 'profiles/carol'), { uid: 'carol', age: 25 }));
  await seed();
  await assertFails(setDoc(doc(as('carol'), 'profiles/carol'), { uid: 'carol', ratingAvg: 5 }));
  await assertFails(setDoc(doc(as('carol'), 'profiles/dave'), { uid: 'dave' }));
  await assertFails(setDoc(doc(as('carol'), 'profiles/carol'), { uid: 'carol', dob: dob('2000-01-01') }));
});

test('women-only join rule still reads the private gender', async () => {
  await seed();
  const req = (guest) => ({
    id: `mw_${guest}`, mealId: 'mw', guestId: guest, hostId: 'alice', status: 'pending',
    createdAt: Timestamp.now(),
  });
  // bob is a man -> denied; a woman guest -> allowed
  await assertFails(setDoc(doc(as('bob'), 'requests/mw_bob'), req('bob')));
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/cara'), { uid: 'cara', dob: dob('1995-01-01'), ageVerified: true, gender: 'woman' });
  });
  await assertSucceeds(setDoc(doc(as('cara'), 'requests/mw_cara'), req('cara')));
});
