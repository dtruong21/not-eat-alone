## [P1] Any signed-in account can list/read every user doc, including exact date of birth, gender, bio and photos

**Repro:**
1. Firestore emulator with `firebase/firestore.rules`; two accounts alice and bob (both with a `users/{uid}` doc holding `dob`, `gender`, `displayName`, `photoUrls`).
2. As bob run `getDocs(collection(db, 'users'))` and `getDoc(doc(db, 'users/alice'))`.
3. Same as bob: `updateDoc(users/alice, {...})` is denied (good); `updateDoc(users/bob, {dob: <other date>, ageVerified: ...})` is allowed.

**Expected:** A user can read only the fields the product shows others (display name, photo(s), bio, derived age band, rating aggregate). Exact DOB and the whole user table are not enumerable. TEST-PLAN "Auth" says "Non-owner cannot read/write another user's `users/{uid}` doc".
**Actual:** `match /users/{uid} { allow read: if isSignedIn(); }` allows both `get` and `list` for any authenticated user. Verified live against the Firestore emulator (72-case sweep, cases U1/U1b): a single query dumps every user's exact `dob`, `gender`, `bio`, `displayName`, `photoUrls` and rating fields. The privacy policy (`docs/legal/privacy.md`) does not disclose DOB being readable by other users. Related: the owner can also rewrite their own `dob` / `ageVerified` after verification (U3/U3b), so the 18+ gate is purely self-attested with no server-side lock (acceptable only if documented as such).

**Device/OS:** Firestore emulator (firebase-tools 13.35, Node 22), no device involved.
**Build:** develop @ 8cf1b41
**Frequency:** always.

**Hypothesis:** Split profile data: `users/{uid}` (private: dob, ageVerified, gender used by rules) vs `profiles/{uid}` (public: displayName, photoUrls, bio, ageYears or age band, rating*), read-open only on the latter; keep `gender` readable only via the rule's `get()` (rules can read private docs the client cannot). If this is accepted for the Paris soft launch, downgrade to P2 explicitly and add it to the privacy policy + store data-safety/privacy labels ("date of birth: visible to other users").

**Workaround:** none client-side.
