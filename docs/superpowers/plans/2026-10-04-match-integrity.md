# Match Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `matches/{id}` doc can only be created by the real approve flow. Close the "fabricated match" hole in `firestore.rules` and prove it with live emulator tests.

**Architecture:** Tighten the `matches` create rule with a `matchApprovalValid` helper that uses `get()` (pre-state) and `getAfter()` (post-transaction state) to require that the same transaction approves a pending request and flips the meal to `matched` with that guest. Test-harness seeding that needs to bypass the new rule moves to an emulator admin REST write (`Authorization: Bearer owner`).

**Tech Stack:** Firestore security rules, `integration_test` + the Firebase emulators (`make e2e`), Flutter via FVM.

Spec: `docs/superpowers/specs/2026-10-04-match-integrity-design.md` (read it first; the rule text and the 10-case test matrix are there).

## Global Constraints

- Flutter via FVM always: `fvm flutter ...`.
- E2E runs ONLY on the dedicated simulator `Convyve E2E` (`make e2e`). Never use `iPhone 17 Pro`: another project's agent uses it.
- Only the `matches` **create** clause (+ the new helper function) changes in `firebase/firestore.rules`. Nothing else in the rules changes.
- No `lib/` changes expected. If the real approve flow is denied by the new rule, STOP and report BLOCKED with evidence; do not weaken the rule to fit.
- Do NOT run `firebase deploy`. The emulator loading the rules is the compile check. The user deploys manually.
- `fvm flutter analyze`: 0 errors/warnings, no new lints in touched files. `fvm flutter test` stays green.
- Do not commit anything under `graphify-out/` or `.superpowers/`.
- Commit trailer: the `Co-Authored-By:` line the harness specifies at that time.
- The Auth emulator mints its own uids: always use the `.uid` of the `User` returned by `signInTestUser`, never the string passed in.

---

### Task 1: Admin seeding helper + `seedMatch` rewrite (rules unchanged)

**Files:**
- Modify: `integration_test/support/emulator_admin.dart` (add `adminSetDoc` + the value encoder)
- Modify: `integration_test/support/seed.dart` (`seedMatch` writes the `matches` doc through `adminSetDoc`)

**Interfaces:**
- Produces: `Future<void> adminSetDoc(String collection, String id, Map<String, Object?> fields)` in `emulator_admin.dart`. Bypasses security rules by design; for seeding preconditions the rules forbid.
- Consumes: `kProjectId`, `kEmulatorHost`, the existing `_checkOk` / `_truncate` helpers and the retry convention in that file.
- `seedMatch({required String hostId, required String guestId, DateTime? dateTime})` keeps its signature and return value (the match id == meal id).

- [ ] **Step 1: Add the REST write helper**

In `integration_test/support/emulator_admin.dart` (reuse the file's `http` import):

```dart
/// Writes (creates or replaces) `collection/id` in the Firestore emulator via
/// the REST API with the emulator's `Authorization: Bearer owner` override,
/// which BYPASSES security rules. Use only to seed preconditions the rules
/// deliberately forbid a client from writing (e.g. a `matches` doc without
/// the approve transaction). Real flows must go through the SDK.
Future<void> adminSetDoc(
  String collection,
  String id,
  Map<String, Object?> fields,
) async {
  final res = await http.patch(
    Uri.parse(
      'http://$kEmulatorHost:8080/v1/projects/$kProjectId/'
      'databases/(default)/documents/$collection/$id',
    ),
    headers: {
      'Authorization': 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'fields': _restFields(fields)}),
  );
  _checkOk(res, 'adminSetDoc($collection/$id)');
}

Map<String, Object?> _restFields(Map<String, Object?> m) =>
    m.map((k, v) => MapEntry(k, _restValue(v)));

Object _restValue(Object? v) {
  if (v == null) return {'nullValue': null};
  if (v is bool) return {'booleanValue': v};
  if (v is int) return {'integerValue': '$v'};
  if (v is double) return {'doubleValue': v};
  if (v is String) return {'stringValue': v};
  if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
  if (v is List) {
    return {
      'arrayValue': {'values': v.map(_restValue).toList()},
    };
  }
  if (v is Map<String, Object?>) {
    return {
      'mapValue': {'fields': _restFields(v)},
    };
  }
  throw ArgumentError('adminSetDoc: unsupported value ${v.runtimeType}');
}
```

Add `import 'dart:convert';` if missing. `FieldValue.serverTimestamp()` cannot be sent over REST: use `DateTime.now()` for `createdAt`.

- [ ] **Step 2: Rewrite the match write in `seedMatch`**

Keep creating the open meal and updating it to `matched` with the SDK as the host (both legal). Replace only the `_db.collection('matches').doc(mealId).set({...})` with:

```dart
// Bypasses the `matches` create rule on purpose: since the rule requires the
// approve transaction's other writes, a bare seed write would be denied. The
// real approve path is covered by request_match_test.dart and by the
// rules_enforced_test.dart match-integrity cases.
await adminSetDoc('matches', mealId, {
  'id': mealId,
  'mealId': mealId,
  'hostId': hostId,
  'guestId': guestId,
  'participants': [hostId, guestId],
  'createdAt': DateTime.now(),
});
```

Update the dartdoc on `seedMatch` accordingly.

- [ ] **Step 3: Verify nothing changed behaviorally**

Run: `fvm flutter analyze integration_test` (clean), then the full `make e2e` once.
Expected: all existing tests PASS (24/24). `chat_test` and `rating_test` read the seeded match through the app, so they prove the REST-written doc has the right shape (`participants` array, timestamp `createdAt`).

- [ ] **Step 4: Commit**

```bash
git add integration_test/support/emulator_admin.dart integration_test/support/seed.dart
git commit -m "test(e2e): seed post-match state through an admin REST write (so the matches create rule can be tightened)"
```

---

### Task 2: Tighten the `matches` create rule + the ten rules cases

**Files:**
- Modify: `firebase/firestore.rules` (add `matchApprovalValid`, replace the `matches` create clause)
- Modify: `integration_test/rules_enforced_test.dart` (add the match-integrity group)

**Interfaces:**
- Consumes: `noBlockBetween(a, b)` (existing helper), `adminSetDoc` (Task 1), `seedOpenMeal`, `seedPendingRequest`, `seedUserProfile`, `signInTestUser`, and the file's existing `permissionDenied()` matcher and `_bootOnce`.
- Produces: the rule from spec §2.1.

- [ ] **Step 1: Write the allowed case FIRST (it must pass against the current rules too, and again after)**

In `rules_enforced_test.dart`, add a group `matches create — approval integrity`. Test 1 builds the real shape with the SDK, as two users:

```dart
// host: profile + open meal. guest: profile + pending request. host: approve.
final host = await signInTestUser(uid: 'host-mi');
await seedUserProfile(uid: host.uid);
final mealId = await seedOpenMeal(hostId: host.uid);
await signOutTestUser();
final guest = await signInTestUser(uid: 'guest-mi');
await seedUserProfile(uid: guest.uid);
final reqId = await seedPendingRequest(
    mealId: mealId, guestId: guest.uid, hostId: host.uid);
await signOutTestUser();
await signInTestUser(uid: 'host-mi'); // same claim → same Auth user; assert uid == host.uid
await db.runTransaction((txn) async {
  final mealRef = db.collection('meals').doc(mealId);
  final reqRef = db.collection('requests').doc(reqId);
  txn.update(mealRef, {'status': 'matched', 'guestId': guest.uid});
  txn.update(reqRef, {'status': 'approved'});
  txn.set(db.collection('matches').doc(mealId), {
    'id': mealId, 'mealId': mealId, 'hostId': host.uid, 'guestId': guest.uid,
    'participants': [host.uid, guest.uid],
    'createdAt': FieldValue.serverTimestamp(),
  });
});
// assert matches/{mealId} now exists
```

(Use the file's existing patterns for booting once, clearing in `setUp`, and re-signing in as an already-created user; if re-signing in as the host by claim yields a different uid, sign in once and perform the guest's request creation in the same session order the existing request tests use. Verify `.uid` equality in the test.)

Run it standalone first against the CURRENT rules. Expected: PASS.

- [ ] **Step 2: Write the nine denial cases (spec §4, tests 2–10)**

Same setup helper, one varying property per case, each asserting `permission-denied`. A small local helper that builds the host+guest+meal+request world (returns ids and uids) keeps the cases short. Cases:
2. match + meal update, NO request doc involved (guest never requested): denied.
3. request exists but the transaction omits the request→`approved` update: denied.
4. request pre-state already `approved` (seed it with `adminSetDoc('requests', reqId, {... 'status':'approved'})`), then run the approve-shaped transaction: denied. Repeat with `denied`.
5. meal pre-state already `matched`: denied.
6. host B creates a match on host A's meal using A's pending request: denied (hostId != meal host).
7. `guestId` in the match differs from the request's guest: denied.
8. `participants` disagree (e.g. `[guest, host]` order, or an extra uid), and a `guestId == hostId` case: denied.
9. match id differs from the meal id (`mealId` field == meal, doc id arbitrary): denied.
10. a block doc exists between host and guest (create it as the host with the legal `blocks/{host}_{guest}` shape): denied.

- [ ] **Step 3: Run the new group against the CURRENT rules and confirm the denial cases FAIL**

Expected: test 1 PASS, tests 2–10 FAIL (the current rule allows these). Record which fail in the report. This is the red step.

- [ ] **Step 4: Implement the rule**

In `firebase/firestore.rules` add the `matchApprovalValid(mealId, guestId, hostId)` function next to the other helpers and replace the `matches` create clause exactly as in the spec §2.1. Leave `get`/`list`/`update`/`delete` and every other collection untouched. Keep the existing explanatory comments style.

- [ ] **Step 5: Run the group again, then the whole suite**

Run: `make e2e`.
Expected: test 1 PASS (this proves `getAfter()` works inside a client transaction); tests 2–10 PASS; `request_match_test`, `chat_test`, `rating_test` and the existing rules cases PASS.

If test 1 or `request_match_test` is denied by the new rule: STOP, capture the emulator's rules-evaluation message (`firestore-debug.log` / the thrown exception), and report BLOCKED. Do not loosen the rule.

- [ ] **Step 6: Gates and commit**

`fvm flutter analyze` (0 errors/warnings), `fvm flutter test` green.

```bash
git add firebase/firestore.rules integration_test/rules_enforced_test.dart
git commit -m "fix(rules): a match can only be created by the real approve transaction (request pending→approved, meal open→matched with that guest)"
```

---

### Task 3: Docs, changelog, final verification

**Files:**
- Modify: `docs/TEST-PLAN.md` (Safety/Matching section: the match-integrity rule and its tests)
- Modify: `CHANGELOG.md` (`[Unreleased]` → `### Fixed`)
- Modify: `docs/RELEASE.md` or `docs/SECURITY.md` only if either currently documents the parked "matches create doesn't verify a request" gap (grep first; update it to "closed" with the date and rule name). If neither mentions it, leave them alone.

- [ ] **Step 1: Docs**

- `docs/TEST-PLAN.md`: add a short entry listing the ten match-integrity cases and that post-match E2E seeds use `adminSetDoc` (rules bypass by design).
- `CHANGELOG.md` under `[Unreleased]` / `### Fixed`: one line: a match can no longer be created without a real, pending, approved request (closes fabricated matches that allowed unsolicited chat and rating).

- [ ] **Step 2: Final verification**

Run once, in this order: `fvm flutter analyze`, `fvm flutter test`, `make e2e`. Expected: 0 errors/warnings; all unit tests pass; the full E2E suite passes (previous 24 + the new match-integrity cases).

- [ ] **Step 3: Commit**

```bash
git add docs CHANGELOG.md
git commit -m "docs: match-integrity rule, test coverage and changelog"
```

- [ ] **Step 4: Push and open the PR to `develop`** (the controller does this after the final review; do not push from the task).
