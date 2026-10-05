# Meal Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining rule gaps around meals and the request/rating lifecycle: no host reassignment, `matched` only via a genuine approve, a request decided once, and ratings only after the meal has happened.

**Architecture:** Tighten `firestore.rules` for three collections. `meals` update becomes the single approve transition tied to the request via `get`/`getAfter` (same technique as the `matches` create rule); `meals` create is pinned to an open, future, guest-less listing. `requests` update gains a pending-only guard. `ratings` create gains a meal-has-happened gate. E2E seeds that relied on now-forbidden client writes move to emulator admin REST helpers.

**Tech Stack:** Firestore security rules, `integration_test` + the Firebase emulators (`make e2e`), Flutter via FVM.

Spec: `docs/superpowers/specs/2026-10-04-meal-integrity-design.md` (read it first: the rule text, the app-payload pitfall for `guestId: null`, and the test matrix are there).

## Global Constraints

- Flutter via FVM always: `fvm flutter ...`.
- E2E runs ONLY on the dedicated simulator `Convyve E2E` (`make e2e`). Never use `iPhone 17 Pro`: another project's agent uses it.
- Rules: only the `meals`, `requests` (update) and `ratings` (create) clauses named in the spec change, plus the new helper functions. Nothing else.
- No `lib/` changes expected. If a real app flow (create meal UI path, approve, deny, rate) would be denied by a new rule, STOP and report BLOCKED with evidence; do not weaken the rule.
- The app's own create payload must be allowed: `MealRepositoryImpl.createMeal` writes `MealDto.toJson()` which includes `guestId: null`, `note: null`, `seats`, a `restaurant` map, `dateTime` as a Timestamp and `createdAt: serverTimestamp()`.
- Do NOT run `firebase deploy`. The emulator loading the rules is the compile check. The user deploys manually.
- `fvm flutter analyze`: 0 errors/warnings, no new lints in touched files. `fvm flutter test` stays green.
- Every new denial case is mutation-checked: delete the one clause it targets, confirm the case FAILS, restore, confirm green. `git diff firebase/firestore.rules` before committing must contain only the intended clauses.
- Do not commit anything under `graphify-out/` or `.superpowers/`.
- Commit trailer: the `Co-Authored-By:` line the harness specifies at that time.
- The Auth emulator mints its own uids: always use the `.uid` of the `User` returned by `signInTestUser`.

---

### Task 1: Harness: `adminUpdateDoc`, and seeds off the writes the new rules forbid (rules unchanged)

**Files:**
- Modify: `integration_test/support/emulator_admin.dart` (add `adminUpdateDoc`)
- Modify: `integration_test/support/seed.dart` (`seedMatch` flips the meal through the admin helper; past-dated meals are created through the admin helper)
- Modify: any test under `integration_test/` that creates a past-dated meal or flips a meal's status through the SDK (grep `collection('meals')` in `integration_test/`)

**Interfaces:**
- Produces: `Future<void> adminUpdateDoc(String collection, String id, Map<String, Object?> fields)` — REST `PATCH` with one `updateMask.fieldPaths=<key>` per top-level key, `Authorization: Bearer owner`, the same `_restValue` encoder, `_sendWithRetry` and 30s timeout convention as `adminSetDoc`.
- `seedOpenMeal` keeps its signature; when `dateTime` is in the past it must create the doc through `adminSetDoc` (the future create rule will reject it), otherwise through the SDK as today.
- `seedMatch` keeps its signature and return value.

- [ ] **Step 1:** Add `adminUpdateDoc` next to `adminSetDoc`, reusing the encoder and retry. Query parameters: `updateMask.fieldPaths=status&updateMask.fieldPaths=guestId` (repeat per key; keys with special characters need backtick-quoting, but ours are plain).
- [ ] **Step 2:** In `seedMatch`, replace the SDK `update({'status':'matched','guestId':...})` with `adminUpdateDoc('meals', mealId, {...})`. If the meal is past-dated (rating scenarios pass `dateTime: now - 2h`), create it via `adminSetDoc` with the same field set `seedOpenMeal` writes (Timestamps as `DateTime`). Update the dartdoc: why the bypass, and that the real approve path is covered by `request_match_test` and the rules cases.
- [ ] **Step 3:** Fix any other seed or test that writes a past-dated meal or a meal status flip through the SDK (grep first; `rules_enforced_test.dart` has a few). Assertions must not change.
- [ ] **Step 4: Verify** `fvm flutter analyze integration_test` clean, then the full `make e2e` once. Expected: everything passes (the previous 46).
- [ ] **Step 5: Commit** `test(e2e): admin update helper; seed past-dated meals and meal status flips through the admin REST write`

---

### Task 2: `meals` create/update/delete rules + cases

**Files:**
- Modify: `firebase/firestore.rules` (add `mealApprovalLink`; replace the `meals` create/update/delete clauses; keep `read`)
- Modify: `integration_test/rules_enforced_test.dart` (group `meals — integrity`)

**Interfaces:**
- Consumes: spec §2.1 verbatim (including `guestId` absent **or null** on create), the helpers from Task 1, the file's `permissionDenied()`, `buildWorld`/`approveTxn` patterns from the `matches create` group.
- Produces: the rule from spec §2.1.

- [ ] **Step 1: Write the cases first (red).** Group `meals — integrity`:
  - Allowed: (a) create with the EXACT `createMeal` payload (`guestId: null`, `note: null`, `seats`, restaurant map, Timestamp `dateTime` in the future, `createdAt: FieldValue.serverTimestamp()`, `status: 'open'`); (b) the real approve transaction (reuse the `matches create` group's allowed case; it must still pass); (c) host deletes an `open` meal.
  - Denied: host updates `hostId` to another uid; updates `dateTime`; updates `restaurant`; updates `womenOnly`; `status: 'matched'` with no request; `status: 'matched'` for a request that is already `approved`/`denied` (seed via `adminSetDoc`); `guestId` that differs from the approved request's guest; `status` set to something other than `matched` (e.g. `completed`); an extra key changed alongside `status`/`guestId`; update by a non-host; create with `status: 'matched'`; create with a non-null `guestId`; create with a past `dateTime`; delete a `matched` meal (seed matched state via the admin helpers).
  Run the group against the CURRENT rules: expect allowed cases PASS, most denial cases FAIL. Record which.
- [ ] **Step 2: Implement the rules** exactly as spec §2.1. Leave `read` unchanged.
- [ ] **Step 3: Run the group, then the full `make e2e`.** Expected: all green, including `request_match_test` (the real UI approve), `chat_test`, `rating_test`, and the existing `matches create` group. If the real approve or the exact-payload create is denied: STOP, capture the emulator's rules message, report BLOCKED.
- [ ] **Step 4: Mutation-check** each new clause that has a targeted case: `hostId`/key-whitelist (`hasOnly(['status','guestId'])`), `resource.data.status == 'open'`, `request.resource.data.status == 'matched'`, `guestId is string`, the `mealApprovalLink` request pre-state (`pending`), its `getAfter` (`approved`), create `status == 'open'`, create guest-less, create future `dateTime`, delete-only-open. Record each result in the report. Where a clause can't be isolated (redundant with another), say so.
- [ ] **Step 5: Gates and commit.** analyze, `fvm flutter test`, then:

```bash
git add firebase/firestore.rules integration_test/rules_enforced_test.dart
git commit -m "fix(rules): meals can't be reassigned or matched without a genuine approve (host/dateTime/restaurant immutable; create open+future; delete only while open)"
```

---

### Task 3: `requests` pending-only guard + ratings meal-has-happened gate

**Files:**
- Modify: `firebase/firestore.rules` (`requests` update clause; `ratings` create clause)
- Modify: `integration_test/rules_enforced_test.dart` (cases)

- [ ] **Step 1: Cases first (red).**
  - requests: denied: host re-decides an `approved` request (approved→denied) and a `denied` request (denied→approved), pre-states built with `adminSetDoc`. Allowed (existing coverage must stay green): pending→approved, pending→denied.
  - ratings: denied: a participant rates a match whose meal `dateTime` is still in the future (seed the match through the admin helpers with a future meal). Allowed: the same rating when the meal's `dateTime` is in the past (the existing `rating_test` world).
  Run against the current rules; record which fail.
- [ ] **Step 2: Implement.**
  - `requests` update: add `&& resource.data.status == 'pending'`.
  - `ratings` create: add `&& get(/databases/$(database)/documents/meals/$(request.resource.data.matchId)).data.dateTime <= request.time`.
  Nothing else in either clause changes.
- [ ] **Step 3: Run the cases, then the full `make e2e`.** `request_match_test`, `chat_test`, `rating_test` (both directions, past-dated meal) must stay green.
- [ ] **Step 4: Mutation-check** the pending-only guard and the meal-date gate (delete each, the matching case must fail, restore).
- [ ] **Step 5: Gates and commit.**

```bash
git add firebase/firestore.rules integration_test/rules_enforced_test.dart
git commit -m "fix(rules): a request can be decided once; a rating requires the meal to have happened"
```

---

### Task 4: Docs, changelog, final verification

**Files:**
- Modify: `docs/TEST-PLAN.md`, `CHANGELOG.md` (`[Unreleased]` → `### Fixed`)
- Modify: `docs/superpowers/specs/2026-10-04-meal-integrity-design.md` (status → Implemented; rule text matches what shipped)

- [ ] **Step 1:** TEST-PLAN: add the meals/requests/ratings integrity cases, stating accurately which clauses were mutation-checked and which are redundant (don't overclaim). CHANGELOG: one or two `### Fixed` lines (meals can't be reassigned or matched without a real approve; a request is decided once; ratings only after the meal).
- [ ] **Step 2: Final verification**, once, in order: `fvm flutter analyze`, `fvm flutter test`, `make e2e`. Expected: 0 errors/warnings, all unit tests pass, the full E2E suite passes.
- [ ] **Step 3: Commit** `docs: meal-integrity rules, coverage and changelog`
- [ ] **Step 4:** Push and open the PR to `develop` (the controller does this after the final review, not the task).
