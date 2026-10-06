# UX Pass Part B, Plan 16b: Shared Widgets, Router Stability, Paris Date Formats

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the app one consistent loading / error / empty pattern and a button that shows progress visibly, stop the router from resetting navigation whenever the user's own profile changes, and show dates and times the way a Paris user reads them (24 h, day before month, "Today / Tomorrow").

**Architecture:** Four new widgets in `lib/core/design/widgets/` (`AppButton`, `ErrorState`, `EmptyState`, `SkeletonCard`) built only from theme tokens; the 9 button sites that use the stop-gap `loadingFilledStyle` move to `AppButton`, the 5 feed screens adopt `ErrorState`/skeletons; `routerProvider` builds one `GoRouter` and feeds the three redirect booleans through a `refreshListenable`; `core/util/date_format.dart` keeps its three public functions but changes what they print (dependency-free, English; plan 19 swaps in `intl` and French).

**Tech Stack:** Flutter via FVM (`fvm flutter ...`), Riverpod, go_router, `flutter_animate` (already a dependency, used for the skeleton shimmer), `flutter_test` + `mocktail`.

Spec: `docs/superpowers/specs/2026-10-05-ux-pass-design.md` (§6). Evidence and findings: `docs/ux/AUDIT.md` X-03, X-06, X-07, X-09, X-12, X-13 (dates), backlog B1-5, B1-9, B1-10; deferred review items: `.superpowers/sdd/2026-10-06-ux-16a-tokens-buttons-font/final-review.md` (items 9, 10, 11, 16).

## Global Constraints

- Flutter via FVM always. `fvm flutter analyze`: 0 errors/warnings, no new lints in touched files. `fvm flutter test` green after every task.
- Dependency rule `presentation → application → domain ← data`; widgets in `lib/core/design/widgets/` import only Flutter, the design tokens/theme and `flutter_animate`. No Firebase imports outside `data/`. Strings stay in English and in place (plan 19 extracts them once); no new `intl` or `flutter_localizations` dependency in this plan.
- Tokens for all colours, spacing, type, radius, sizes; no magic numbers (`WarmPlayfulSize.actionHeight` = 56 and `.minTap` = 48 exist; add new tokens first).
- Accessibility: every new widget has a semantics label where its visual is not text; loading is announced (`Semantics(liveRegion: true)` on the changed label); tap targets >= 48; respects `MediaQuery.disableAnimations` and large text (test at 320 px width and `TextScaler.linear(2.0)`).
- Every `AsyncValue` consumer keeps rendering loading / error / data.
- No `firestore.rules`, Cloud Functions, CI workflow changes. Do not run `firebase deploy`. No new analytics events.
- Existing E2E (`integration_test/`) locates widgets by key and text: do not change existing keys. E2E that print dates (`inbox_feedback_test.dart:165,235` use `formatMealDateTime(when)` itself, so they follow the formatter) must stay green; any E2E that hard-codes the old format must be updated. `make e2e` runs once at the end.
- Do NOT run `dart format` on directories or on files you do not otherwise edit (the SDK formatter differs from the committed style and churns ~100 files); format only new files, check `git status` shows only intended files before every commit.
- Do not commit anything under `graphify-out/`, `.superpowers/`, `ux_audit/out/`. Commit trailer: the `Co-Authored-By:` line the harness specifies at that time.
- Capture runs use only the simulators `Convyve E2E` and `Convyve UX Small`, never the generic `iPhone 17 Pro`.

---

### Task 1: Shared test helper and `AppButton`; retire `loadingFilledStyle`

**Files:**
- Create: `lib/core/design/widgets/app_button.dart`, `test/support/contrast.dart`, `test/core/design/widgets/app_button_test.dart`
- Modify: `lib/core/design/theme.dart` (delete `loadingFilledStyle`), the 9 call sites (`rating_sheet.dart:158`, `signin_screen.dart:263`, `phone_verify_screen.dart:125`, `profile_edit_screen.dart:94`, `report_sheet.dart:159`, `meal_detail_screen.dart:404`, `create_meal_screen.dart:242`, `age_gate_screen.dart:182`, `profile_setup_screen.dart:97`), the 6 tests that copy the contrast helper (`grep -rln "double contrast(" test`) to import `test/support/contrast.dart`

**Interfaces:**
- Produces:
  ```dart
  enum AppButtonVariant { primary, tonal, outlined, text }

  class AppButton extends StatelessWidget {
    const AppButton({
      required this.label,
      required this.onPressed,
      this.variant = AppButtonVariant.primary,
      this.isLoading = false,
      this.loadingLabel,
      this.icon,
      this.expand = true,
      super.key,
    });
    final String label;
    final VoidCallback? onPressed;   // null = disabled
    final AppButtonVariant variant;
    final bool isLoading;            // taps ignored, spinner in the foreground colour beside the label
    final String? loadingLabel;      // e.g. 'Sending…'; defaults to label
    final Widget? icon;
    final bool expand;               // full width (primary page CTAs); height = WarmPlayfulSize.actionHeight for primary/tonal, minTap otherwise
  }
  ```
- Behaviour: while `isLoading` the button keeps its ENABLED colours (not the grey disabled fill), `onPressed` is swallowed (no tap-through; `Semantics(button: true, enabled: false)` plus a live-region label `loadingLabel ?? label`), a 20 px (`WarmPlayfulSize` token to add: `spinner = 20`) `CircularProgressIndicator(strokeWidth: 2, color: foreground)` shows beside the label, and the button's size never changes between idle and loading (the label keeps its width: use a `Row` with `mainAxisSize` min and a fixed spinner slot, or an `IndexedStack`-style stable size). It builds the right Material button (`FilledButton`, `FilledButton.tonal`, `OutlinedButton`, `TextButton`) so the theme from plan 16a applies unchanged.
- `test/support/contrast.dart` exports `double contrast(Color a, Color b)` (WCAG; the copy that exists in `test/core/design/contrast_test.dart`).

- [ ] **Step 1: Tests first (red).** `app_button_test.dart`, both brightnesses: idle primary has fill `scheme.primary`, label `onPrimary`, height >= 56 and full width at 320 px; loading shows a `CircularProgressIndicator` whose colour contrasts >= 3:1 with the fill, the fill is still `scheme.primary` (not the disabled fill), `onPressed` is never called on tap while loading (count calls), `tester.getSize(find.byType(AppButton))` identical idle vs loading; `onPressed: null` renders disabled (fill `wp.border`, label `wp.subtle`); loading label is exposed via `SemanticsController`/`tester.getSemantics` as a live region; each variant renders and meets >= 48 high; at `TextScaler.linear(2.0)` and 320 px there is no overflow (label wraps or ellipsizes: choose `maxLines: 2`).
- [ ] **Step 2: Implement `AppButton`** and the `spinner` size token. Delete `loadingFilledStyle` and its comment from `theme.dart`.
- [ ] **Step 3: Migrate the 9 sites** to `AppButton(label:, loadingLabel:, isLoading:, onPressed:)`. Primary page CTAs (Send code, Verify, Continue x2, Create meal, Save) use the default `expand: true`; Submit in the report and rating sheets and "Request to join" the same. Keep every existing `Key`, label text, and the guard that suppresses the handler while submitting. Remove per-site `SizedBox(height: …)` wrappers that only forced button height. If a site's existing widget test finds `FilledButton` by type, keep it working (AppButton builds a `FilledButton` for primary) or move to the key.
- [ ] **Step 4: Share the contrast helper:** move the copy-pasted `contrast` function into `test/support/contrast.dart` and import it in the 6 test files; drop the redundant `>= 3.0` assertion in `contrast_test.dart` that the 4.5 check already covers, and the test that only asserts a literal.
- [ ] **Step 5: Gates** (analyze, full test). **Commit** `feat(design): shared AppButton with visible, size-stable loading; retire the loadingFilledStyle stop-gap`

---

### Task 2: `ErrorState`, `EmptyState`, `SkeletonCard`; adopt in the feeds

**Files:**
- Create: `lib/core/design/widgets/error_state.dart`, `empty_state.dart`, `skeleton_card.dart`, `test/core/design/widgets/{error_state,empty_state,skeleton_card}_test.dart`
- Modify (adoption): `lib/features/meal/presentation/discovery_screen.dart` (~123-131), `lib/features/matching/presentation/request_inbox_screen.dart` (~48-56), `lib/features/chat/presentation/chat_list_screen.dart` (~30-47), `lib/features/chat/presentation/chat_screen.dart` (~160-175), `lib/features/meal/presentation/restaurant_search_screen.dart` (~75-90), and the existing tests of those screens that look for the old spinner or the old error sentence

**Interfaces:**
- Produces:
  ```dart
  class ErrorState extends StatelessWidget {
    const ErrorState({required this.onRetry, this.title = "Couldn't load this", this.message = 'Check your connection and try again.', super.key});
    final VoidCallback onRetry; final String title; final String message;
  }  // icon Icons.cloud_off_rounded (wp.muted), title titleMedium, body wp.muted, AppButton tonal 'Try again'; centered, scrollable at 2.0x text
  class EmptyState extends StatelessWidget {
    const EmptyState({required this.title, this.message, this.icon, this.action, super.key});
  }  // icon in wp.muted, title titleMedium, optional body, optional AppButton
  class SkeletonCard extends StatelessWidget {
    const SkeletonCard({this.lines = 3, this.showAvatar = true, super.key});
  }  // card-shaped (radius lg, WarmPlayfulElevation.card, surface fill) with wp.border blocks; shimmer via flutter_animate .shimmer(duration: 1200 ms) looping; static (no controller running) when MediaQuery.disableAnimations
  ```
  plus `class SkeletonList extends StatelessWidget { const SkeletonList({this.count = 3, super.key}); }` (a non-scrolling `Column`/`ListView` of `SkeletonCard`s with the list's real padding).
- Adoption rule: `loading:` → `SkeletonList` (Discover, Requests, Chats, restaurant search) or a message-shaped skeleton (chat); `error:` → `ErrorState(onRetry: () => ref.invalidate(<the provider that screen watches>))`; the empty copy sites that currently use `wp.muted` text (`No meals near you yet`, `No pending requests`, empty chats, `Say hi 👋`) → `EmptyState` with the same words (copy changes belong to plans 17/18). Do not change keys.

- [ ] **Step 1: Widget tests first (red)** for the three widgets: `ErrorState` shows title, message and a 'Try again' button that calls `onRetry` once and is >= 48 high; at 320 px and 2.0x text no overflow; semantic label present. `SkeletonCard` renders with `disableAnimations: true` and with animations (use `pump(Duration)` not `pumpAndSettle`; the shimmer loops forever, like any spinner: tests of screens in loading state must not `pumpAndSettle`); its colours use `wp.border`/surface in both modes. `EmptyState` with and without action.
- [ ] **Step 2: Implement** the three widgets and `SkeletonList`; add any new tokens first (block heights, skeleton radius) to `tokens.dart`.
- [ ] **Step 3: Adopt in the five screens** per the rule; keep every `AsyncValue` branch. Update screen tests: loading finds `SkeletonList`/`SkeletonCard` (not `CircularProgressIndicator`), error finds `ErrorState` and tapping 'Try again' re-fetches (override the provider with a mock that fails once, then succeeds, and assert the data appears). Check `integration_test/` for finders of the old spinner/error text (`grep -rn "CircularProgressIndicator\|Something went wrong" integration_test`) and update only if needed; E2E must keep waiting by key/text, never `pumpAndSettle` while a skeleton is on screen.
- [ ] **Step 4: Gates; commit** `feat(design): shared ErrorState, EmptyState and SkeletonCard; feeds show skeletons and a retry on error`

---

### Task 3: One router, stable across profile changes

**Files:**
- Modify: `lib/core/routing/router.dart`
- Create: `test/core/routing/router_stability_test.dart`
- Keep: `authRedirect` (pure function) and `test/core/routing/redirect_test.dart` unchanged

**Interfaces:**
- Consumes: `authStateProvider` (`StreamProvider<AuthUser?>`), `currentUserDocProvider` (`StreamProvider<AppUser?>`).
- Produces: `routerProvider` that builds ONE `GoRouter` per provider lifetime. A `ValueNotifier<int>` (or a small private `ChangeNotifier`) is passed as `refreshListenable`; it is bumped by `ref.listen` on three SELECTED values only: `signedIn` (`authStateProvider.select((a) => a.value != null)`), `ageVerified` and `profileComplete` (`currentUserDocProvider.select((u) => u.value?.ageVerified ?? false)` etc.). `redirect:` reads the current values with `ref.read` at call time. `ref.onDispose` disposes the notifier and the router.

- [ ] **Step 1: Tests first (red)** in `router_stability_test.dart` with a `ProviderContainer` (override the two stream providers with controllable `StreamController`s): (a) the `GoRouter` instance is identical after the user document emits a change that touches no redirect input (e.g. new `photoUrls`, name, bio): `identical(c.read(routerProvider), first)`; (b) a change of `ageVerified` or `profileComplete` or sign-out DOES re-run redirect (assert `router.routerDelegate.currentConfiguration.uri` moves to `/onboarding/age`, `/onboarding/profile`, `/auth/signin` respectively); (c) a widget test mounting `MaterialApp.router` on the stable router: navigate to `/meals/detail` (with a `Meal` extra) or another pushed page, emit a user doc change that touches only the photo, and assert the same page is still on screen with its state (e.g. a `TextField` keeps its text).
- [ ] **Step 2: Implement** as in Interfaces; delete the doc-comment claims that the router is rebuilt on auth changes and replace with the new contract. Keep the `loading` behaviour of `ageVerified` (false while the doc is loading; the `authRedirect` guards already cover it).
- [ ] **Step 3: Gates** (analyze, full test; `redirect_test.dart` untouched and green). **Commit** `fix(routing): build the router once so profile writes no longer reset navigation (refreshListenable on the three redirect inputs)`

---

### Task 4: Dates and times for Paris

**Files:**
- Modify: `lib/core/util/date_format.dart`, `lib/features/onboarding/presentation/age_gate_screen.dart` (~25-43, its private month table), `test/core/util/date_format_test.dart`, widget tests that assert the old strings (`grep -rn "PM\|AM'\| at \|October\|1/5" test`), `integration_test/` only if a test hard-codes the old format
- Docs: `docs/ux/AUDIT.md` untouched (history); changelog in Task 5

**Interfaces:**
- Produces (same function names and signatures plus an optional clock for tests):
  - `String formatMealDateTime(DateTime value, {DateTime? now})` → relative when near: `Today 20:30`, `Tomorrow 12:30`; otherwise `Sat 10 Oct, 20:00` (weekday abbreviation, day, month abbreviation, 24 h time; year appended only when it differs from `now`'s year: `Sat 10 Oct 2027, 20:00`). Local time via `toLocal()` as today; "today/tomorrow" computed on local calendar days of `value.toLocal()` vs `(now ?? DateTime.now()).toLocal()`.
  - `String formatClockTime(DateTime value)` → 24 h `20:30`.
  - `String formatMonthDay(DateTime value)` → `5 Jan` (day, month abbreviation) in local time.
  - `String formatLongDate(DateTime value)` → `5 January 2027` for the age gate's date of birth; replaces the private month table there (keep one month-name table in `date_format.dart`).
- English, dependency-free (no `intl`): plan 19 replaces the internals with `DateFormat` and the locale.

- [ ] **Step 1: Tests first (red)** in `date_format_test.dart` (keep both test groups the CI already runs: the file is run twice, once normally and once with `TZ=Pacific/Kiritimati` in `.github/workflows/ci.yml`; keep the hard-literal group that only runs under that zone and extend it): today/tomorrow/other-day/other-year cases with a fixed `now`, local-day boundaries (an instant that is "tomorrow" in UTC+14 but "today" in UTC: assert the LOCAL answer using the same independent derivation as the existing tests, not `toLocal()` of the implementation), midnight and 00:05 (24 h `00:05`), noon, `formatMonthDay` and `formatLongDate`. Run the file under `TZ=UTC` and `TZ=Pacific/Kiritimati` (`TZ=… fvm flutter test test/core/util/date_format_test.dart`): the tests must fail without `toLocal()` under Kiritimati (mutation-check once by removing it and say so in the report).
- [ ] **Step 2: Implement** the formatters and the age-gate change. Update every widget test that asserted the old text to derive its expectation from the formatter's documented output (literal strings with a fixed `now`/time zone where the test controls it) rather than calling the same formatter on both sides where that would be tautological.
- [ ] **Step 3: Gates** (analyze, full test; also run the date test under Kiritimati as CI does). **Commit** `feat(ui): 24-hour times, day-before-month dates and Today/Tomorrow labels (dependency-free; intl and French come with plan 19)`

---

### Task 5: Docs, verification capture, final gates

**Files:**
- Modify: `docs/DESIGN.md` (components: AppButton variants and loading, ErrorState, EmptyState, SkeletonCard; date/time formats; router contract), `CHANGELOG.md` (`[Unreleased]` Added/Changed/Fixed), `docs/TEST-PLAN.md` (new tests; the two skeleton/loading caveats for E2E), `docs/ux/16b-verification.md` (new), nav icon `size: 24` literal in `lib/core/design/theme.dart` (~278) → a token (`WarmPlayfulSize.icon`) with the existing icon theme value
- Create: `docs/ux/shots-16b/` (at most 8 downscaled PNGs, < 400 KB each)

- [ ] **Step 1: Docs** accurate to what shipped (say which behaviours are widget-tested vs E2E vs only seen in the capture).
- [ ] **Step 2: Capture** with `make ux-capture DEVICE='Convyve E2E' OUT=16b-light-default` and, after `xcrun simctl ui <udid> appearance dark` (restore light afterwards, including on failure), `OUT=16b-dark-default`. View AFTER vs the 16a captures (`ux_audit/out/16a-light-default/`) for: Discover loading (`20_discover_loading`: skeleton), Discover data (relative dates), requests/chats, `93_discover_error` and the other feed error shots (ErrorState with Try again), `05_phone_verify_in_flight`, `37_create_meal_in_flight`, `70_chat_report_in_flight`, `75_rating_sheet_in_flight` (visible spinner, same button size), the chat times. Write `docs/ux/16b-verification.md` per shot: what changed, remaining defects with severity and the later plan (17 onboarding+Discover+meal detail, 18 requests/chat/ratings/settings, 19 French) that owns each. Confirm by navigation in a capture step or an existing capture note that editing the profile photo no longer resets the stack (the harness README lists the old behaviour).
- [ ] **Step 3: Final verification, once, in order:** `fvm flutter analyze` (0 errors/warnings), `fvm flutter test`, `TZ=Pacific/Kiritimati fvm flutter test test/core/util/date_format_test.dart`, `make e2e` (all green; rerun once if the intermittent launch hang hits; run in the background with a log and bounded polling).
- [ ] **Step 4: Commit** `docs: UX plan 16b (shared widgets, router, dates): design system, changelog, test plan, verification capture`
- [ ] **Step 5:** The controller pushes and opens the PR to `develop` after the final review.
