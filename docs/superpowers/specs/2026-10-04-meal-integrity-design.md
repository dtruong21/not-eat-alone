# Convyve — Meal Integrity (Plan 13)

**Date:** 2026-10-04
**Status:** Implemented
**Feature:** Close the remaining rule gaps around meals and the request/rating lifecycle that the Plan 12 final review found. A meal's host can no longer be reassigned, a meal can only move to `matched` through a genuine approve, a request can only be decided once, and a rating can only be left after the meal has happened.

---

## 1. Problems (all pre-existing, found by the final review of Plan 12)

Today in `firestore.rules`:

```
match /meals/{mealId} {
  allow create: if isSignedIn()
                && request.resource.data.hostId == request.auth.uid
                && request.resource.data.status is string
                && request.resource.data.geohash is string
                && request.resource.data.dateTime is timestamp;
  allow read: if isSignedIn();
  allow update, delete: if isSignedIn() && resource.data.hostId == request.auth.uid;
}
```

1. **Host reassignment (Important).** `update` only checks the *current* `hostId`. A host can set `hostId` to a stranger X. X then appears in Discover as the host of a meal they never created, and every new request (and its push notification) goes to X. It is impersonation and harassment with no match needed.
2. **Bait and switch.** The same unrestricted update lets a host change `dateTime`, `restaurant` or `womenOnly` after guests have already requested, or set `status: 'matched'` and any `guestId` with no request.
3. **Free-form create.** A meal can be created already `matched`/`completed`, with a `guestId`, or with a `dateTime` in the past.
4. **`requests` update has no pre-state guard.** A host can flip a request approved ↔ denied indefinitely. Each flip fires `request_updated` and pushes the guest.
5. **Ratings are not gated on the meal having happened.** A host can approve a guest and immediately 1-star them, before the meal.

## 2. Design

### 2.1 `meals`

The app writes `meals` in exactly two client paths: `MealRepositoryImpl.createMeal` (create) and the approve transaction (`status: matched`, `guestId`). The Cloud Function `postMealReminder` (status → `completed`) and account deletion use the Admin SDK and bypass rules. There is no edit, cancel or delete UI. So the rule can be as narrow as the app's real behaviour.

```
// Helper: the request being approved in this transaction (read once via `let`).
function mealApprovalLink(mealId, guestId, hostId) {
  let reqPath = /databases/$(database)/documents/requests/$(mealId + '_' + guestId);
  let req = get(reqPath).data;
  return req.status == 'pending'
      && req.hostId == hostId
      && req.guestId == guestId
      && getAfter(reqPath).data.status == 'approved';
}

match /meals/{mealId} {
  allow create: if isSignedIn()
                && request.resource.data.hostId == request.auth.uid
                && request.resource.data.status == 'open'
                && (!('guestId' in request.resource.data)
                    || request.resource.data.guestId == null)
                && request.resource.data.keys().hasOnly(['id', 'hostId', 'restaurant', 'dateTime', 'geohash', 'note', 'womenOnly', 'seats', 'status', 'guestId', 'createdAt'])
                && request.resource.data.restaurant is map
                && request.resource.data.womenOnly is bool
                && request.resource.data.seats is int
                && (!('note' in request.resource.data)
                    || request.resource.data.note == null
                    || (request.resource.data.note is string
                        && request.resource.data.note.size() <= 200))
                && request.resource.data.createdAt == request.time
                && request.resource.data.geohash is string
                && request.resource.data.dateTime is timestamp
                && request.resource.data.dateTime > request.time;
  allow read: if isSignedIn();
  allow update: if isSignedIn()
                && resource.data.hostId == request.auth.uid
                && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'guestId'])
                && resource.data.status == 'open'
                && resource.data.dateTime > request.time
                && request.resource.data.status == 'matched'
                && request.resource.data.guestId is string
                && mealApprovalLink(mealId, request.resource.data.guestId, request.auth.uid)
                && existsAfter(/databases/$(database)/documents/matches/$(mealId));
  allow delete: if false;
}
```

- `hostId`, `dateTime`, `restaurant`, `womenOnly`, `geohash` become immutable (only `status` and `guestId` may change).
- `status` can only go `open → matched`, and only together with a genuine pending→approved request from that guest in the same transaction (the same `getAfter` technique as the `matches` create rule). A host can no longer mark a meal matched, or pick a guest, on their own.
- Create requires `status == 'open'`, no `guestId` (absent **or null**: `MealRepositoryImpl.createMeal` writes `MealDto.toJson()`, which includes `guestId: null` and `note: null`), and a future `dateTime`.
- Create also whitelists the keys and types the app writes (final-review finding, pre-existing): `keys().hasOnly([id, hostId, restaurant, dateTime, geohash, note, womenOnly, seats, status, guestId, createdAt])`, `restaurant` is a map, `womenOnly` a bool, `seats` an int, `note` absent/null or a string of at most 200 characters (the create screen's `_maxNoteLength`), and `createdAt == request.time` (the app writes `serverTimestamp()`). One malformed meal would otherwise break Discover for everyone in its geohash cell (the stream maps every doc through `_mealFromDoc`, which throws), and with no client delete only an admin could clean it up.
- The update also requires the meal to be still in the future (`resource.data.dateTime > request.time`). `postMealReminder` only completes `matched` meals, so an unmatched past meal stays `open`; without this a host could approve a request on it and rate instantly. Blocking the meal flip is enough to block the match (the `matches` create needs `mealAfter.status == 'matched'`).
- The meal flip also requires the `matches/{mealId}` doc to exist after the write (`existsAfter`), i.e. the same transaction creates it. Without that, a host could flip the meal and approve the request but skip the match create (and its `noBlockBetween` check), leaving the guest with an approved request and no chat. The `matches` create rule keeps enforcing the block check and the rest of the match shape.
- No client delete (`allow delete: if false`). Why: delete + recreate at the same id would reopen the bait-and-switch. Create is allowed for a future, open, guest-less meal and requests are keyed `{mealId}_{guestId}`, so a host could delete an open meal and recreate it at the same id with a different restaurant/`dateTime`/`womenOnly` while pending requests stay attached; rules can't tombstone an id. Nothing in the app deletes meals; account deletion, `postMealReminder` and any future cancel function use the Admin SDK and bypass rules, so history that matches, chat and ratings depend on can't be erased from a client either.

Interaction with the `matches` create rule: that rule reads `mealAfter.status == 'matched'` and `mealAfter.guestId`, so it still holds. The two rules now both anchor on the same request transition.

Access-call budget per approve transaction (worst case, counting every access without caching): the meals update evaluates `get(req)`, `getAfter(req)` and `existsAfter(matches)` (3 accesses with the `let` binding in `mealApprovalLink`, at most 5 without it); the requests update (the `approved` branch, see 2.2) evaluates `getAfter(meal)` and `existsAfter(matches)` (2); the matches create evaluates 4 reads (`get` and `getAfter` of the request and of the meal) plus 2 `exists` for `noBlockBetween` (6). The worst single operation is 6, under the 10 allowed per operation, and the whole approve transaction is at most 5 + 2 + 6 = 13 access calls (11 with the `let` binding; fewer distinct documents), under the 20 allowed per transaction. `deny` and the sibling-deny writes make zero access calls.

### 2.2 `requests` update guard

```
// An approve is only admitted inside the approve transaction.
function requestApprovalLinked(mealId, guestId) {
  let mealAfter = getAfter(/databases/$(database)/documents/meals/$(mealId)).data;
  return mealAfter.status == 'matched'
      && mealAfter.guestId == guestId
      && existsAfter(/databases/$(database)/documents/matches/$(mealId));
}

// requests: allow update
allow update: if isSignedIn()
              && resource.data.hostId == request.auth.uid
              && resource.data.status == 'pending'
              && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status'])
              && (request.resource.data.status == 'denied'
                  || (request.resource.data.status == 'approved'
                      && requestApprovalLinked(resource.data.mealId, resource.data.guestId)));
```

- A request can be decided exactly once (`pending -> approved|denied`). The approve transaction, `deny`, and the post-commit sibling denies all start from `pending`, so the real flows are unaffected. A host can no longer flip a decided request back and forth.
- `approved` requires the same transaction to leave the meal `matched` with this guest and create the `matches/{mealId}` doc. A bare `approved` write (no meal flip, no match) used to be allowed: the guest then got an "approved" push and a "Matched!" banner into a chat that did not exist, and with decide-once the request could never be genuinely approved again. `mealId`/`guestId` come from the stored request, whose id the create rule pins to `{mealId}_{uid}`.
- `requests` create also requires the meal to be still in the future (`get(meal).data.dateTime > request.time`): a request on a meal that has already passed is denied.

### 2.3 Ratings gate

Add to the `ratings` create rule that the meal has happened:

```
&& get(/databases/$(database)/documents/meals/$(request.resource.data.matchId)).data.dateTime <= request.time
```

(`matchId == mealId` throughout the app.) The post-meal card already appears only after `dateTime`, so the UI is consistent with the rule. Because `dateTime` is now immutable and must be in the future at creation, a host can't backdate a meal to get around the gate.

### 2.4 App change: picker lead

The create-meal date/time picker (`create_meal_screen.dart`) now rejects a pick less than `mealMinLead` (5 minutes) ahead (`isMealTimeFarEnough`) with a snackbar, instead of silently ignoring it, so it matches the server-side future-`dateTime` check. The submit path does not re-validate (see TEST-PLAN known gaps).

### 2.5 Out of scope

- Approving a request from a blocked user fails with a generic error (inbox UX). Not a rules problem; separate small app change.
- Edit/cancel meal features. If added later, they need their own explicit rule.
- Server-set `ageVerified`, moving approve into a Cloud Function.

## 3. Test harness

Several E2E seeds rely on client writes these rules forbid:

- `seedMatch` flips a meal to `matched` with the SDK as the host (now needs a genuine request). 
- Rating scenarios seed a meal with a **past** `dateTime` through the SDK (now rejected on create).

Add `adminUpdateDoc(collection, id, fields)` next to `adminSetDoc` (REST `PATCH` with `updateMask.fieldPaths` and the `Bearer owner` override, same retry/timeout convention). Seeds that need forbidden state use the admin helpers; the real flows stay covered by `request_match_test` (UI approve) and the rules cases below. `seedOpenMeal` (SDK create path) writes the same whitelisted key set as `createMeal` (`id`, `note`, `seats`, `guestId: null`, `createdAt: serverTimestamp()`), so the create rule's key/type clauses admit it. The unit tests under `test/` use the fake Firestore and are unaffected.

## 4. Tests (`integration_test/rules_enforced_test.dart`)

Real emulator uids, valid bodies, only the property under test varying, denials pinned to `permission-denied`, and each clause that can be isolated mutation-checked (delete the clause, watch its case fail, restore); two are kept as redundant defence in depth (`guestId is string` on the meals update and the link's `get(req).hostId == hostId`; see TEST-PLAN).

**meals**
- Allowed: create an open future meal **with the exact payload `createMeal` writes** (including `guestId: null`, `note: null`, `seats`, `createdAt: serverTimestamp()`; a rule that rejected the app's own create would break the product); the real approve transaction (meal + request + match; must stay green).
- Denied: update `hostId` to another uid; update `dateTime`/`restaurant`/`womenOnly`; `status: matched` with no request; `status: matched` for a request that is not pending; `guestId` that differs from the approved request's guest; `status` other than `matched`; changing any extra key alongside `status`/`guestId`; update by a non-host; a forged host (a user approving their own forged request to flip someone else's meal); the meal + request flip without the `matches` doc created in the same transaction; create with `status: matched`, with a non-null `guestId`, with a past `dateTime`; delete an open meal (and delete + recreate at the same id) and delete a matched meal; approve a request on a meal that has already passed (admin-seeded past `open` meal); create with an extra key (e.g. `postMealNotified`), a non-map `restaurant`, a non-bool `womenOnly`, a non-int `seats`, a `note` over 200 characters or a non-string `note`, or a client-set `createdAt`.

**requests**
- Denied: a host re-deciding an `approved` or `denied` request (approved→denied, denied→approved); a bare `approved` write with no meal flip and no match; `approved` while the meal is still open, matched with someone else, or matched with no match doc (admin-seeded pre-state, so each isolates one conjunct); a request on a meal that has already passed.
- Allowed: pending→denied (the app deny and the sibling-deny writes), the real approve transaction, and an `approved` write once the meal is matched with that guest and the match exists.

**ratings**
- Denied: a rating on a meal whose `dateTime` is still in the future.
- Allowed: the same rating once the meal has passed (seed the meal in the past via the admin helper).

## 5. Risks

- **Seeds and tests that write meals directly** will start failing; the plan's first task moves them to the admin helpers while the rules are unchanged, so the tree stays green.
- **`getAfter` on the request from the meals rule** relies on the same semantics the `matches` rule already proved live.
- **Scheduled `postMealReminder`** writes `status: completed` via the Admin SDK, unaffected. It must not need a client write.
- **Deploy is manual** (`firebase deploy --only firestore --project not-eat-alone`); CI skips deploy without the secret.

## 6. Delivery

Branch `feature/meal-integrity` off `develop`, subagent-driven, merged to `develop` only. Order keeps the tree green: harness (admin update helper, seeds off forbidden writes) → meals rules + cases → requests guard + ratings gate + cases → docs/changelog/final verification.
