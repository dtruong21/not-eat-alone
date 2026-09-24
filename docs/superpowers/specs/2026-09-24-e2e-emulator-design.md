# Convyve — End-to-End Testing on the Firebase Emulator Suite (E2E Plan)

**Date:** 2026-09-24
**Status:** Approved (design), pending implementation plan
**Feature:** A repeatable, CI-runnable end-to-end test harness that boots the real Flutter app against the Firebase Emulator Suite (Auth + Firestore + Functions + Storage), exercising the real Firestore security rules and the real Cloud Functions triggers across the app's core flows. Automated E2E lives on emulators; a live `stage`-backend pass stays a documented manual smoke.

---

## 1. Goal & constraints

Give the app one honest, automated integration path that proves the pieces work **together** — client widgets, Riverpod controllers, `firestore.rules`, and the TypeScript Cloud Functions — the way unit/widget tests (which stub Firebase via `fake_cloud_firestore`) cannot. It must:

- Run locally and in CI with **one command**, no real Firebase project, no network, no cost, no App Check / APNs / Blaze dependency.
- Load the **real** `firebase/firestore.rules` and the **real** `firebase/functions` build, so a rules regression or a broken trigger fails the suite.
- Stay isolated from prod/stage data (emulators are ephemeral, seeded per run).

Non-goal: automating the Google/Apple sign-in **button** (real OAuth can't run in the emulator) and testing push **delivery** (FCM has no emulator). Those stay in the manual `stage` smoke checklist.

## 2. Architecture overview

```
firebase emulators:exec "fvm flutter test integration_test"
  ├─ boots: auth 9099, firestore 8080 (loads firestore.rules),
  │         functions 5001 (loads built firebase/functions),
  │         storage 9199, ui 4000
  └─ runs: integration_test/*_test.dart
        ├─ app_harness.dart  → boots real app widget tree, SDKs → emulators,
        │                       App Check + Crashlytics OFF
        ├─ support/auth.dart → sign test users in via fake Google credential
        ├─ support/seed.dart → SDK writes to set preconditions
        └─ app_test.dart     → drives UI, asserts UI + Firestore + Function effects
```

## 3. Emulator configuration

Add an `emulators` block to `firebase.json` (ports above; `singleProjectMode: true`; `ui.enabled: true`). The existing `firestore` array already points both databases at `firebase/firestore.rules`, so the emulator serves the real rules. The `functions` codebase already builds via its `predeploy`; the emulator serves the built output.

**Named-database decision:** the Firestore emulator serves the `(default)` database. The E2E harness therefore runs with a Firestore db id of `(default)` (see §4 test flavor). The prod/stage split (`(default)` vs named `stage`) is a **real-backend** concern and stays covered by the manual `stage` smoke, not by emulator E2E. Rationale: keeps the harness simple and avoids emulator named-db edge cases; the rules and Functions under test are byte-identical across databases.

## 4. Bootstrap emulator seam

`bootstrap()` in `lib/main_common.dart` gains an optional, default-off emulator switch. Shape:

- A small value object `EmulatorConfig({required String host, ...ports})` (or a single `bool useEmulators` reading a fixed localhost + default ports). Prefer the value object for host override (Android emulator uses `10.0.2.2`, CI/desktop uses `127.0.0.1`).
- New optional param `EmulatorConfig? emulator` on `bootstrap`. When non-null, **after** `Firebase.initializeApp` and **before** any SDK use:
  - `FirebaseFirestore.instanceFor(app, databaseId).useFirestoreEmulator(host, 8080)`
  - `FirebaseAuth.instance.useAuthEmulator(host, 9099)`
  - `FirebaseFunctions.instanceFor(region: 'europe-west1').useFunctionsEmulator(host, 5001)`
  - `FirebaseStorage.instance.useStorageEmulator(host, 9199)`
  - **Skip** `FirebaseAppCheck.instance.activate(...)` entirely.
  - **Skip** Crashlytics collection wiring (leave collection disabled; harness sets nothing).
- Shipped `main_stage.dart` / `main_prod.dart` pass no `emulator` → zero behaviour change in real builds. The harness (`integration_test/support/app_harness.dart`) calls `bootstrap(config: <test flavor>, options: ..., emulator: EmulatorConfig.local())`.

**Test flavor for db id:** the harness uses a `FlavorConfig` whose `firestoreDatabaseId == '(default)'` (i.e. `Flavor.prod`-shaped) so the emulator's `(default)` db is hit. It keeps `appTitle`/storage prefix irrelevant to the assertions. If any code reads `FlavorConfig.current.isStage` for behaviour under test, note it in the plan and pick the flavor that keeps the scenario meaningful.

**Region note:** any repository that constructs `FirebaseFunctions` must use `instanceFor(region: 'europe-west1')` consistently so the emulator seam and prod agree. Verify during the plan; if a repo uses the default region, the seam must match it.

## 5. Test authentication

The app ships Google + Apple providers only. The Auth emulator accepts **any** OAuth credential without contacting Google, so:

- `support/auth.dart` exposes `signInTestUser({required String uid, String? email})` → builds `GoogleAuthProvider.credential(idToken: <emulator fake>, accessToken: <fake>)` and calls `FirebaseAuth.instance.signInWithCredential(...)`, or uses the emulator REST `signInWithIdp` shortcut. Returns the created `User`.
- Two fixtures: `host` and `guest`. Helpers `asHost()` / `asGuest()` sign the respective user in (sign-out between when a scenario switches actor).
- The **sign-in UI** (the Google button flow) is **out of scope** for automated E2E — it needs real OAuth. It is listed in the manual `stage` smoke checklist instead.

## 6. Seeding

`support/seed.dart` writes preconditions directly through the (emulator-pointed) SDK — faster and less brittle than driving multi-screen setup through the UI for every test:

- `seedUserProfile(uid, {gender, dob, ...})` — writes a valid `users/{uid}` doc (rules require `uid`, `dob` timestamp, `ageVerified` bool, rating fields 0).
- `seedMeal({hostId, ...})` — writes an `open` `meals/{id}` doc.
- Each test clears emulator state first via the Firestore emulator's REST clear endpoint (`DELETE /emulator/v1/projects/<id>/databases/(default)/documents`) plus Auth clear (`DELETE /emulator/v1/projects/<id>/accounts`), so tests are independent and order-free.

Preconditions are seeded via SDK; the **behaviour under test** is always driven through the UI (or the client repository) so the flow, rules, and triggers all run for real.

## 7. Scenarios (incremental)

Right-sized so each is an independently reviewable task. Ship in this order:

1. **Smoke** — harness boots the real app against emulators, a seeded test user is signed in, the app renders the Discover feed (or its empty state) without error. Proves seam + auth + rules read path. *(This is the first deliverable — everything else layers on it.)*
2. **Request → approve → match** — guest (seeded profile) sees host's seeded open meal, sends a join request; assert `requests/{id}` created under rules; sign in as host, approve; assert the approve transaction locks the meal (`matched` + `guestId`), creates `matches/{mealId}` with `participants`, and denies sibling pending requests. Exercises the client approve transaction + `request_updated`/match Functions.
3. **Chat** — with a match from (2), host posts a message; assert `matches/{id}/messages/{msg}` passes `matchMessageCreateOk` rule; guest reads it; a `reads/{uid}` receipt writes. (Blocked-pair negative case if cheap: a block between the two makes message-create fail.)
4. **Rating aggregate** — both parties rate after the meal; assert two `ratings/{matchId}_{uid}` docs, and that the `onRatingCreated` Function updates each target's `ratingCount`/`ratingAvg` (poll the user doc until the trigger fires; the emulator runs triggers asynchronously). This is the headline Functions-under-test scenario.

Each scenario is a task: write the test, run it red against a stub/empty impl or a deliberately wrong expectation, wire whatever harness support it needs, run green, commit.

## 8. One-command run + CI

- **Local:** a `Makefile`/README target: `firebase emulators:exec --only auth,firestore,functions,storage "fvm flutter test integration_test"`. `emulators:exec` boots, waits for readiness, runs the command, tears down, and propagates the exit code.
- **CI:** new job in `.github/workflows/ci.yml` (or a dedicated `e2e.yml`), gated the same as the other checks. Steps: checkout → setup Node + `npm ci` + `npm run build` in `firebase/functions` → setup Flutter (FVM) → `flutter pub get` + codegen → install `firebase-tools` → `firebase emulators:exec ...` as above. Runs headless (Flutter integration tests execute on the Dart VM / a desktop or `flutter-tester` device in CI — confirm the device target in the plan; likely `flutter test integration_test` with the linux desktop or the headless test device). Add it to branch-protection required checks **only after** it is proven stable (initially non-blocking to avoid gating on a flaky new job).
- Emulator readiness/seed timing and trigger-async waits use bounded polling helpers (no fixed sleeps) so CI stays deterministic.

## 9. Files

```
firebase.json                                  (modify: add emulators block)
lib/main_common.dart                           (modify: EmulatorConfig seam)
lib/core/config/emulator_config.dart           (create: EmulatorConfig value object)
integration_test/support/app_harness.dart      (create: boot app on emulators)
integration_test/support/auth.dart             (create: fake-credential test sign-in)
integration_test/support/seed.dart             (create: SDK seeding + emulator clear)
integration_test/smoke_test.dart               (create: scenario 1)
integration_test/request_match_test.dart       (create: scenario 2)
integration_test/chat_test.dart                (create: scenario 3)
integration_test/rating_test.dart              (create: scenario 4)
.github/workflows/ci.yml (or e2e.yml)          (modify/create: emulator E2E job)
docs/TEST-PLAN.md                              (modify: add E2E + manual stage smoke checklist)
Makefile or docs note                          (create/modify: one-command run target)
```

## 10. Non-goals (deferred / manual)

- Automating the Google/Apple sign-in button (real OAuth) — manual `stage` smoke.
- Push (FCM) delivery — no emulator; assert the Function *writes/enqueues*, not device receipt.
- Named `stage` database in the emulator — E2E runs on `(default)`; prod/stage split verified by manual stage smoke.
- Real-device / golden-image visual testing.
- Making the E2E job a **required** branch-protection check on day one (add after it proves stable).

## 11. Delivery

Branch `feature/e2e-emulator` (off `develop`), executed subagent-driven. Order keeps the tree green: emulator config + bootstrap seam → harness + auth + seed support → smoke test (scenario 1) → request/match → chat → rating → one-command run + CI job → docs (TEST-PLAN manual smoke + README run target) → verify + PR to `develop`.
