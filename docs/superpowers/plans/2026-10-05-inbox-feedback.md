# Inbox Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The host's request inbox shows which meal each request is for, marks requests whose meal has passed (Approve disabled, Deny enabled), and always gives snackbar feedback when Approve or Deny succeeds or fails.

**Architecture:** A `requestMealProvider` (cached `getMeal` per meal id) feeds a meal line and a past-meal state on `RequestInboxTile`. `InboxActionController.deny` returns its outcome like `approve` does; a pure function maps an action + outcome to a snackbar message. The tile captures `ScaffoldMessenger` and `GoRouter` before the await and uses only those afterwards.

**Tech Stack:** Flutter via FVM, Riverpod (`@riverpod` codegen where the file already uses it, manual `FutureProvider.family` otherwise), go_router, `flutter_test` + `mocktail`, and the existing `integration_test` emulator harness.

Spec: `docs/superpowers/specs/2026-10-05-inbox-feedback-design.md` (read it first: §2.3 has the exact message table).

## Global Constraints

- Flutter via FVM always: `fvm flutter ...`.
- Dependency rule `presentation → application → domain ← data`. `cloud_firestore`/`firebase_auth` imports only in a feature's `data/` layer. The application layer must NOT import Firebase types or the data layer (a prior review removed an application→data import in `inbox_action_controller.dart`; do not reintroduce one; `MealNoLongerOpenException` currently lives under `matching/data/repositories/` and the presentation tile already imports it. Keep the existing import pattern in the tile; for the pure mapping function put it in the presentation layer next to the tile so it can reference that exception, or move the exception to `matching/domain/` only if that is a trivial, fully-tested move).
- Unmount-after-await: never touch `ref` or `context` after an `await` in the tile; capture `ScaffoldMessenger.of(context)` and `GoRouter.of(context)` BEFORE the await (see the existing `_approve`). The controller keeps its `ref.keepAlive()` while an action is in flight.
- Tokens for colors/spacing/type (`lib/core/design/tokens.dart`); no magic numbers. Every `AsyncValue` consumer renders loading/error/data.
- Analytics: no new events.
- E2E runs ONLY on the dedicated simulator `Convyve E2E` (`make e2e`); never `iPhone 17 Pro`. The Auth emulator mints its own uids: use `.uid` of the `User` returned by `signInTestUser`.
- `fvm flutter analyze`: 0 errors/warnings, no new lints in touched files. `fvm flutter test` green.
- Do not run `firebase deploy`. No `firestore.rules` change in this plan.
- Do not commit anything under `graphify-out/` or `.superpowers/`.
- Commit trailer: the `Co-Authored-By:` line the harness specifies at that time.

---

### Task 1: Pure message mapping, controller `deny` outcome, `requestMealProvider`

**Files:**
- Create: `lib/features/matching/application/request_meal_provider.dart`
- Create: `lib/features/matching/presentation/widgets/inbox_action_message.dart` (pure mapping)
- Modify: `lib/features/matching/application/inbox_action_controller.dart` (`deny` returns `Future<Object?>`)
- Tests: `test/features/matching/application/request_meal_provider_test.dart`, `test/features/matching/presentation/widgets/inbox_action_message_test.dart`, and the existing controller tests in `test/features/matching/application/controllers_test.dart`

**Interfaces:**
- Produces: `final requestMealProvider = FutureProvider.family<Meal?, String>(...)`.
- Produces: `enum InboxAction { approve, deny }` and `String inboxActionMessage(InboxAction action, Object? error)` returning exactly the §2.3 texts (success when `error == null`). Plus a way for the tile to know whether to attach the Chat action (approve success only).
- Produces: `Future<Object?> deny(JoinRequest request)` returning `state.error` (like `approve`); update all callers.

- [ ] **Step 1: Tests first (red).** Message mapping: every row of the table (approve success, approve `MealNoLongerOpenException`, approve other error, deny success, deny other error). Provider: delegates to a mocked `MealRepository.getMeal` and caches per id. Controller: `deny` returns `null` on success, the error on failure; state transitions unchanged.
- [ ] **Step 2: Implement** the provider, the mapping, and the controller return type; update the tile's `_deny` caller only as far as needed to compile (the full tile UI is Task 2).
- [ ] **Step 3:** `fvm dart run build_runner build --delete-conflicting-outputs` if a generated file is involved; `fvm flutter analyze`; `fvm flutter test` (full) green.
- [ ] **Step 4: Commit** `feat(inbox): outcome message mapping, deny returns its outcome, requestMealProvider`

---

### Task 2: Tile UI: meal line, past-meal state, outcome snackbars

**Files:**
- Modify: `lib/features/matching/presentation/widgets/request_inbox_tile.dart`
- Possibly create/modify a shared date-time formatter in `lib/core/util/` (only if the existing Discover/meal-detail helper can't be reused without a layering violation)
- Tests: `test/features/matching/presentation/widgets/request_inbox_tile_test.dart` (extend), `test/features/matching/presentation/request_inbox_screen_test.dart` if its fixtures need the new provider override

**Interfaces:**
- Consumes: Task 1's provider, mapping, and `deny` outcome.
- Produces stable keys for E2E: `request_inbox_meal_line_${request.id}`, `request_inbox_past_chip_${request.id}`; the existing approve/deny button keys stay.

- [ ] **Step 1: Widget tests first (red).** Cover spec §3 widget list: meal line with restaurant + date/time on data; nothing extra on loading/error/null; past meal → chip, Approve disabled, Deny enabled; approve success snackbar with the Chat action (navigates to `/chats/{mealId}`); approve generic failure and `MealNoLongerOpenException`; deny success and failure; unmount mid-flight (tile removed while the action is in flight → no exception, snackbar still shown). Override `requestMealProvider` and the repositories with mocks as the existing tests do.
- [ ] **Step 2: Implement** the tile: watch `requestMealProvider(request.mealId)`; meal line under the guest label (restaurant name + formatted date/time, tokens for spacing/type); past-meal chip + disabled Approve; `_approve`/`_deny` capture `ScaffoldMessenger` and `GoRouter` before the await and show `inboxActionMessage(...)` afterwards; the Chat action only on approve success.
- [ ] **Step 3:** `fvm flutter analyze` (0 errors/warnings), `fvm flutter test` (full) green.
- [ ] **Step 4: Commit** `feat(inbox): show the meal on each request, mark past meals, give feedback on approve/deny`

---

### Task 3: E2E scenario

**Files:**
- Create: `integration_test/inbox_feedback_test.dart`
- Modify (only if needed): `integration_test/support/seed.dart` helpers

**Interfaces:**
- Consumes: the harness (`pumpApp`, `signInTestUser`, `seedUserProfile`, `seedOpenMeal`, `seedPendingRequest`, `adminSetDoc`, `pollUntil`, `clearEmulators`) and the tile keys from Task 2. Mirror `request_match_test.dart` / `chat_test.dart` for boot-once-per-process, image-error suppression, bounded waits.

- [ ] **Step 1:** Scenario A, past meal: seed a host, a guest, a past OPEN meal (`adminSetDoc`) and a pending request on it (`adminSetDoc`, since the rules now reject creating it); sign in as the host, open the Requests tab; assert the past chip and the disabled Approve; tap Deny; assert the "Request denied." snackbar and that the tile disappears and the request doc is `denied`.
- [ ] **Step 2:** Scenario B, future meal: a normal request through the real flow (guest requests via the SDK helper `seedPendingRequest` as the guest, as in `request_match_test`); host sees the restaurant name and date on the tile; Approve succeeds; the "Approved. You can chat now." snackbar appears; tapping Chat opens the chat screen.
- [ ] **Step 3: Verify** the new file standalone, then the full `make e2e` once (expect all existing tests plus the new ones). Rerun once if the intermittent launch hang hits.
- [ ] **Step 4: Commit** `test(e2e): inbox feedback: past-meal request is marked and clearable; approve gives feedback and opens the chat`

---

### Task 4: Docs, changelog, final verification

**Files:**
- Modify: `docs/TEST-PLAN.md` (inbox feedback section; remove or mark as fixed the Plan 13 follow-ups "inbox shows no feedback" and "hide/mark past-meal requests")
- Modify: `CHANGELOG.md` (`[Unreleased]`: `### Added` for the meal line and feedback snackbars, `### Fixed` for the swallowed errors)
- Modify: `docs/superpowers/specs/2026-10-05-inbox-feedback-design.md` (status → Implemented; text equals what shipped)

- [ ] **Step 1:** Update the docs accurately (no overclaiming: say which cases are widget-tested vs E2E).
- [ ] **Step 2: Final verification, once, in order:** `fvm flutter analyze`, `fvm flutter test`, `make e2e`. All green.
- [ ] **Step 3: Commit** `docs: inbox feedback: test plan, changelog, spec status`
- [ ] **Step 4:** Push and open the PR to `develop` (the controller does this after the final review).
