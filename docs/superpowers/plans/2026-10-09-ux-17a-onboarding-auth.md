# UX Pass Part B, Plan 17a: Sign-in, Phone Code, Age Gate and Profile Setup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the first-run experience found by the audit: phone sign-in that can be finished at large text (P0), honest in-flight feedback while the SMS is on its way, a code screen with a back button, resend and auto-submit, an age gate that shows why an under-18 user is turned away, a date-of-birth picker that opens on the year, and a profile form that says what is missing and has 44 pt targets.

**Architecture:** Presentation-layer changes in `features/auth`, `features/onboarding`, `features/user` plus one small application-layer provider (the under-18 notice) and a route-extra type for the code screen. Built on the 16a/16b foundations (`AppButton`, `context.wp`, `ErrorState`, stable router, 24 h dates). No domain, data, rules or Functions changes. No `intl`/French yet (plan 19): new strings stay English, in place.

**Tech Stack:** Flutter via FVM (`fvm flutter ...`), Riverpod, go_router, `sign_in_with_apple` (already a dependency: `SignInWithAppleButton`), `flutter_test` + `mocktail`.

Spec: `docs/superpowers/specs/2026-10-05-ux-pass-design.md` (§6). Evidence: `docs/ux/AUDIT.md` SIGNIN-01..07, VERIFY-01..05, AGE-01..05, SETUP-01..05 (backlog B2-1..B2-4). Earlier plans' parked items that land here: `docs/ux/16a-verification.md`, `docs/ux/16b-verification.md` (D2 sign-in label overlap, Google/Apple 48 vs 56 height, bare sign-in phone error), 16b final review M3 (AppButton semantics focus: verify), M4.

## Global Constraints

- Flutter via FVM always. `fvm flutter analyze`: 0 errors/warnings, no new lints in touched files. `fvm flutter test` green after every task.
- Dependency rule `presentation → application → domain ← data`; Firebase imports only in `data/`. Strings stay English and in place (plan 19 extracts them once). No `intl`, no new packages.
- Tokens for all colours, spacing, type, radius, sizes (`WarmPlayfulSize.actionHeight` 56, `minTap` 48, `spinner` 20 exist); no magic numbers. Use `context.wp` for muted/dangerText; never `colorScheme.outline` as text (a grep test enforces it).
- Accessibility: tap targets >= 48 (the photo remove button 44 visual hit area is required by the audit: use 48 where space allows, never less than 44), semantics labels for icon-only controls, errors announced (`Semantics(liveRegion: true)` or `ErrorState`/`InputDecoration.errorText`), no overflow at 320 px width and `TextScaler.linear(2.0)`, primary actions never hidden under the keyboard (scrollable screens, `scrollPadding`).
- Keep every existing `Key` that `integration_test/` or tests use (`signin_phone_field`, `phone_verify_code_field`, the age-gate and profile keys: grep before editing). E2E signs in through the SDK helper, not these screens, but keys are still relied on by widget tests.
- Router is stable (plan 16b): changing a route's `extra` type touches `lib/core/routing/router.dart` builders only; do not change `authRedirect` or the listeners.
- No `firestore.rules`, Cloud Functions, CI workflow changes. No firebase deploy. No new analytics events (add to `docs/TRACKING-PLAN.md` first if one becomes necessary and stop to ask).
- Do NOT run `dart format` on directories or on files you do not otherwise edit (the SDK formatter differs from the committed style and churns ~100 files); format only new files; check `git status` shows only intended files before every commit.
- Do not commit anything under `graphify-out/`, `.superpowers/`, `ux_audit/out/`. Commit trailer: the `Co-Authored-By:` line the harness specifies at that time.
- Capture runs use only the simulators `Convyve E2E` and `Convyve UX Small`, never the generic `iPhone 17 Pro`.
- Out of scope (owner/asset needed, do not attempt): the official multi-colour Google "G" mark (SIGNIN-05, Google half): it needs an asset from Google's brand resources; list it in the verification doc as an open item.

---

### Task 1: Sign-in screen

**Files:**
- Modify: `lib/features/auth/presentation/signin_screen.dart`, `lib/core/design/widgets/app_button.dart` (optional `height` override), `lib/features/onboarding/application/` (new `underage_notice_provider.dart`, used by Task 3: create the provider here so the banner can be built now)
- Tests: `test/features/auth/presentation/signin_screen_test.dart` (extend), `test/core/design/widgets/app_button_test.dart` (height param)

**Interfaces:**
- Produces `final underageNoticeProvider = StateProvider<bool>((ref) => false);` (Riverpod `StateProvider` or the project's existing equivalent: check how other simple flags are declared) in `lib/features/onboarding/application/underage_notice_provider.dart`. Set to `true` by the age gate (Task 3) before sign-out; cleared when the sign-in screen's banner is dismissed or a sign-in starts.
- `AppButton` gains `final double? height;` (null = current per-variant default); the three sign-in buttons use `WarmPlayfulSize.actionHeight`.

- [ ] **Step 1: Tests first (red).** Cover: (a) at 320 px width and `TextScaler.linear(2.0)` the Google/Apple/Send-code buttons have no overflow and all labels fully visible (wrap, up to 2 lines); (b) "Send code" stays in its loading state until `codeSent` or `onError` fires (use a fake `AuthRepository` whose `verifyPhone` returns immediately but calls `codeSent` later; assert still loading in between, then pushes the code route with the new extra (Task 2 defines `PhoneVerifyArgs`; until then assert on `verificationId` via the current string extra and update in Task 2), and that a 60 s safety timeout clears it (use `fakeAsync`)); (c) an invalid number shows the message ON THE FIELD (`InputDecoration.errorText`: "Enter a phone number with country code, e.g. +33 6 12 34 56 78") and the field keeps it visible above the keyboard; the generic red sentence remains for non-validation errors; (d) the phone field accepts only digits, `+` and spaces and has `autofillHints: [AutofillHints.telephoneNumber]`; (e) subtitle reads "Meet one person over a meal in Paris."; (f) with `underageNoticeProvider` true a dismissible banner "You must be 18 or older to use Convyve." (muted card, close button >= 48) appears above the title, announced as a live region; dismissing sets the provider false; (g) Google/Apple/Send code are all 56 high; Apple uses the official `SignInWithAppleButton` (black in light mode, white in dark; height 56; radius `WarmPlayfulRadius.md`; label "Continue with Apple" via its `text` parameter), disabled look while another method is in flight.
- [ ] **Step 2: Implement** (SIGNIN-01..07 minus the Google mark). Phone validation: a pure function `isPlausiblePhone(String)` in `lib/core/util/` (E.164-ish: `+` then 8-15 digits after removing spaces) with its own unit test; do not call the repository when invalid. Hold `_pendingMethod` for the phone flow until `codeSent`/`onError` (clear in both, plus the 60 s timeout; cancel the timer in `dispose`). Keep analytics calls as they are.
- [ ] **Step 3: Gates; commit** `feat(auth): sign-in at large text, honest Send-code progress, inline phone error, official Apple button, under-18 notice banner`

---

### Task 2: Phone code screen

**Files:**
- Modify: `lib/features/auth/presentation/phone_verify_screen.dart`, `lib/features/auth/presentation/signin_screen.dart` (route extra), `lib/core/routing/router.dart` (`/auth/phone` builder only)
- Create: `lib/features/auth/presentation/phone_verify_args.dart`
- Tests: `test/features/auth/presentation/phone_verify_screen_test.dart` (extend), router builder covered by an existing or new small test

**Interfaces:**
- Produces `class PhoneVerifyArgs { const PhoneVerifyArgs({required this.verificationId, required this.phoneE164}); final String verificationId; final String phoneE164; }`. The sign-in screen pushes `extra: PhoneVerifyArgs(...)`; the `/auth/phone` builder reads `state.extra` safely (if it is not a `PhoneVerifyArgs`, fall back to the sign-in screen as the other builders do: no `!` casts). `PhoneVerifyScreen` takes `PhoneVerifyArgs args` instead of `String verificationId` (update every test that constructs it).

- [ ] **Step 1: Tests first (red):** (a) at 320 px and 2.0x text the screen scrolls and "Verify" is reachable with the keyboard up (`tester.view.viewInsets`), no overflow; (b) the 6th digit auto-submits once (no double submit when the field is also submitted by the keyboard); (c) `AppBar` with a back button (the screen is reachable only via push) and the line "Sent to +33 6 12 34 56 78" built from `phoneE164` with a "Change" `TextButton` that pops; (d) "Resend code" is disabled for 30 s (`fakeAsync`), then enabled, and re-calls `verifyPhone(phoneE164:)` with the same number, replacing the stored verification id for the next verify; show "Code sent again" feedback and restart the 30 s countdown (label "Resend code in 24 s" while counting); (e) a wrong code (repository throws) shows "That code didn't work. Check it or resend." in `dangerText` ON the field's `errorText` and clears the field and refocuses it; non-code errors keep the generic sentence; (f) `textInputAction: done`; loading label "Verifying…" visible and button size stable (AppButton).
- [ ] **Step 2: Implement** (VERIFY-01..05). Distinguish a wrong-code error from other errors by the repository exception type if one exists (grep `AuthRepository`/`repository_exception.dart`); if the repository maps everything to one type, treat all `confirmSmsCode` failures as "code didn't work" and note it in the report.
- [ ] **Step 3: Gates; commit** `feat(auth): phone code screen scrolls, auto-submits, can go back, change number and resend; specific wrong-code message`

---

### Task 3: Age gate

**Files:**
- Modify: `lib/features/onboarding/presentation/age_gate_screen.dart`, `lib/features/onboarding/application/age_gate_controller.dart`
- Tests: `test/features/onboarding/presentation/age_gate_screen_test.dart`, `test/features/onboarding/application/age_gate_controller_test.dart` (extend)

**Interfaces:**
- Consumes `underageNoticeProvider` (Task 1).
- The controller sets `ref.read(underageNoticeProvider.notifier).state = true` BEFORE it signs an under-18 user out (the sign-in screen, which the router sends them to, shows the banner). The in-screen `blocked` branch stays as the fallback.

- [ ] **Step 1: Tests first (red):** (a) controller: under-18 DOB sets the notice then calls `signOut` (order asserted with a mock `AuthRepository` and a provider listener), adult path unchanged and does NOT set the notice; (b) screen: scrollable, no overflow and Continue reachable at 320 px / 2.0x / keyboard n/a; (c) `showDatePicker` is opened with `initialDatePickerMode: DatePickerMode.year`, `helpText: 'Your date of birth'`, `fieldLabelText: 'Date of birth'` (assert by pumping the real picker and finding the help text; the picker's year view is visible); (d) the chosen date shows through `formatLongDate`; (e) Continue shows "Saving…" while submitting (AppButton).
- [ ] **Step 2: Implement** (AGE-01..05; AGE-01 is already closed by 16a's buttons). Use a `SingleChildScrollView` + `ConstrainedBox(minHeight: viewport)` + `IntrinsicHeight`-free centering pattern so the content stays vertically centred when it fits.
- [ ] **Step 3: Gates; commit** `feat(onboarding): age gate scrolls, picker opens on the year, under-18 users are told why on the sign-in screen`

---

### Task 4: Profile setup and form

**Files:**
- Modify: `lib/features/user/presentation/widgets/profile_form.dart` (shared with profile edit), `lib/features/onboarding/presentation/profile_setup_screen.dart`
- Tests: `test/features/user/presentation/widgets/profile_form_test.dart`, `test/features/onboarding/presentation/profile_setup_screen_test.dart`

**Interfaces:**
- `ProfileForm` exposes (via the existing `onChanged` data object or a new read-only getter on the form data class) which required fields are missing: `List<String> missingFields` (e.g. `['a photo', 'your name', 'how you identify']`), used by the setup screen; add it to the existing form-data type rather than creating a parallel one.

- [ ] **Step 1: Tests first (red):** (a) add-photo tile has a visible label "Add photo", dashed or solid `wp.muted` border, icon in `onSurface`, semantics label, and shows the busy spinner in `onSurface` while uploading; (b) every photo remove button has a >= 44 x 44 hit area, a 24 visual, `tooltip: 'Remove photo'` and a semantics label; (c) setup screen: while invalid, a helper line under Continue states what is missing ("Add a photo and pick how you identify"), hidden when valid; announced as a live region when it changes; (d) subtitle is the short copy "Name, photo and gender. That's it."; (e) text fields have `scrollPadding` so Bio and Continue come into view above the keyboard (assert via a focused field and `tester.ensureVisible`/viewInsets at 320 px and 2.0x); (f) no overflow at 320 px / 2.0x in the setup screen and the shared form (also used by profile edit: run its existing tests).
- [ ] **Step 2: Implement** (SETUP-01, 03, 04, 05; SETUP-02 is closed by the stable router: do not re-implement).
- [ ] **Step 3: Gates; commit** `feat(profile): labelled add-photo tile, 44 pt remove buttons, missing-fields hint, keyboard-safe form`

---

### Task 5: Docs, verification capture, final gates

**Files:**
- Modify: `docs/DESIGN.md` (auth/onboarding patterns: inline field errors, under-18 notice, resend countdown), `CHANGELOG.md`, `docs/TEST-PLAN.md`, `docs/TRACKING-PLAN.md` only if an event changed (none expected), `ux_audit/capture_test.dart` only if a screen's steps changed (e.g. the code screen now needs the back/resend steps)
- Create: `docs/ux/17a-verification.md`, `docs/ux/shots-17a/` (<= 8 downscaled PNGs, each < 400 KB)

- [ ] **Step 1: Docs** accurate to what shipped (widget-tested vs only seen in the capture).
- [ ] **Step 2: Capture** with `make ux-capture DEVICE='Convyve E2E' OUT=17a-light-default`, and the xxl small-phone cell the way `tool/ux_matrix.sh` does it (appearance/content_size restored afterwards, also on failure; only the dedicated simulators; no stray processes). Compare with the 16b captures for `01_signin`, `02_signin_phone_error`, `03_signin_phone_waiting`, `04_phone_verify`, `05_phone_verify_in_flight`, `06_phone_verify_error`, `10_age_gate`, `11_age_gate_picker`, `12_age_gate_under18_selected`, `14-16 profile_setup_*`, and in the xxl/SE cell the same: `06_phone_verify_error` must now exist at xxl (it could not be captured before). Write `docs/ux/17a-verification.md`: per shot what changed, remaining defects with severity and owning later plan (17b Discover/meal detail, 18, 19), the open Google-mark item, and an explicit VoiceOver note for the AppButton idle→loading semantics check (cannot be run headless: list it as a manual QA step in `docs/TEST-PLAN.md`).
- [ ] **Step 3: Final verification, once, in order:** `fvm flutter analyze`, `fvm flutter test`, `TZ=Pacific/Kiritimati` and `TZ=America/Los_Angeles` runs of the date-sensitive CI files, `make e2e` (all green; rerun once if the intermittent launch hang hits; run in the background with a log and bounded polling).
- [ ] **Step 4: Commit** `docs: UX plan 17a (sign-in, phone code, age gate, profile setup): design system, changelog, test plan, verification capture`
- [ ] **Step 5:** The controller pushes and opens the PR to `develop` after the final review.
