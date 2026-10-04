# Convyve — Match Integrity (Plan 12)

**Date:** 2026-10-04
**Status:** Implemented
**Feature:** Close the "fabricated match" hole. A `matches/{id}` doc may only be created by the real approve flow: for a request that exists and is pending, being set to `approved` in the same transaction, on a meal being set to `matched` with that guest.

---

## 1. Problem

`firestore.rules` today:

```
match /matches/{matchId} {
  allow create: if isSignedIn()
                && request.resource.data.hostId == request.auth.uid;
  ...
}
```

The only check is `hostId == me`. Any signed-in user can create a match with **any** other user as `guestId`, with no meal, no request and no consent from the guest. Consequences:

- The forger can message a stranger (`messages` create requires only that the caller is a match participant and no block exists).
- The forger can rate a stranger (`ratingParticipantsValid` trusts the match doc), moving that person's `ratingAvg`. The recent doc-id pinning stops stuffing under arbitrary ids, but a forged match still allows one rating per forged match, and matches are free to create.
- The stranger sees a chat from someone they never matched with.

This was parked in Plan 6 ("rules-only fix collides with same-transaction `get()` ordering") and re-raised by the final review of the E2E branch.

## 2. Design

Firestore rules can read the state **after** a batch or transaction commits with `getAfter()`. The approve flow already writes all three documents in one client transaction (`RequestRepositoryImpl.approve`):

1. `meals/{mealId}` → `status: 'matched'`, `guestId`
2. `requests/{mealId}_{guestId}` → `status: 'approved'`
3. `matches/{mealId}` → create

So the `matches` create rule can require that the other two writes are present and valid.

### 2.1 The rule

```
// Helper: the approve transaction's other writes must be present.
function matchApprovalValid(mealId, guestId, hostId) {
  let reqPath  = /databases/$(database)/documents/requests/$(mealId + '_' + guestId);
  let mealPath = /databases/$(database)/documents/meals/$(mealId);
  let reqBefore  = get(reqPath).data;
  let reqAfter   = getAfter(reqPath).data;
  let mealBefore = get(mealPath).data;
  let mealAfter  = getAfter(mealPath).data;
  return reqBefore.status == 'pending'
      && reqBefore.hostId == hostId
      && reqBefore.guestId == guestId
      && reqAfter.status == 'approved'
      && mealBefore.status == 'open'
      && mealBefore.hostId == hostId
      && mealAfter.status == 'matched'
      && mealAfter.guestId == guestId;
}

match /matches/{matchId} {
  allow create: if isSignedIn()
                && request.resource.data.keys().hasOnly(['id', 'mealId', 'hostId', 'guestId', 'participants', 'createdAt'])
                && request.resource.data.createdAt == request.time
                && request.resource.data.hostId == request.auth.uid
                && request.resource.data.mealId == matchId
                && request.resource.data.id == matchId
                && request.resource.data.guestId != request.auth.uid
                && request.resource.data.participants
                     == [request.resource.data.hostId, request.resource.data.guestId]
                && noBlockBetween(request.resource.data.hostId, request.resource.data.guestId)
                && matchApprovalValid(matchId, request.resource.data.guestId, request.auth.uid);
  // get / list / update / delete unchanged
}
```

What each clause buys:

| Clause | Blocks |
|---|---|
| `keys().hasOnly([...six keys...])` | extra, unbounded keys on a match doc |
| `createdAt == request.time` | a missing or malformed `createdAt` (a string, a forged time) that would break the guest's Chats list parse (`MatchRepositoryImpl._fromDoc`); `FieldValue.serverTimestamp()` equals `request.time`, which is what `RequestRepositoryImpl.approve` writes |
| `hostId == auth.uid` | a body that names a third uid as host while the caller approves their own request |
| `mealId == matchId`, `id == matchId` | a match under an arbitrary id (matchId == mealId throughout the app) |
| `guestId != me`, `participants == [host, guest]` | self-match, and a participants list that disagrees with host/guest (the chat list query and message rules trust `participants`/host/guest) |
| `noBlockBetween` | approving a request after one party blocked the other |
| `reqBefore.status == 'pending'` + hosts/guest equal | forging with no request, or approving a denied or already-approved request |
| `reqAfter.status == 'approved'` | creating the match without actually approving the request |
| `mealBefore.status == 'open'`, `mealBefore.hostId == hostId` | matching a meal that isn't open or isn't the caller's |
| `mealAfter.status == 'matched'`, `mealAfter.guestId == guestId` | a match that disagrees with its meal |

Guest consent is the pending request itself: only the guest can create it (`requests` create requires `guestId == me`, an open meal, no block).

### 2.2 Access-call budget

Four distinct documents are read (`get`/`getAfter` on the request and the meal), plus the two `exists` calls in `noBlockBetween`: six accesses. The limit is 10 per single-document request and 20 for a transaction/batch, so the transaction has headroom. `getAfter()` semantics inside a client transaction must be validated live on the emulator (the plan's first rules test does exactly that: a transaction shaped like the app's approve must be **allowed**).

### 2.3 What does not change

- The app: `RequestRepositoryImpl.approve` already writes exactly the shape the rule requires. No `lib/` change is expected. If the live test shows the real flow is denied, that is a finding, not something to paper over.
- `get`/`list`/`update`/`delete` on `matches` (update and delete stay `false`).
- Existing matches: only `create` is tightened.
- Admin SDK writers (Cloud Functions, seed scripts) bypass rules.

## 3. Test harness

`integration_test/support/seed.dart`'s `seedMatch` currently writes the match doc directly as the host. That write becomes illegal by design. Post-match preconditions (chat, rating) need a way to seed state the rules forbid.

- Add `adminSetDoc(collection, id, fields)` to `integration_test/support/emulator_admin.dart`: a REST `PATCH` to the Firestore emulator with `Authorization: Bearer owner`, which bypasses security rules (the emulator's documented admin override). It encodes a Dart map into Firestore REST values (null, bool, int, double, String, DateTime as timestamp, List, Map).
- `seedMatch` keeps its signature and the SDK writes for the meal (create, then update to matched), and writes only the `matches` doc through `adminSetDoc`. A comment states why.
- The real approve path stays covered end to end by `request_match_test.dart` (through the UI) and by the new rules cases (through a raw SDK transaction).

## 4. Tests (`integration_test/rules_enforced_test.dart`)

All with real emulator uids, valid bodies, and only the property under test varying. Denials are pinned to `permission-denied`.

Allowed:
1. A transaction shaped exactly like the app's approve (meal → matched + guestId, request → approved, match create) by the host, on a real open meal with a real pending request from a guest.

Denied (each as a transaction or a single write by the host):
2. A match with no request at all.
3. A request that exists but the transaction does not set it to `approved` (match + meal only).
4. A request already `approved` or `denied` (pre-state not pending).
5. A meal that is not `open` (already matched).
6. A meal hosted by someone else (host forging a match on another host's meal).
7. `guestId` that differs from the request's guest.
8. `participants` that disagree with host/guest, or `guestId == hostId`.
9. A match id that is not the meal id.
10. A block between host and guest.

Existing coverage that must stay green: `request_match_test` (real UI approve), `chat_test`, `rating_test`, and the 20 existing rules cases.

## 5. Risks

- **`getAfter` inside a client transaction** behaves as documented but is unproven in this codebase. Mitigated by test 1 being the first thing the plan runs against the new rule.
- **Seed bypass hides regressions** in chat/rating setup. Accepted: those scenarios test chat and rating, and the approve path has its own coverage.
- **Production deploy** is manual (`firebase deploy --only firestore --project not-eat-alone`); CI skips deploy without the service-account secret. Nothing here is deployed by merging.

## 6. Non-goals

- Server-set `ageVerified` (needs Cloud Functions / Blaze).
- Moving approve into a Cloud Function.
- Changing the requests update rule's transition guard (status may still go pending → approved/denied by the host; the new match rule additionally requires the pre-state to be pending).
- App UI changes.

## 7. Delivery

Branch `feature/match-integrity` off `develop`, subagent-driven. Ordered to keep the tree green: admin seeding helper and `seedMatch` rewrite (rules unchanged, full suite still green) → the rule plus its ten rules cases → docs, changelog, final verification. Merged to `develop` only; no release to `main`.
