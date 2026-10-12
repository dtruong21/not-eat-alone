// QA sweep 2026-10-12: replays the EXACT write/query shapes the app's repositories
// produce (lib/features/*/data/repositories/*_impl.dart) through the rules, plus the
// state-machine paths the Cloud Functions (Admin SDK, rules bypassed) leave behind
// (cancelMatchedMeal, deleteAccount, backfill). Complements hardening.rules.test.cjs
// (what must be denied) with "what the shipped app must still be allowed to do".
const test = require('node:test');
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, getDocs, setDoc, addDoc, updateDoc, deleteDoc, collection, query, where,
  orderBy, limit, writeBatch, runTransaction, serverTimestamp, Timestamp,
} = require('firebase/firestore');

let env;
test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-convyve-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});
test.after(async () => env.cleanup());

const as = (uid) => env.authenticatedContext(uid).firestore();
const admin = async (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
const inDays = (d) => Timestamp.fromMillis(Date.now() + d * 86400e3);
const dob = (s) => Timestamp.fromDate(new Date(s));
const restaurant = { placeId: 'p1', name: 'Chez X', address: '1 rue Y', lat: 48.85, lng: 2.35 };

// users: alice (woman, host), bob (man, guest), cara (woman, guest)
async function seed() {
  await env.clearFirestore();
  await admin(async (db) => {
    for (const [uid, gender] of [['alice', 'woman'], ['bob', 'man'], ['cara', 'woman']]) {
      await setDoc(doc(db, `users/${uid}`), { uid, dob: dob('1990-01-01'), ageVerified: true, gender });
      await setDoc(doc(db, `profiles/${uid}`), { uid, displayName: uid, photoUrls: ['u'], age: 36 });
    }
  });
}

// MealRepositoryImpl.createMeal (MealDto.toJson + the explicit restaurant/dateTime/createdAt fixes)
const mealDoc = (id, hostId, extra = {}) => ({
  id, hostId, restaurant, dateTime: inDays(2), geohash: 'u09tv', note: null,
  womenOnly: false, seats: 1, status: 'open', guestId: null, createdAt: serverTimestamp(), ...extra,
});
// RequestRepositoryImpl.createRequest
const requestDoc = (mealId, guestId, hostId) => ({
  id: `${mealId}_${guestId}`, mealId, guestId, hostId, status: 'pending', createdAt: serverTimestamp(),
});
// RequestRepositoryImpl.approve (transaction) + _denySiblings
async function approve(db, mealId, guestId, hostId) {
  await runTransaction(db, async (txn) => {
    const meal = await txn.get(doc(db, `meals/${mealId}`));
    if (!meal.exists() || meal.data().status !== 'open') throw new Error('MealNoLongerOpen');
    txn.update(doc(db, `meals/${mealId}`), { status: 'matched', guestId });
    txn.update(doc(db, `requests/${mealId}_${guestId}`), { status: 'approved' });
    txn.set(doc(db, `matches/${mealId}`), {
      id: mealId, mealId, hostId, guestId, participants: [hostId, guestId], createdAt: serverTimestamp(),
    });
  });
}

test('new user: age gate batch, profile setup batch, public age self-heal', async () => {
  await env.clearFirestore();
  const db = as('dan');
  // UserRepositoryImpl.upsertAgeVerified (merge sets in one batch)
  const b = writeBatch(db);
  b.set(doc(db, 'users/dan'), { uid: 'dan', dob: dob('1999-05-05'), ageVerified: true, createdAt: serverTimestamp() }, { merge: true });
  b.set(doc(db, 'profiles/dan'), { uid: 'dan', age: 27 }, { merge: true });
  await assertSucceeds(b.commit());
  // updateProfile: name/photos/bio -> profiles, gender -> users, one batch
  const b2 = writeBatch(db);
  b2.set(doc(db, 'profiles/dan'), { uid: 'dan', displayName: 'Dan', photoUrls: ['https://x/1.jpg'], bio: 'hi' }, { merge: true });
  b2.set(doc(db, 'users/dan'), { gender: 'man' }, { merge: true });
  await assertSucceeds(b2.commit());
  // watchOwn age self-heal
  await assertSucceeds(setDoc(doc(db, 'profiles/dan'), { uid: 'dan', age: 28 }, { merge: true }));
  // age-gate retry before verification is allowed; after verification a re-run is locked
  const b3 = writeBatch(db);
  b3.set(doc(db, 'users/dan'), { uid: 'dan', dob: dob('1980-05-05'), ageVerified: true, createdAt: serverTimestamp() }, { merge: true });
  await assertFails(b3.commit());
});

test('legacy users doc that still holds public fields: owner writes are denied until the backfill ran', async () => {
  await env.clearFirestore();
  await admin(async (db) => {
    await setDoc(doc(db, 'users/leo'), {
      uid: 'leo', dob: dob('1990-01-01'), ageVerified: true, createdAt: Timestamp.now(),
      displayName: 'Leo', photoUrls: ['u'], bio: 'b', ratingSum: 5, ratingCount: 1, ratingAvg: 5,
    });
  });
  const db = as('leo');
  // new app's updateProfile (gender lives in users) -> the whole batch is rejected
  const b = writeBatch(db);
  b.set(doc(db, 'profiles/leo'), { uid: 'leo', displayName: 'Leo' }, { merge: true });
  b.set(doc(db, 'users/leo'), { gender: 'man' }, { merge: true });
  await assertFails(b.commit());
  // what backfill_profiles.js --apply does (Admin SDK): move the public fields, delete them from users
  await admin(async (adb) => {
    await setDoc(doc(adb, 'profiles/leo'), {
      uid: 'leo', displayName: 'Leo', photoUrls: ['u'], bio: 'b', ratingSum: 5, ratingCount: 1, ratingAvg: 5, age: 36,
    }, { merge: true });
    await updateDoc(doc(adb, 'users/leo'), {
      displayName: require('firebase/firestore').deleteField(),
      photoUrls: require('firebase/firestore').deleteField(),
      bio: require('firebase/firestore').deleteField(),
      ratingSum: require('firebase/firestore').deleteField(),
      ratingCount: require('firebase/firestore').deleteField(),
      ratingAvg: require('firebase/firestore').deleteField(),
    });
  });
  const b2 = writeBatch(db);
  b2.set(doc(db, 'profiles/leo'), { uid: 'leo', displayName: 'Leo2' }, { merge: true });
  b2.set(doc(db, 'users/leo'), { gender: 'man' }, { merge: true });
  await assertSucceeds(b2.commit());
});

test('an OLD app build (pre-split) against the new rules: documented breakage', async () => {
  await seed();
  // old app wrote name/photos/bio into users/{uid}
  await assertFails(setDoc(doc(as('alice'), 'users/alice'), { displayName: 'A2' }, { merge: true }));
  // old app read another person's users/{uid} for their name
  await assertFails(getDoc(doc(as('bob'), 'users/alice')));
});

test('meal lifecycle with the exact shapes: create, request, approve, deny siblings, chat, read, rate', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(as('alice'), 'meals/m1'), mealDoc('m1', 'alice')));
  // the discovery query (status == open && dateTime > now, orderBy dateTime, limit 100)
  await assertSucceeds(getDocs(query(
    collection(as('bob'), 'meals'), where('status', '==', 'open'),
    where('dateTime', '>', Timestamp.now()), orderBy('dateTime'), limit(100))));

  await assertSucceeds(setDoc(doc(as('bob'), 'requests/m1_bob'), requestDoc('m1', 'bob', 'alice')));
  await assertSucceeds(setDoc(doc(as('cara'), 'requests/m1_cara'), requestDoc('m1', 'cara', 'alice')));
  // host inbox query
  await assertSucceeds(getDocs(query(
    collection(as('alice'), 'requests'), where('hostId', '==', 'alice'),
    where('status', '==', 'pending'), orderBy('createdAt', 'desc'))));

  await assertSucceeds(approve(as('alice'), 'm1', 'bob', 'alice'));
  // _denySiblings query + per-doc update
  const sib = await assertSucceeds(getDocs(query(
    collection(as('alice'), 'requests'), where('mealId', '==', 'm1'),
    where('status', '==', 'pending'), where('hostId', '==', 'alice'))));
  assert(sib.size === 1);
  await assertSucceeds(updateDoc(sib.docs[0].ref, { status: 'denied' }));
  // second approve of the same meal is impossible (the app throws MealNoLongerOpen client-side)
  await require('node:assert').rejects(approve(as('alice'), 'm1', 'cara', 'alice'));

  // chats list + chat
  await assertSucceeds(getDocs(query(
    collection(as('bob'), 'matches'), where('participants', 'array-contains', 'bob'),
    orderBy('createdAt', 'desc'))));
  await assertSucceeds(addDoc(collection(as('bob'), 'matches/m1/messages'), {
    matchId: 'm1', senderId: 'bob', text: 'hi', createdAt: serverTimestamp(),
  }));
  await assertSucceeds(getDocs(query(
    collection(as('alice'), 'matches/m1/messages'), orderBy('createdAt', 'desc'), limit(1))));
  await assertSucceeds(setDoc(doc(as('alice'), 'matches/m1/reads/alice'), {
    uid: 'alice', lastReadAt: serverTimestamp(),
  }, { merge: true }));

  // a stranger gets nothing
  await assertFails(getDocs(collection(as('cara'), 'matches/m1/messages')));
  await assertFails(getDoc(doc(as('cara'), 'matches/m1')));

  // rating: only after the meal started (admin moves it to the past), exact RatingDto keys
  await admin((db) => updateDoc(doc(db, 'meals/m1'), { dateTime: Timestamp.fromMillis(Date.now() - 60e3) }));
  const rating = {
    id: 'm1_bob', matchId: 'm1', raterUid: 'bob', targetUid: 'alice', stars: 4, showedUp: true,
    createdAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(as('bob'), 'ratings/m1_bob'), rating));
  // "already rated?" listener (doc get on own id) and the never-rated case
  await assertSucceeds(getDoc(doc(as('bob'), 'ratings/m1_bob')));
  await assertSucceeds(getDoc(doc(as('alice'), 'ratings/m1_alice')));
});

test('report, block, unblock and fcm token shapes', async () => {
  await seed();
  await assertSucceeds(addDoc(collection(as('bob'), 'reports'), {
    reporterId: 'bob', targetType: 'user', targetId: 'alice', reason: null, status: 'open', createdAt: serverTimestamp(),
  }));
  const blockDoc = {
    id: 'bob_alice', blockerUid: 'bob', blockedUid: 'alice', pair: ['bob', 'alice'], createdAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(as('bob'), 'blocks/bob_alice'), blockDoc));
  await assertSucceeds(getDocs(query(collection(as('bob'), 'blocks'), where('pair', 'array-contains', 'bob'))));
  await assertSucceeds(getDocs(query(collection(as('alice'), 'blocks'), where('pair', 'array-contains', 'alice'))));
  await assertFails(deleteDoc(doc(as('alice'), 'blocks/bob_alice')));
  await assertSucceeds(deleteDoc(doc(as('bob'), 'blocks/bob_alice')));
  // PushRepositoryImpl.registerToken / unregister
  await assertSucceeds(setDoc(doc(as('bob'), 'users/bob/fcmTokens/tok1'), {
    token: 'tok1', platform: 'ios', updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(deleteDoc(doc(as('bob'), 'users/bob/fcmTokens/tok1')));
  await assertFails(setDoc(doc(as('alice'), 'users/bob/fcmTokens/tok2'), { token: 'tok2' }));
});

test('state machine: guest withdraws (cancelMatchedMeal) -> meal reopens, same guest can re-request, host can re-approve', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(as('alice'), 'meals/m2'), mealDoc('m2', 'alice')));
  await assertSucceeds(setDoc(doc(as('bob'), 'requests/m2_bob'), requestDoc('m2', 'bob', 'alice')));
  await assertSucceeds(setDoc(doc(as('cara'), 'requests/m2_cara'), requestDoc('m2', 'cara', 'alice')));
  await assertSucceeds(approve(as('alice'), 'm2', 'bob', 'alice'));
  await assertSucceeds(updateDoc(doc(as('alice'), 'requests/m2_cara'), { status: 'denied' }));
  await assertSucceeds(addDoc(collection(as('bob'), 'matches/m2/messages'), {
    matchId: 'm2', senderId: 'bob', text: 'hi', createdAt: serverTimestamp(),
  }));

  // Admin: applyCancel as guest + deleteMatchTree
  await admin(async (db) => {
    await updateDoc(doc(db, 'meals/m2'), { status: 'open', guestId: null });
    await deleteDoc(doc(db, 'requests/m2_bob'));
    for (const d of (await getDocs(collection(db, 'matches/m2/messages'))).docs) await deleteDoc(d.ref);
    await deleteDoc(doc(db, 'matches/m2'));
  });
  // The other participant's open chat now has nothing to authorise reads against.
  await assertFails(getDocs(query(collection(as('alice'), 'matches/m2/messages'), orderBy('createdAt'))));
  // same guest re-requests, host approves again (a fresh match at the same id)
  await assertSucceeds(setDoc(doc(as('bob'), 'requests/m2_bob'), requestDoc('m2', 'bob', 'alice')));
  await assertSucceeds(approve(as('alice'), 'm2', 'bob', 'alice'));
  // the previously denied guest can never come back (terminal by design)
  await assertFails(setDoc(doc(as('cara'), 'requests/m2_cara'), requestDoc('m2', 'cara', 'alice')));
});

// Documents a known deadlock (passing = the deadlock exists):
// docs/bugs/2026-10-12-cancel-meal-can-leave-a-stale-match-that-blocks-rematching.md
test('state machine: a failed deleteMatchTree after the meal reopened blocks every future approval of that meal', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(as('alice'), 'meals/m3'), mealDoc('m3', 'alice')));
  await assertSucceeds(setDoc(doc(as('bob'), 'requests/m3_bob'), requestDoc('m3', 'bob', 'alice')));
  await assertSucceeds(approve(as('alice'), 'm3', 'bob', 'alice'));
  // applyCancel's transaction committed (meal open, request deleted) but the process died before
  // deleteMatchTree: the matches doc is still there.
  await admin(async (db) => {
    await updateDoc(doc(db, 'meals/m3'), { status: 'open', guestId: null });
    await deleteDoc(doc(db, 'requests/m3_bob'));
  });
  await assertSucceeds(setDoc(doc(as('cara'), 'requests/m3_cara'), requestDoc('m3', 'cara', 'alice')));
  // the approve transaction cannot create matches/m3 again (matches update is `false`)
  await assertFails(approve(as('alice'), 'm3', 'cara', 'alice'));
});

test('state machine: host cancels -> meal cancelled; the guest can no longer request or re-open it', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(as('alice'), 'meals/m4'), mealDoc('m4', 'alice')));
  await assertSucceeds(setDoc(doc(as('bob'), 'requests/m4_bob'), requestDoc('m4', 'bob', 'alice')));
  await assertSucceeds(approve(as('alice'), 'm4', 'bob', 'alice'));
  await admin(async (db) => {
    await updateDoc(doc(db, 'meals/m4'), { status: 'cancelled' });
    await deleteDoc(doc(db, 'matches/m4'));
  });
  await assertFails(setDoc(doc(as('cara'), 'requests/m4_cara'), requestDoc('m4', 'cara', 'alice')));
  // the host cannot re-open it either (meals update only allows open -> matched)
  await assertFails(updateDoc(doc(as('alice'), 'meals/m4'), { status: 'open' }));
});

test('profiles: a person with no profile doc resolves to "not found", not an error', async () => {
  await seed();
  const snap = await assertSucceeds(getDoc(doc(as('bob'), 'profiles/ghost')));
  assert(!snap.exists());
});

// Desired behaviour that the rules do NOT yet have (skipped; see the bug files). Remove `skip`
// once the rules are tightened.
test('requests: a guest cannot store a client-chosen createdAt or extra keys', {
  skip: 'open bug: docs/bugs/2026-10-12-requests-rule-lets-a-guest-break-the-hosts-inbox.md',
}, async () => {
  await seed();
  await assertSucceeds(setDoc(doc(as('alice'), 'meals/m9'), mealDoc('m9', 'alice')));
  await assertFails(setDoc(doc(as('bob'), 'requests/m9_bob'), {
    ...requestDoc('m9', 'bob', 'alice'), createdAt: 'not-a-timestamp',
  }));
  await assertFails(setDoc(doc(as('bob'), 'requests/m9_bob'), {
    ...requestDoc('m9', 'bob', 'alice'), junk: 'x'.repeat(100000),
  }));
});

test('meals: restaurant must have the shape Discover parses', {
  skip: 'open bug: docs/bugs/2026-10-12-one-malformed-meal-breaks-discover-for-everyone.md',
}, async () => {
  await seed();
  await assertFails(setDoc(doc(as('alice'), 'meals/junk'), mealDoc('junk', 'alice', { restaurant: {} })));
  await assertFails(setDoc(doc(as('alice'), 'meals/junk'), mealDoc('junk', 'alice', {
    restaurant: { placeId: 5, name: null, address: 'a', lat: 'x', lng: [] },
  })));
});

test('profiles: displayName/bio/photoUrls are typed and size-capped', {
  skip: 'open bug: docs/bugs/2026-10-12-minor-findings-second-sweep.md',
}, async () => {
  await seed();
  await assertFails(setDoc(doc(as('bob'), 'profiles/bob'), { uid: 'bob', displayName: 12345 }, { merge: true }));
  await assertFails(setDoc(doc(as('bob'), 'profiles/bob'), { uid: 'bob', bio: 'x'.repeat(200000) }, { merge: true }));
  await assertFails(setDoc(doc(as('bob'), 'profiles/bob'), { uid: 'bob', photoUrls: 'not-a-list' }, { merge: true }));
});

function assert(cond) { if (!cond) throw new Error('assertion failed'); }
