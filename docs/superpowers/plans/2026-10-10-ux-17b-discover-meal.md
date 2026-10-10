# UX Pass Part B, Plan 17b: Discover, Meal Detail, Create Meal and Restaurant Search

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the screens a guest spends most of the app on: Discover cards that show when and how far on one readable line and never hide under the FAB, a Discover empty/loading/notice experience that does not waste the first screen, and a meal detail whose "Request to join" action is one pinned, full-width, same-size control in every state (the owner's ask 2), with a visible rejection message. Then small create-meal and restaurant-search fixes.

**Architecture:** Presentation-layer changes in `features/meal` (+ one small confirm dialog in Settings that replaces the removed Discover sign-out shortcut). Built on the 16a/16b/17a foundations (`AppButton`, `ErrorState`, `EmptyState`, `SkeletonList`, stable router, 24 h date formats, `context.wp`). No domain, data, rules or Functions changes. French/`intl` comes in plan 19: new strings stay English, in place.

**Tech Stack:** Flutter via FVM (`fvm flutter ...`), Riverpod, go_router, `flutter_test` + `mocktail`.

Spec: `docs/superpowers/specs/2026-10-05-ux-pass-design.md` (§6). Evidence: `docs/ux/AUDIT.md` DISC-01..07, MEAL-01..09, CREATE-01..04, SEARCH-01..02, owner ask 2 (backlog B3-1..B3-6). Later-plan inputs that land here: `docs/ux/16b-verification.md`, `docs/ux/17a-verification.md` (D5 pale disabled countdown stays out; D8 large-text overflows on Discover/meal detail; D9 capture harness cannot reach create meal).

IMPORTANT, develop has moved: another session already landed on `develop` (merged into this branch before this plan was written): an "Open in Maps" outlined button on the meal-detail restaurant card (`_OpenInMapsButton`, `hasMapsLocation`, analytics `directions_opened`), the "Women only" badge stacked under the name at text scale > 1.5 (`_RestaurantHeader`, closes MEAL-05), a Contact-support row in Settings, and the Places-backed restaurant search (`searchRestaurants` callable, 400 ms debounce in `restaurant_search_screen.dart`). Read the current files first; keep all of that behaviour and its keys/tests; do not redo it.

## Global Constraints

- Flutter via FVM always. `fvm flutter analyze`: 0 errors/warnings, no new lints in touched files. `fvm flutter test` green after every task.
- Dependency rule `presentation → application → domain ← data`; Firebase imports only in `data/`. Strings English, in place. No `intl`, no new packages (no `shared_preferences`: it is not a dependency; persisting the Paris-notice dismissal is out of scope, see Task 3).
- Tokens for all colours, spacing, type, radius, sizes (`WarmPlayfulSize.actionHeight` 56, `minTap` 48, `spinner` 20, `keyboardReveal`); no magic numbers. `context.wp` for muted/dangerText; never `colorScheme.outline` as text or icon colour (a grep test enforces it).
- Accessibility: tap targets >= 48 (the Paris-notice close button must be 48), semantics for state changes (`Semantics(liveRegion: true)` for the action status line), no overflow at 320 px width and `TextScaler.linear(2.0)`, primary actions never hidden under the keyboard or off screen (the meal-detail action is PINNED, so it is always reachable).
- Keep every existing `Key` used by `integration_test/` or tests (`meal_detail_request_to_join_button`, `meal_detail_request_retry_button`, `meal_detail_restaurant_card`, `women_only_badge`, `discovery_meal_card_*`, `discovery_sign_out_button` is REMOVED in Task 3: update every test/E2E reference, grep `integration_test/` first and report; E2E signs in/out through the SDK helper).
- Skeleton/ErrorState tests: `pump(Duration)` (e.g. 1 ms), never `pumpAndSettle` while a skeleton is on screen (flutter_animate pending timer: docs/MASTER-SPEC.md gotcha 6).
- Stable router (plan 16b): do not touch `lib/core/routing/router.dart`.
- No `firestore.rules`, Cloud Functions, CI workflow changes. No firebase deploy. No new analytics events (use the existing `directions_opened` untouched).
- Do NOT run `dart format` on directories or on files you do not otherwise edit; format only new files; check `git status` shows only intended files before every commit. Do not commit anything under `graphify-out/`, `.superpowers/`, `ux_audit/out/`. Commit trailer: the `Co-Authored-By:` line the harness specifies at that time.
- Capture runs use only the simulators `Convyve E2E` and `Convyve UX Small`, never the generic `iPhone 17 Pro`.

---

### Task 1: Capture harness reaches create meal again

**Files:** Modify `ux_audit/capture_test.dart` (and `ux_audit/README.md`, one paragraph). Nothing under `lib/`.

The Places-backed search needs a `PLACES_API_KEY` secret the emulator cannot read, so nine create-meal and restaurant-search capture steps fail in every cell and `make ux-capture` exits non-zero.

- [ ] **Step 1:** Override the restaurant-search repository provider (`restaurantSearchRepositoryProvider`, see `lib/features/meal/application/restaurant_providers.dart`) inside the harness' `ProviderScope` overrides with a small fixed-list fake (the old in-memory list: 5-6 realistic Paris restaurants with address, lat/lng; searching filters by case-insensitive name contains; `'zzzz'` returns empty so the no-matches shot works; a 600 ms+ debounce wait in the harness is already covered by bounded waits: check `restaurant_search` steps still wait for the debounce). Find how `bootstrap(...)`/`pumpApp` in `ux_audit/capture_test.dart` accepts overrides; if it cannot, add the smallest seam IN THE HARNESS (never in `lib/`) and say so.
- [ ] **Step 2:** Run `make ux-capture DEVICE='Convyve E2E' OUT=17b-probe` once: it must exit 0 with all shots present (65). Note the time. If a native notification alert covers the screen (known: stuck alert, see `docs/ux/17a-verification.md`), recover with `xcrun simctl shutdown`/`boot` of "Convyve E2E" only.
- [ ] **Step 3: Commit** `fix(ux): capture harness serves restaurant search from a fixed list (Places key is not available to the emulator)`

---

### Task 2: Meal detail: one pinned action bar

**Files:**
- Modify: `lib/features/meal/presentation/meal_detail_screen.dart` (+ small new widget files under `lib/features/meal/presentation/widgets/` if the file gets unwieldy: `meal_action_bar.dart`)
- Tests: `test/features/meal/presentation/meal_detail_*_test.dart` (existing: `meal_detail_button_test.dart`, `meal_detail_open_in_maps*_test.dart`: keep them green), new `meal_action_bar_test.dart`

**Interfaces:**
- Produces a pinned action area: `Scaffold(bottomNavigationBar: SafeArea(child: Padding(all: s4, child: _MealActionBar(meal))))`. Every state is a full-width `AppButton` of height `WarmPlayfulSize.actionHeight` (56) plus an optional one-line status `Text` in `wp.muted` (live region) under it; the bar's height never changes between states (reserve the status line's height always, or give both rows fixed slots). States, in the order `_RequestAction` resolves them today:
  - own meal: tonal disabled button 'This is your meal' and status 'You'll see requests in the Requests tab.' (no Request button);
  - women-only meal and viewer not a woman: tonal disabled 'Women only' and status 'Only women can join this meal.' (`_WomenOnlyGuard`'s words);
  - request state loading: a skeleton bar (the same 56 high block) not a spinner;
  - request state error: compact `ErrorState`-style row inside the same bar height: 'Couldn't load your request' + 'Try again' (`meal_detail_request_retry_button` key kept) that invalidates `mealRequestStateProvider(meal.id)`;
  - no request: primary 'Request to join' (key `meal_detail_request_to_join_button`), loading label 'Sending request…' while `createRequestControllerProvider` is submitting;
  - pending: tonal disabled 'Requested' and status 'Waiting for the host to reply.' (use the host's first name only if it is already available in the screen without a new fetch: otherwise 'the host');
  - approved: primary 'Open chat' with a chat icon that navigates to `/chats/${meal.id}` (matchId == mealId; keep the existing route and any key/test for the matched banner's button: read `_MatchedBanner`), status 'You're matched. Say hi!';
  - denied: tonal disabled 'Not selected' and status 'The host chose someone else. Have a look at other meals.'.
- The server-rejection listener moves from `_RequestToJoinButton` to `_MealActionBar` (always mounted): when `createRequestControllerProvider` goes loading → error show a SnackBar "Couldn't send your request. Try again." (existing copy) and, for `MealNoLongerOpenException` (see `lib/features/matching/domain/meal_no_longer_open_exception.dart` or wherever it lives now), "This meal is no longer open." (MEAL-04); capture `ScaffoldMessenger` before awaiting anything; test with a controller fake that fails after a delay, and with the button unmounted/remounted by the optimistic 'Requested' state (the listener must still fire once).
- Safety menu hidden on the host's own meal (MEAL-08): `_MealSafetyActions` renders nothing (no app-bar action) when the viewer is the host.
- Remove the in-scroll `_RequestAction` and the old `_RequestedState`, `_MatchedBanner`, `_NotSelectedState`, `_WomenOnlyGuard`, `_YourMealChip` widgets once their states live in the bar (keep their Keys where tests/E2E use them: grep `integration_test/` and `test/` first and carry keys to the new widgets). The scroll body keeps: restaurant card (with Open in Maps), date line, note, host block. Add bottom padding to the scroll content so nothing hides behind the pinned bar at 2.0x text.

- [ ] **Step 1: Tests first (red).** A parametrised widget test over all states asserting: the action `AppButton` is full width and exactly `actionHeight` high; the whole bar height is identical across states (compare `tester.getSize(find.byKey(const Key('meal_action_bar')))`); label text per state; status line text and live-region semantics; disabled states are not tappable; 'Request to join' tap calls `request(meal)` once; 'Open chat' navigates (assert location `/chats/<id>`); at 320 px width and 2.0x text no overflow and the bar stays on screen with a long note and long host bio in the scroll body; rejection snackbar (both copies) fires once even after the button swapped to 'Requested'; safety menu absent for the host, present for others. Keep all existing meal-detail tests green (update expectations that located the old widgets).
- [ ] **Step 2: Implement.** Keep `AppButton` semantics from 16b; use `AnimatedSwitcher` only if it cannot change the bar's size (fixed-size container).
- [ ] **Step 3: Gates; commit** `feat(meal): pinned, same-size action bar on meal detail for every request state; rejection feedback; no safety menu on your own meal`

---

### Task 3: Discover

**Files:**
- Modify: `lib/features/meal/presentation/discovery_screen.dart`, `lib/features/meal/presentation/widgets/paris_notice.dart`, `lib/features/settings/presentation/settings_screen.dart` (sign-out confirm dialog ONLY)
- Tests: `test/features/meal/presentation/discovery_screen_test.dart` (+ edge tests that exist from the QA sweep: `discovery_*edge_test.dart`), `paris_notice_test.dart`, `test/features/settings/presentation/settings_screen_test.dart`

**Interfaces:** none new.

- [ ] **Step 1: Tests first (red).** (a) A card shows ONE meta line `formatMealDateTime(dateTime) · 1.3 km` in `wp.muted` bodySmall-or-bodyMedium (single `Text`, `maxLines: 1`, ellipsis), restaurant name `maxLines: 2` ellipsis, host row name in `Flexible` with `maxLines: 1` ellipsis (MEAL-09) → no overflow at 320 px / 2.0x with "Emilia Vasquez-Hernandez"; (b) the list has bottom padding >= `WarmPlayfulSize.actionHeight + s8` (derive from tokens) so the last card is fully visible above the FAB when scrolled to the end (scroll to the end in the test and assert the last card's bottom is above the FAB's top); (c) the Paris notice is the FIRST list item (scrolls away), dismissable in-session, close button hit area >= 48 with tooltip 'Dismiss'; persistence across sessions is OUT of scope (document in DESIGN.md: needs `shared_preferences`, decision later); (d) empty state is `EmptyState(icon, title 'No meals nearby yet', message 'Be the first: host a meal and someone will join.', action: AppButton 'Create a meal' → same route as the FAB)`; (e) the app-bar sign-out button is gone (DISC-04): remove `_onSignOut` and its test/E2E references if they are not needed elsewhere, keep Settings' sign-out; (f) Settings sign-out asks to confirm first ('Sign out?' dialog with 'Cancel' / 'Sign out', danger-free styling) and shows no spinner dialog; keep analytics `SignoutCompleted` behaviour intact (Settings has its own `_signOut`).
- [ ] **Step 2: Implement** (DISC-01..07 minus the skeleton work already done in 16b; B3-2, B3-3, B3-4 and SET-03's confirm). Use the shared widgets. Do not touch the Contact-support row another session added to Settings.
- [ ] **Step 3: Gates; commit** `feat(discover): one-line when/how-far, never hidden under the FAB, a useful empty state, a notice that scrolls away; sign-out lives in Settings with a confirm`

---

### Task 4: Create meal and restaurant search

**Files:**
- Modify: `lib/features/meal/presentation/create_meal_screen.dart`, `lib/features/meal/presentation/restaurant_search_screen.dart`, (copy of the success snackbar wherever it is fired: grep 'Meal created')
- Tests: `test/features/meal/presentation/create_meal_screen_test.dart`, `restaurant_search_screen_test.dart` (keep the all-platform variant test from the 16b fix), edge tests from the QA sweep

- [ ] **Step 1: Tests first (red).** (a) default time is the next :00 or :30 at least `mealMinLead` away (CREATE-02: not "now + 1 h to the minute"); the time picker is opened with the 24 h setting that matches the app's 24 h formatting (`MediaQuery(alwaysUse24HourFormat: true)` around the picker via `builder`); (b) the success snackbar reads "Meal posted. You'll get requests in the Requests tab." (CREATE-04 copy; no new scope); (c) no overflow at 320 px / 2.0x including the 2.2 px overflow `33_create_meal_empty` showed at xxl on the small phone (D9); the submit button reachable with the keyboard up (scrollable form + `keyboardReveal` padding on the note field); (d) restaurant search no-matches copy: `No restaurant called “<query>”. Try another name.` with the real query; the prompt state before typing stays; error state uses `ErrorState` (already) and its retry keeps re-running the typed query.
- [ ] **Step 2: Implement** (CREATE-01 is already closed by AppButton; CREATE-02, CREATE-04 copy, SEARCH-01/02).
- [ ] **Step 3: Gates; commit** `feat(meal): sensible default meal time, clearer success and no-match copy, create meal fits at large text`

---

### Task 5: Docs, verification capture, final gates

**Files:**
- Modify: `docs/DESIGN.md` (meal-detail action bar states table, Discover card anatomy, empty state, notice behaviour), `CHANGELOG.md`, `docs/TEST-PLAN.md` (new tests; manual QA: VoiceOver on the action bar status line and AppButton loading; Open in Maps still works; pinned bar with keyboard n/a)
- Create: `docs/ux/17b-verification.md`, `docs/ux/shots-17b/` (<= 8 downscaled PNGs, each < 400 KB)

- [ ] **Step 1: Docs** accurate to what shipped (widget-tested vs only seen in capture).
- [ ] **Step 2: Capture** `make ux-capture DEVICE='Convyve E2E' OUT=17b-light-default` (must now exit 0), dark (`xcrun simctl ui <udid> appearance dark`, restore light afterwards, also on failure), and the xxl small-phone cell the way `tool/ux_matrix.sh --only se3-light-xxl` does it (it restores appearance/content_size; it deletes the cell directory: copy the 17a before-shots first if you want to keep them). Only the dedicated simulators; no stray processes. View BEFORE (16b/17a captures, audit shots) vs AFTER for: `22_discover_data`, `21_discover_empty`, `23_discover_scrolled` (scroll to END if the harness can: add a `23b_discover_scrolled_end` shot to prove the FAB no longer covers the last card: DISC-03 verification), `24_discover_notice_dismissed`, `40_meal_detail_open`, `42_meal_detail_requested`, `43_meal_detail_matched`, `44_meal_detail_not_selected`, `46_meal_detail_women_only_disabled`, `48_meal_detail_own`, `49_meal_detail_request_rejected` (does the rejection snackbar now show early? capture ~1 s after the tap, MEAL-04 verification), `33`-`37` create meal shots; in se3-light-xxl check the Discover, meal-detail and create-meal overflows are gone (`ux_audit/out/logs/<cell>.findings.txt`: count UXOVERFLOW lines before/after). Write `docs/ux/17b-verification.md` (per shot what changed; remaining defects with severity and owning later plan: 18 requests/chat/ratings/settings, 19 French; the Google mark and Android auto-verification items stay open from 17a). Copy at most 8 downscaled (`sips -Z 900`, < 400 KB) AFTER shots into `docs/ux/shots-17b/`.
- [ ] **Step 3: Final verification, once, in order:** `fvm flutter analyze` (0 errors/warnings), `fvm flutter test`, the date-sensitive CI files under `TZ=Pacific/Kiritimati` and `TZ=America/Los_Angeles` (see `.github/workflows/ci.yml` ~58-65), `make e2e` (all green; the meal-detail DOM changed: E2E request/approve/match scenarios must still find the buttons by key; run in the background with a log and bounded polling; rerun once if the intermittent launch hang hits; if it fails say precisely whether it is these changes or flake).
- [ ] **Step 4: Commit** `docs: UX plan 17b (Discover, meal detail, create meal, search): design system, changelog, test plan, verification capture`
- [ ] **Step 5:** The controller pushes and opens the PR after the final review.
