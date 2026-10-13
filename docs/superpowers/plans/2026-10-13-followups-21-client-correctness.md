# Follow-ups Plan 21: Client Correctness Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the five client-side follow-ups left by the UX pass: remembered Paris-notice dismissal, a post-meal rating card that never truncates its button, an honest "this meal is no longer open" on join, late (post-grace) write failures that the user can see, and a live meal-detail so a cancelled or ended meal is reflected without leaving the screen.

**Architecture:** Client-only changes under `lib/` and `test/`. No Firestore rules, indexes, Cloud Functions, CI or native-project changes (those stay manual/owner steps). Typed outcomes live in application/domain; presentation maps them to `context.l10n` strings (ARBs in `lib/l10n/`, French drafted by us, native review later via `docs/l10n/FRENCH-REVIEW.md`). The meal detail gains a live stream through the existing repository interface.

**Tech Stack:** Flutter (FVM), Riverpod 3, go_router, `shared_preferences` (already a dependency), gen_l10n (committed generated files).

## Global Constraints

- Flutter via FVM. `fvm flutter analyze`: 0 errors AND 0 warnings (CI fails on warnings), no new lints in touched files; `fvm flutter test` green after every task; no new dependencies.
- Dependency rule `presentation → application → domain ← data`; `cloud_firestore` only in `data/`; `AppLocalizations`/`context.l10n` only in presentation and core UI; application/domain return typed values, presentation localizes.
- Every new user-facing string goes in BOTH `lib/l10n/app_en.arb` and `app_fr.arb` (key with feature prefix, `@key` description, typed placeholders, ICU plural for counts), then `fvm flutter gen-l10n` and COMMIT the generated diff. gen_l10n here has `use-escaping` OFF: a literal `'` is written `'`, never `''`; French uses typographic `’`; French typography uses a non-breaking space (U+00A0) before `: ! ? ;`, inside « », and between a number and its unit; informal "tu"; terminology as in `docs/l10n/FRENCH-REVIEW.md` (tabs "Messages"/"Demandes", "Hôte", "Convive", "Entre femmes"). The ARB lint, parity and hard-coded-strings guard tests under `test/l10n/` must stay green.
- English strings that already exist are byte-identical unless the task says otherwise; existing tests pass unchanged where possible (adapt only when the task changes the asserted structure, and say so).
- The 9-state meal action bar keeps its fixed height and one-line status at 1.3x text on 320 px (see `lib/features/meal/presentation/widgets/meal_action_bar.dart`); any new state or label must pass the existing and new French/English no-overflow tests at 320 px / 2.0x.
- Analytics: no new events unless the task says so; if one is added, it goes in `docs/TRACKING-PLAN.md` first and through the typed registry in `lib/core/analytics/`. No PII.
- The 3 s `queuedWriteGrace` and offline-first behaviour are unchanged: offline writes still queue and the UI still moves on after the grace.
- E2E (`integration_test/`) runs English and finds widgets by Key; do not change existing Keys; `make e2e` must stay green (run once in Task 5's final gates).
- Do NOT run `dart format` on directories or files you do not otherwise edit; check `git status` shows only intended files before every commit; never commit `.superpowers/`, `graphify-out/`, `ux_audit/out/`. Commit trailer: the `Co-Authored-By:` line the harness specifies at that time.
- Capture runs (only Task 5 optional visual check) use only the simulators `Convyve E2E` and `Convyve UX Small`, never the generic `iPhone 17 Pro`.

---

### Task 1: Remember the Paris-notice dismissal

**Files:**
- Modify: `lib/features/meal/presentation/widgets/paris_notice.dart` (and its owner in `discovery_screen.dart` if the dismissed flag lives there), a small provider in `lib/features/meal/application/` (e.g. `paris_notice_provider.dart`), `lib/main_common.dart` only if seeding before `runApp` is the simplest way to avoid a flash
- Tests: `test/features/meal/presentation/`, `test/features/meal/application/`

**Interfaces:**
- Persist the dismissal in `SharedPreferences` under key `paris_notice_dismissed` (bool). Follow the same seeding pattern as `localeSeedProvider` in `lib/core/locale/locale_controller.dart` (read once at bootstrap, override a seed provider) so the first frame already knows the value and the notice does not flash for returning users. A `ParisNoticeController extends Notifier<bool>` (state = dismissed) with `Future<void> dismiss()` that updates state synchronously then persists in a try/catch (a failed write must not reach `PlatformDispatcher.onError` as fatal; the choice still applies for the session). Default seed (tests, E2E, harness) = not dismissed, so the existing tests and the capture harness keep seeing the notice.
- The notice stays per DEVICE (not per user), like the language choice. It never reappears after dismissal.

- [ ] **Step 1: Tests first (red):** dismiss hides the notice and persists; a fresh container seeded from `SharedPreferences.setMockInitialValues({'paris_notice_dismissed': true})` starts dismissed (no flash: first pumped frame has no notice); default shows it; a throwing write does not throw out of `dismiss()` (use a fake via the seed pattern only if possible without new dependencies, otherwise test that `dismiss` is wrapped by reading the code path with a recorded-write fake injected through a small `ParisNoticeStore` interface). Existing Discover tests unchanged.
- [ ] **Step 2: Implement; Step 3: gates; commit** `feat(meal): remember the Paris notice dismissal on this device`. Remove the "follow-up" wording from the doc comment in `paris_notice.dart`.

---

### Task 2: Post-meal rating card: Rate button never truncates

**Files:**
- Modify: `lib/features/rating/presentation/widgets/post_meal_card.dart` (+ ARB keys if the label changes)
- Tests: `test/features/rating/presentation/` (existing English card-height and one-line-title tests stay valid unless the layout change is the point; adapt only those and say so)

**Interfaces:**
- Today the Rate button reads "Rate Giulia Pe…" (EN) / "Noter Giulia Pe…" (FR) at default text size: the guest's name is inside the button label and ellipsizes. Required: the button label is short and constant ("Rate" / "Noter", with the person's name shown elsewhere in the card, e.g. in the card's title line or a subtitle) so it never truncates at 1.0x, 1.3x or 2.0x text on 320 px, in either language, with a long name ("Emilia Vasquez-Hernandez") or an apostrophe name. Accessibility: the button's semantics label still names the person ("Rate Giulia Pellegrini" / "Noter Giulia Pellegrini"): use `semanticLabel` on `AppButton` (it exists) with an ICU placeholder.
- The card keeps one primary action and the same fixed Keys; the card title/subtitle may wrap to two lines with ellipsis only for pathological names; the card must not overflow at 320 px / 2.0x.

- [ ] **Step 1: Tests first (red):** at 320 px and text scales 1.0/1.3/2.0 in en and fr with a long name and with a name containing an apostrophe: no overflow exception, the button text widget is not ellipsized (`RenderParagraph.didExceedMaxLines == false`), the button semantics label contains the name. 
- [ ] **Step 2: Implement; Step 3: gates; commit** `fix(rating): post-meal card keeps a short Rate button and names the person in the title`. Update `docs/ux/19-verification.md` follow-up table (mark fixed).

---

### Task 3: "This meal is no longer open." when joining a closed meal

**Files:**
- Modify: `lib/features/matching/data/repositories/request_repository_impl.dart` (`createRequest`), `lib/features/matching/domain/repositories/request_repository.dart` (doc), `lib/features/matching/application/create_request_controller.dart`, the meal-detail snackbar wiring in `lib/features/meal/presentation/widgets/meal_action_bar.dart` (the existing error listener), ARB only if a new string is needed (reuse `mealActionNoLongerOpen`: "This meal is no longer open.")
- Tests: `test/features/matching/`, `test/features/meal/presentation/`, `integration_test/` only if an existing E2E asserts the old generic snackbar (check; English text must stay for other failures)

**Interfaces:**
- When `createRequest` fails with a Firestore `permission-denied` (the rules reject a request for a meal that is not `open`, or the host/women-only checks), the repository inspects why with ONE follow-up read of `meals/{mealId}` (cache-first is fine; the read must tolerate offline): if the meal doc is missing or its status is not `open`, throw the existing domain `MealNoLongerOpenException(mealId)`; otherwise keep `RepositoryWriteException`. Reuses the same exception type `acceptRequest` already uses (`lib/features/matching/domain/meal_no_longer_open_exception.dart`).
- The controller keeps `AsyncError(e)` as-is; `MealActionBar`'s existing `ref.listen` on the create-request controller shows `l10n.mealActionNoLongerOpen` when the error is `MealNoLongerOpenException`, and the generic localized failure otherwise (unchanged text for other errors). The snackbar must capture `l10n` before any await (stale-closure rule).
- Women-only violations and other permission-denied cases whose meal IS open keep the generic failure.

- [ ] **Step 1: Tests first (red):** repository unit tests with the project's fake Firestore approach (look at how `request_repository_impl` is tested today; if none, use a small fake `FirebaseFirestore` seam or test the mapping function in isolation by extracting `Future<Object> _classifyFailure(mealId, error)` that takes a meal-reader callback): permission-denied + meal cancelled -> `MealNoLongerOpenException`; + meal matched -> same; + meal missing -> same; + meal open -> `RepositoryWriteException`; non-permission errors -> `RepositoryWriteException`; a failing meal read -> `RepositoryWriteException` (never masks the original). Widget test: the snackbar shows the no-longer-open text in en and fr.
- [ ] **Step 2: Implement; Step 3: gates; commit** `fix(matching): joining a closed meal says it is no longer open`.

---

### Task 4: Late write failures the user can see

**Files:**
- Modify: `lib/core/util/queued_write.dart`, the four callers (`create_request_controller.dart`, `create_meal_controller.dart`, `rating_controller.dart`, `chat_controller.dart`), `lib/core/routing/app_shell.dart` (or the root scaffold-messenger owner) for the listener, ARB keys
- Create: `lib/core/util/queued_write_failures.dart` (a Riverpod notifier/stream of typed failures)
- Tests: `test/core/util/queued_write_test.dart` (extend), shell widget test, controller tests

**Interfaces:**
- Problem: after the 3 s grace `settleOrQueue` completes normally; a rejection that arrives later (offline write replayed on reconnect and refused by rules, e.g. the meal closed meanwhile) is only `debugPrint`ed, so the user believes it succeeded.
- `settleOrQueue(write, {grace, void Function(Object error, StackTrace stack)? onLateError})`: unchanged behaviour when `onLateError` is null; when the failure arrives AFTER the grace, call `onLateError` (still log). Never calls it for failures within the grace (those still throw).
- `enum QueuedWriteKind { joinRequest, meal, rating, message }` and a keepAlive `QueuedWriteFailures` notifier exposing the latest failure as an event (kind + an incrementing id so the same kind twice still notifies). Controllers pass `onLateError: (e, s) => ref.read(queuedWriteFailuresProvider.notifier).report(kind)` (read the notifier BEFORE the await so a disposed controller can still report; the notifier is keepAlive and app-level, so it works after the screen is gone).
- Presentation: the app shell (the widget that owns the `ScaffoldMessenger` for the tabs) listens and shows a localized SnackBar per kind: joinRequest "Your join request didn't go through. Try again."; meal "Your meal wasn't posted. Try again."; rating "Your rating wasn't saved."; message "A message didn't send." (English wording is yours to polish within one short sentence; French in tu; ARBs en+fr). Rate-limit: if several failures arrive within 2 s show one snackbar. Not shown while signed out. No navigation, no actions required. Analytics: none.
- Chat messages already have per-message pending/failed UI: for `message` check `chat_controller.dart` first: if chat already surfaces a failed state for late errors, do NOT duplicate: skip `message` (remove the enum value) and say so in the report.

- [ ] **Step 1: Tests first (red):** `queued_write_test`: late rejection calls `onLateError` exactly once, in-grace rejection still throws and does not call it, success never calls it, null callback preserved behaviour; notifier emits distinct events for repeated same-kind failures; shell test: a reported failure shows the localized snackbar (en and fr), two failures within 2 s show one, none when signed out.
- [ ] **Step 2: Implement; Step 3: gates; commit** `fix(core): surface writes that fail after the offline grace`.

---

### Task 5: Live meal detail: cancelled while open, and a "Meal ended" state

**Files:**
- Modify: `lib/features/meal/domain/repositories/meal_repository.dart` (+ `watchMeal(String id)`), `lib/features/meal/data/repositories/meal_repository_impl.dart`, `lib/features/meal/application/` (a `mealStreamProvider.family<Meal?, String>`), `lib/features/meal/presentation/meal_detail_screen.dart`, `lib/features/meal/presentation/widgets/meal_action_bar.dart`, ARBs, docs (`docs/DESIGN.md` action-bar state table, `docs/TEST-PLAN.md`, `CHANGELOG.md`)
- Tests: `test/features/meal/`, `test/features/meal/presentation/`

**Interfaces:**
- Today the detail screen is built from the `Meal` passed at tap time, so a meal the host cancels (or that completes) while the guest is looking at it keeps showing the stale state. Add `Stream<Meal?> watchMeal(String id)` (Firestore `doc.snapshots()` mapped through the existing DTO mapper, `includeMetadataChanges` not needed; permission-denied/not-found emit `null`, errors propagate as stream errors). The screen watches `mealStreamProvider(id)` and uses the live meal when available, falling back to the passed meal while the first snapshot loads or on stream error (never a blank/loading regression: the passed meal renders instantly as today).
- `MealStatus.completed` gets its own terminal action-bar state "Meal ended" (disabled button or status line, same fixed bar height and one-line status rule as the other states; `Key('meal_detail_ended_button')` or the existing disabled-button pattern; copy en "This meal has ended." / fr in tu) shown for any viewer who is not the host; the host keeps the existing own-meal state. A cancelled meal keeps its existing state (cancelled wins over everything). Add the state to the action-bar state table in `docs/DESIGN.md` (now 10 states) and to the fixed-height slot computation (the label list function that sizes the bar must include the new label in both languages).
- Live updates must not rebuild-flicker: ignore snapshots equal to the current value (Meal is freezed so `==` works); dispose cleanly on screen exit.
- A meal deleted/hidden by rules emits `null`: keep showing the last known meal with its actions disabled as "no longer available" ONLY if an existing string exists ("This meal is no longer open." -> reuse `mealActionNoLongerOpen`); do not add more states.

- [ ] **Step 1: Tests first (red):** repository `watchMeal` mapping with the project's Firestore test approach (look at how `meal_repository_impl` is tested; else test through a fake `MealRepository` and the provider); screen tests with a fake repository whose stream emits open -> cancelled and open -> completed: the action bar changes live (en and fr), the passed-in meal renders before the first snapshot, a stream error keeps the passed meal; all 10 states at 320 px / 1.3x have one-line status and the same bar height (extend the existing action-bar state tests, en + fr); 320 px / 2.0x no overflow for the ended state.
- [ ] **Step 2: Implement; Step 3: gates; commit** `feat(meal): live meal detail with a Meal ended state`.
- [ ] **Step 4: Final verification once, in order:** `fvm flutter analyze` (0/0), `fvm flutter test`, the date-sensitive CI files under `TZ=Pacific/Kiritimati`, then `make e2e` in the background with a log (bounded polling; rerun once if the intermittent launch hang hits; say precisely whether a failure is these changes or flake). Update `docs/ux/19-verification.md` / `docs/ux/` follow-up list: mark fixed items (Paris-notice persistence, post-meal card, no-longer-open on join, late write failures, live meal/ended state) and leave the remaining ones (push text i18n, Android auto-verify + notification row, CI filter, native French review). Commit `docs: follow-ups plan 21: verification and follow-up list`.
- [ ] **Step 5:** The controller pushes and opens the PR after the final review.
