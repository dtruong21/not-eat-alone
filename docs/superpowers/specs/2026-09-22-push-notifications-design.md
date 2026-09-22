# Convyve — Push Notifications Design (Plan 8)

**Date:** 2026-09-22
**Status:** Approved (design), pending implementation plan
**Feature:** FCM device-token management on the client + the project's first Cloud Functions codebase, delivering event-driven pushes: a new join request (→ host), an approve/deny (→ guest), and a new chat message (→ the other party). Scheduled reminders and the post-meal prompt are deferred to a later slice.

---

## 1. Goal & constraints

When something happens that the recipient isn't looking at, they get a push on the right device that deep-links to the relevant screen. The client registers/refreshes FCM tokens and handles taps; Cloud Functions react to Firestore writes and send the messages. Everything is built and unit-tested now, but three things gate live delivery and are the user's homework: the Firebase **Blaze** plan (required to deploy Cloud Functions), an **APNs auth key** (iOS delivery) + **Android SHA-256/Play Integrity** (Android delivery), and a `FIREBASE_SERVICE_ACCOUNT` secret with Functions-deploy permissions (CD). None of these block writing or unit-testing the code.

Single Firebase project, split databases (`(default)`=prod, `stage`=stage). Firestore triggers are per-database, so every trigger is registered **twice** — once for each database — sharing one handler. Tokens are stored in the same database the app writes to for its flavor.

## 2. Flutter client — `notifications` feature (clean layers)

Add `firebase_messaging`. New feature `lib/features/notifications/`:

```
domain/
  entities/       push_route.dart            # sealed/enum result of a tapped payload
  repositories/   push_repository.dart       # permission + token registration interface
data/
  repositories/   push_repository_impl.dart  # firebase_messaging + firestore token writes
  push_route_mapper.dart                      # pure: message data map -> PushRoute (unit-tested)
application/
  push_providers.dart
  push_registration_controller.dart          # request permission + register + refresh wiring
presentation/     (no screen; a foreground listener wired in the app shell)
```

### Token registration

- `PushRepository` (domain interface):
  - `Future<bool> requestPermission()` — iOS + Android 13+ `POST_NOTIFICATIONS`.
  - `Future<void> registerToken(String uid)` — get the current FCM token, write `users/{uid}/fcmTokens/{token}` = `{ token, platform, updatedAt: serverTimestamp }` (in the flavor DB via `db`); also subscribe to `onTokenRefresh` and upsert on change.
  - `Future<void> unregisterCurrentToken(String uid)` — delete the current token doc on sign-out.
- `push_repository_impl.dart` — the only notifications file importing `firebase_messaging` + `cloud_firestore`. `platform` is `'ios'`/`'android'` from `defaultTargetPlatform`.

### Permission + lifecycle

- `push_registration_controller.dart` (`@riverpod` AsyncNotifier or a small init hook): once a signed-in, onboarded user is present, request permission (best-effort; a denial disables pushes silently — the app still works), then `registerToken(uid)`. Wire from the app shell/init. On sign-out, `unregisterCurrentToken` before the auth state clears (hook into the existing sign-out path).

### Foreground + tap handling

- A foreground listener (`FirebaseMessaging.onMessage`) shows a lightweight in-app banner/snackbar (no full screen). Wired once in the app shell.
- Tap handling: `FirebaseMessaging.onMessageOpenedApp` + `getInitialMessage()` (cold start) → pass `message.data` through the pure `pushRouteMapper` → navigate via the router:
  - `type: 'message'` + `matchId` → `/chats/:matchId`
  - `type: 'request'` (new request) → `/requests`
  - `type: 'request_update'` + `mealId` → `/meals/detail`? No — the guest's meal-detail needs the `Meal` object (passed via `extra`, not available from a push). Route the guest to `/chats/:matchId` when approved (a match now exists; matchId == mealId), and to `/requests`? The guest has no requests inbox. **Decision:** `request_update` (approved) → `/chats/:mealId` (the new chat); (denied) → `/discover` (nothing to open). Encode the destination in the payload's `type`/data so the mapper is pure.
- `pushRouteMapper` is a pure function `PushRoute? mapPushData(Map<String, String?> data)` returning a typed route (path + optional param), unit-tested against each payload shape. The navigation side-effect lives in the shell listener, not the mapper.

### Native config (structural, added now)

- iOS `Info.plist`: `UIBackgroundModes` → `remote-notification`. (APNs key + capability = user homework; without it iOS won't deliver but the app builds.)
- Android: `POST_NOTIFICATIONS` permission in the manifest; a default notification channel + a monochrome notification icon; `firebase_messaging` gradle wiring is automatic via `google-services`.

## 3. Cloud Functions — `firebase/functions/` (TypeScript)

First Functions codebase. `firebase.json` already declares `functions.source = firebase/functions`, `codebase = default`, predeploy `npm run build`.

```
firebase/functions/
  package.json          # firebase-admin, firebase-functions (v2), typescript, eslint, dev: firebase-functions-test, jest/vitest
  tsconfig.json
  .eslintrc.cjs
  .gitignore            # node_modules, lib/
  src/
    index.ts            # exports all trigger functions (per database)
    lib/
      messaging.ts      # sendToUser() + token pruning
      payloads.ts       # pure payload builders (unit-tested)
    triggers/
      request_created.ts
      request_updated.ts
      message_created.ts
  test/
    payloads.test.ts
    messaging.test.ts
```

### Shared helpers

- `payloads.ts` (pure, no admin SDK): `buildRequestCreated()`, `buildRequestUpdated(status)`, `buildMessageCreated(senderName, textPreview)` → `{ notification: {title, body}, data: {type, ...ids} }`. Unit-tested. Text preview truncated (~120 chars), no PII beyond the sender's display name in the body.
- `messaging.ts`: `sendToUser(databaseId, uid, message)` — `getFirestore(getApp(), databaseId)`, read `users/{uid}/fcmTokens`, `getMessaging().sendEachForMulticast(...)`, and delete token docs whose send failed with `messaging/registration-token-not-registered` / `invalid-argument`. The token-pruning decision is a pure helper `tokensToPrune(responses, tokens)` — unit-tested.

### Triggers (each registered for both databases)

Using `firebase-functions/v2/firestore`, region `europe-west1`. A factory builds a handler; `index.ts` exports one function per (event × database):

- `request_created`: `onDocumentCreated({document: 'requests/{requestId}', database})` → read the created request, `sendToUser(database, hostId, buildRequestCreated(...))`.
- `request_updated`: `onDocumentUpdated({document: 'requests/{requestId}', database})` → if `before.status != after.status` and `after.status ∈ {approved, denied}` → `sendToUser(database, guestId, buildRequestUpdated(after.status))`.
- `message_created`: `onDocumentCreated({document: 'matches/{matchId}/messages/{messageId}', database})` → read the parent match's `participants`, pick the recipient (participant ≠ `senderId`), look up the sender's `displayName` (from `users/{senderId}` in the same DB), `sendToUser(database, recipientUid, buildMessageCreated(...))`.

`index.ts` exports, e.g., `requestCreatedDefault`, `requestCreatedStage`, `requestUpdatedDefault`, `requestUpdatedStage`, `messageCreatedDefault`, `messageCreatedStage` — six functions, two thin wrappers per event passing `database: '(default)'` / `'stage'` into the shared handler.

### Idempotency / safety

- Handlers no-op cleanly when the recipient has no tokens (nothing to send).
- A message from a user to themselves (shouldn't happen) or a request with a missing host is guarded (early return).
- Functions never throw on a single bad token — prune and continue.

## 4. Rules

`firebase/firestore.rules` — add under `users/{uid}`:

```
match /fcmTokens/{token} {
  allow read, write: if isOwner(uid);   // owner-only; tokens are private device ids
}
```

(Existing `users/{uid}` rules unchanged. `isOwner` helper already exists.) Deploy to both databases.

## 5. CI / CD wiring

- **CI** (`ci.yml`): add a fast `functions-build` job (ubuntu) — `npm ci` + `npm run build` (tsc) + `npm test` in `firebase/functions`, so TypeScript errors and the functions unit tests gate PRs. Cheap (no Flutter). Add it to the branch-protection required checks once it exists.
- **CD** (`deploy.yml`): add `functions` to the deploy `--only` list (`firestore,storage,functions`) and, before deploy, `npm ci` in `firebase/functions` (the predeploy `npm run build` then compiles). Still gated behind `FIREBASE_SERVICE_ACCOUNT` — and Functions deploy additionally needs the **Blaze** plan + the service account having Cloud Functions Admin. Documented in `docs/CICD.md`.
- `docs/CICD.md` updated: Blaze requirement, the functions build/deploy steps, and that `europe-west1` is the functions region.

## 6. Analytics

Declared in `events.dart` + `docs/TRACKING-PLAN.md`, no PII:
- `push_permission_granted` (props: `granted` bool)
- `push_opened` (props: `type` — the payload type string, e.g. `message`/`request`/`request_update`)

(The Cloud Functions themselves don't emit product analytics in v1.)

## 7. Testing

- **Flutter**
  - `push_route_mapper`: each payload shape → the right `PushRoute`; unknown/missing type → null (no crash).
  - `push_repository_impl` (fake_cloud_firestore + a faked messaging seam): `registerToken` writes `users/{uid}/fcmTokens/{token}` with platform; `unregisterCurrentToken` deletes it. (The `firebase_messaging` calls are behind a thin injectable seam so the token I/O is testable without a real plugin.)
  - `push_registration_controller`: permission granted → registers; denied → no token write, no crash; sign-out → unregister called. Fires `push_permission_granted`.
- **Cloud Functions**
  - `payloads.test.ts`: each builder returns the expected title/body/data; preview truncation; no undefined ids.
  - `messaging.test.ts`: `tokensToPrune` selects exactly the tokens whose response error is a not-registered/invalid code, leaving valid ones; `sendToUser` no-ops with zero tokens (mocked firestore + messaging).
- **Rules** (manual/emulator note in TEST-PLAN): a user reads/writes only their own `fcmTokens`; another user is denied.
- **Live delivery** (documented as pending in TEST-PLAN): needs Blaze + APNs key + Android SHA + a physical device — a manual checklist, not automatable here.

## 8. Non-goals (deferred)

- Scheduled reminders **T-24h / T-2h** before a meal + the **post-meal prompt** (need Cloud Scheduler + time-window queries; post-meal overlaps Plan 10 ratings) — a follow-up slice.
- Notification preferences / per-type opt-outs, quiet hours, badge counts, an in-app notification center, rich (image) notifications.
- Analytics from within Functions; delivery/open-rate tracking beyond the client `push_opened`.
- Live device delivery verification (gated on Blaze + APNs/SHA).

## 9. Delivery

Own plan on branch `feature/plan-8-push` (off `develop`), executed subagent-driven. Ordered so the tree stays green: FCM dep + native config + `fcmTokens` rule → push domain + route mapper (pure) → push repository impl + token I/O → registration controller + providers + analytics → foreground/tap wiring in the shell → Functions scaffold (package/tsconfig/eslint) → Functions pure helpers (payloads + prune) + tests → Functions triggers (both databases) → CI functions-build job + CD `--only` functions + docs → verify/build/PR to `develop`.
