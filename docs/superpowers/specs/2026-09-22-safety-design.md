# Convyve — Safety & Moderation Design (Plan 9)

**Date:** 2026-09-22
**Status:** Approved (design), pending implementation plan
**Feature:** The launch-blocking safety set — block (bidirectional hide + rule-enforced), report (user/meal/message), women-only request enforcement, a callable account-deletion cascade, and a safety-tips card. Automated content moderation is deferred.

---

## 1. Goal & constraints

Users must be able to protect themselves and the platform must meet store safety requirements before launch. A block hides two users from each other and prevents any interaction. Reports persist for manual review. Women-only meals reject non-women at the rules layer, not just the UI. A user can delete their account and have their data purged (Apple/Play requirement). No automated content-moderation Function in v1 — manual reports are the moderation path; auto-moderation (external API + Blaze) is a later hardening slice.

Single Firebase project, split databases. `blocks`/`reports` live in the flavor's database like everything else. The account-deletion cascade runs in the Cloud Functions codebase built in Plan 8 (needs Blaze — already required for push).

## 2. Block

### Model

Top-level `blocks/{blockerUid}_{blockedUid}`:

```
{ blockerUid, blockedUid, pair: [blockerUid, blockedUid], createdAt }
```

The `pair` array makes both parties able to find blocks involving them in one query (`where('pair', arrayContains: myUid)`), which is what powers bidirectional hiding.

### Rules

```
match /blocks/{blockId} {
  allow read: if isSignedIn() && request.auth.uid in resource.data.pair;
  allow create: if isSignedIn()
                && request.resource.data.blockerUid == request.auth.uid
                && request.resource.data.blockerUid != request.resource.data.blockedUid
                && request.resource.data.pair == [request.resource.data.blockerUid, request.resource.data.blockedUid];
  allow delete: if isSignedIn() && resource.data.blockerUid == request.auth.uid; // only the blocker unblocks
  allow update: if false;
}
```

### Repository & enforcement

- `safety/domain/repositories/block_repository.dart`: `block(String blockedUid)`, `unblock(String blockedUid)`, `watchBlockedUserIds() → Stream<Set<String>>` (the "other" uid from every block whose `pair` contains me — the hide-set).
- Client hiding:
  - Discovery controller: filter out meals whose `hostId` is in the hide-set. Combine the hide-set stream into the existing discovery pipeline.
  - Chat list: filter out matches whose other participant is in the hide-set.
- Rules enforcement at interaction points (a block is not just UI):
  - `requests/{id}` create — reject when a block exists either direction between guest and host:
    ```
    && !exists(/databases/$(database)/documents/blocks/$(request.resource.data.guestId + '_' + request.resource.data.hostId))
    && !exists(/databases/$(database)/documents/blocks/$(request.resource.data.hostId + '_' + request.resource.data.guestId))
    ```
  - `matches/{matchId}/messages/{id}` create — the `matchParticipant` helper already reads the parent match; extend the messages-create rule to compute the other participant and reject when a block exists either direction:
    ```
    function noBlockBetween(a, b) {
      return !exists(/databases/$(database)/documents/blocks/$(a + '_' + b))
             && !exists(/databases/$(database)/documents/blocks/$(b + '_' + a));
    }
    ```
    In the messages-create rule, derive `other` from the parent match (`hostId`/`guestId` vs `senderId`) and require `noBlockBetween(request.auth.uid, other)`.

### Silent-block note (deferred)

A blocked user can technically detect a block by inspecting `blocks` data (they are in `pair`). The app never surfaces this. Truly-silent blocking (a Function mirroring into per-user private hide-lists) is a deferred hardening; the pair-readable model is chosen for v1 because it is instant, simple, and rule-enforceable.

## 3. Report

### Model

`reports/{autoId}`:

```
{ reporterId, targetType: 'user' | 'meal' | 'message', targetId, reason, createdAt, status: 'open' }
```

### Rules

```
match /reports/{reportId} {
  allow create: if isSignedIn()
                && request.resource.data.reporterId == request.auth.uid
                && request.resource.data.targetType in ['user', 'meal', 'message'];
  allow read, update, delete: if false; // admin-only via console/Function
}
```

### Repository & UI

- `safety/domain/repositories/report_repository.dart`: `report({required String targetType, required String targetId, String? reason})`.
- A shared "Report" bottom sheet (reason chips + optional note). Entry points: the other user's profile (in the chat header / meal-detail host block), a meal (meal detail), a chat message (long-press). Reason is a short enum-ish string (`inappropriate`, `spam`, `harassment`, `fake`, `other`).

## 4. Women-only enforcement

Currently women-only meals are only hidden client-side (Plan 5 discovery). Enforce at the request rule so a non-woman can't join even via a deep link:

- Extend `requests/{id}` create rule: if the target meal is women-only, the requester must be a woman:
  ```
  && (get(/databases/$(database)/documents/meals/$(request.resource.data.mealId)).data.womenOnly == false
      || get(/databases/$(database)/documents/users/$(request.resource.data.guestId)).data.gender == 'woman')
  ```
- Client guard: on meal detail, a non-woman viewing a women-only meal sees the request control disabled with "This meal is women-only." (Discovery already hides them; this covers deep links / matched banners.)

## 5. Account deletion (callable Cloud Function)

- Add a callable `deleteAccount` to `firebase/functions/` (v2 `onCall`, region `europe-west1`). Input: `{ databaseId }` (the caller's flavor DB: `'(default)'` or `'stage'`). Auth required (`request.auth.uid`).
- Cascade (admin SDK, in `databaseId`):
  - Delete `users/{uid}` (+ subcollections `fcmTokens`, and any other user subcollections).
  - Delete the user's `meals` (where `hostId == uid`) and their subcollections if any.
  - Delete `requests` where `guestId == uid` or `hostId == uid`.
  - Delete `matches` where `pair`/`participants` contains uid, plus each match's `messages` + `reads` subcollections.
  - Delete `blocks` where `pair` contains uid.
  - Delete Storage objects under `{prefix}/users/{uid}/**` (prefix from the flavor — pass or derive; the client can pass the storage prefix too, or the Function maps databaseId→prefix: `stage`→`stage`, `(default)`→`prod`).
  - Delete the Firebase Auth user (`getAuth().deleteUser(uid)`).
- Helpers factored as pure where possible (e.g. the list of collection queries) so the deletion plan is unit-testable; the admin execution is integration/emulator.
- Client: `safety/data` calls the callable via `cloud_functions` (add `cloud_functions` dep). A `AccountRepository.deleteAccount()` interface in `user` or `safety`. Profile/settings → "Delete account" → a confirming dialog (irreversible, typed confirm or a clear two-step) → call → on success sign out and return to `/auth/signin`.
- The callable is region-pinned; the client uses `FirebaseFunctions.instanceFor(region: 'europe-west1')`.

## 6. Safety-tips card

- A static `SafetyTipsCard` widget (tokens) with 3–4 tips: meet in a public place, tell a friend where you're going, trust your instincts, you can block/report anytime. Shown on the chat screen (once matched, above/below the message list or behind an info action) — the moment a meetup becomes real. No data, no config.

## 7. Analytics

Declared in `events.dart` + `docs/TRACKING-PLAN.md`, no PII:
- `user_blocked`
- `user_reported` (props: `target_type`)
- `account_deletion_requested`

## 8. Feature layout

```
lib/features/safety/
  domain/repositories/  block_repository.dart, report_repository.dart, account_repository.dart
  data/                 dtos + mappers (block/report) + repositories/ (block/report/account impls)
  application/          providers + controllers (block, report, account-deletion)
  presentation/         report_sheet.dart, block/report actions, widgets/safety_tips_card.dart
```

Discovery + chat controllers gain block filtering (in `meal`/`chat` application). Rules changes in `firebase/firestore.rules`. The deletion callable in `firebase/functions/`.

## 9. Testing

- Block repo (fake_cloud_firestore): `block` writes `blocks/{a}_{b}` with `pair`; `watchBlockedUserIds` returns the other uid from every pair containing me (both as blocker and blocked); `unblock` deletes.
- Discovery/chat filter: a meal/match involving a blocked uid is excluded (controller tests with a seeded hide-set).
- Report repo: `report` writes a `reports` doc with reporter + targetType/targetId.
- Women-only: rule + a client guard test (non-woman → request disabled; woman → enabled).
- Deletion: unit-test the pure "what to delete" plan (collection/query list) in the Function; the cascade execution is an emulator/manual check (documented). Client: `AccountController.delete` calls the callable + signs out; error surfaces.
- Rules (manual/emulator): a blocked pair cannot create a request or a message between them; a non-woman cannot create a request on a women-only meal; `reports` is create-only (no client read); `blocks` read only by the pair.
- Widgets: report sheet submits; block action confirms; safety-tips card renders; account-deletion confirm dialog gates the call.

## 10. Non-goals (deferred)

- Automated content moderation (image SafeSearch / text moderation Function + external API) — manual reports cover v1.
- Function-mirrored truly-silent blocks.
- An in-app admin/moderation dashboard (reports reviewed via the Firebase console for v1).
- Report rate-limiting / abuse prevention on reports themselves.
- Re-verification / appeals flow.

## 11. Delivery

Own plan on branch `feature/plan-9-safety` (off `develop`), executed subagent-driven. Ordered so the tree stays green: block model + rules → block repo + providers → discovery/chat block filtering → report model + rules + repo + sheet → women-only rule + client guard → safety-tips card → account-deletion callable (Function) + pure plan tests → account-deletion client (dep + repo + controller + confirm dialog + wire in profile) → analytics + docs + rules deploy → verify/build/PR to `develop`.
