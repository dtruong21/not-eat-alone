## [P3] Firestore/Storage rules accept unbounded or client-controlled values (reports, message timestamps, rating extra keys, storage env prefix)

**Repro (all against the Firestore emulator with `firebase/firestore.rules`, 72-case sweep; bob = any signed-in user):**
1. `reports`: `addDoc(reports, {reporterId: 'bob', targetType: 'user', targetId: 'x', note: 'z'.repeat(500000)})` and extra arbitrary keys are allowed (cases P5/P6).
2. `matches/{id}/messages`: a participant can write `createdAt: Timestamp(1970)` or a far-future timestamp (X8c); the rule only checks `senderId`, `text` size. Ordering and the "Seen" comparison use `createdAt`.
3. `ratings`: create accepts extra keys such as `aggregated: true` (Q8). `onRatingCreated` skips docs with `aggregated == true`, so a rater can submit a rating that is never aggregated (self-inflicted, but it breaks the idempotency flag's trust boundary).
4. `storage.rules`: `match /{env}/users/{uid}/{file}` does not constrain `env` to `stage|prod`; any signed-in user can write images (up to 8MB each) under `anything/users/{ownUid}/`.
5. `deleteAccount` callable has no `enforceAppCheck` (only `searchRestaurants` has it) and trusts a client-supplied `databaseId` (self-scoped, so harmless, but inconsistent with the App Check posture).
6. Women-only meals are readable (get/list) by any signed-in user (M0b); hiding is client-side only. Requests are still rule-gated by `gender == 'woman'`.

**Expected:** Defence in depth: key whitelists and size caps on user-writable documents; server timestamps for ordering fields.
**Actual:** As above. Everything else in the sweep behaved as designed (see TEST-PLAN sweep log): non-owner denied on users writes, fcmTokens, requests, matches, messages, reads, blocks, ratings; block both directions; decided-once requests; reminder flags (`reminder24hSent/reminder2hSent`) cannot be written by any client and do not interfere with the approve transaction.

**Device/OS:** Firestore emulator (firebase-tools 13.35, Node 22).
**Build:** develop @ 8cf1b41
**Frequency:** always.

**Hypothesis:** `reports`: `keys().hasOnly([...])` + `reason.size() <= 500`. `messages`: `createdAt == request.time`. `ratings`: `keys().hasOnly(['id','matchId','raterUid','targetUid','stars','showedUp','comment','createdAt'])`. Storage: `env in ['stage','prod']`. Add `enforceAppCheck: true` to `deleteAccount` once App Check enforcement is switched on.
