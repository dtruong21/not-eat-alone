## [P1] Any signed-in user can break Discover for every user in Paris with one malformed `meals` document, and nobody can remove it from the app

**Repro (rules emulator + fake Firestore, no device needed):**
1. As any signed-in account (phone / Apple / Google + age gate is the only barrier) write `meals/junk` with the keys the create rule whitelists but `restaurant: {}`, `status: 'open'`, `geohash: 'u09tv'`, `dateTime` = now + 1 year, `createdAt: serverTimestamp()`. The rules emulator accepts it (the create rule only checks `restaurant is map`; `restaurant: {placeId: 5, name: null, lat: 'x'}` is accepted too).
2. Open Discover as any other user in the Paris cell.

**Expected:** The junk document is rejected by the rules (restaurant shape validated like every other field) and/or skipped by the client so the valid meals still show.
**Actual:** `MealRepositoryImpl._mealFromData` throws `RepositoryParseException(meals/junk)` inside the snapshot `.map`; the stream emits an error, `discoveryControllerProvider` goes to `AsyncError` and Discover shows "Something went wrong - please try again." for everyone whose query contains the document (open, future, within the soonest 100). Every later snapshot still contains it, so pull-to-refresh does not help. Clients cannot delete or edit meals (`allow delete: if false`, update only `open -> matched` by the host), and "cancel an unmatched open meal" is deliberately not built, so the document stays until an admin deletes it (or its date passes - the attacker chooses a date a year out). This is a one-request availability attack on the core flow. The TEST-PLAN already lists "Discover should skip an unparseable meal instead of erroring the whole stream" as a deferred follow-up; with the unvalidated `restaurant` map it is exploitable.

**Regression tests (skipped until fixed):** `test/features/meal/data/meal_repository_poison_edge_test.dart` ("a malformed meal document is skipped; the valid ones still stream"). Rules emulator confirmation (not committed as a failing test): `restaurant: {}` write succeeds.

**Device/OS:** n/a (fake Firestore + Firestore emulator, firebase-tools 13.35).
**Build:** develop @ 979e5f2
**Frequency:** always.

**Hypothesis / fix (both, defence in depth):** (1) rules: `request.resource.data.restaurant.keys().hasOnly(['placeId','name','address','lat','lng']) && placeId/name/address is string && lat/lng is number && lat in [-90,90] && lng in [-180,180]` plus size caps on `name`/`address`; (2) client: in `watchDiscoverable` parse per document and drop (and log) the ones that fail instead of failing the whole snapshot. Add the matching case to `firebase/rules-test/` and to the `meals` whitelist contract test `test/core/firebase/rules_write_shape_contract_test.dart`.
