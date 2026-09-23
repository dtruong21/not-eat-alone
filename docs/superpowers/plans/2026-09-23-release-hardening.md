# Release Hardening & Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Launch-ready hardening — Firebase Crashlytics + Analytics wired, App Check securing backend access, a soft Paris notice, a Settings screen (legal + account deletion + sign-out + version), drafted legal + store content, and a QA sweep. Store submission stays user homework.

**Architecture:** All-Firebase observability (no third-party keys). Analytics `track()` is made non-throwing so it's safe inside the controllers' `AsyncValue.guard`. App Check attests requests (enforcement is a later console toggle). Settings consolidates legal/account actions.

**Tech Stack:** Flutter 3.47.4 (FVM); add `firebase_crashlytics`, `firebase_app_check`, `url_launcher`, `package_info_plus`; remove `sentry_flutter`, `posthog_flutter`; `firebase_analytics` (already present); flutter_test + mocktail.

**Design spec:** `docs/superpowers/specs/2026-09-23-release-hardening-design.md`

## Global Constraints

- Always `fvm flutter` / `fvm dart`; `$HOME/.pub-cache/bin` on PATH.
- Dependency rule intact; tokens for UI; tests mirror `lib/`. `ref.watch` only in build.
- Analytics carries no PII (existing registry already complies). Crashlytics/Analytics collection OFF in debug.
- Codegen after freezed/`@riverpod`: `fvm dart run build_runner build --delete-conflicting-outputs`.
- Run `fvm flutter analyze` (clean) + `fvm flutter test` (green) before each commit.

---

## File Structure

- `pubspec.yaml`; `lib/main_common.dart` (bootstrap wiring); `lib/core/analytics/client.dart`; `lib/features/meal/presentation/discovery_screen.dart` (Paris notice); a `settings` feature (`lib/features/settings/presentation/settings_screen.dart` + a `core/config/legal_urls.dart`); `lib/features/user/presentation/profile_edit_screen.dart` (remove delete); `lib/core/routing/router.dart` (`/settings`).
- Docs: `docs/SECURITY.md`, `docs/legal/privacy.md`, `docs/store/listing.md`, `docs/RELEASE.md`, `docs/TRACKING-PLAN.md`, `docs/PRD.md`, memory, `docs/bugs/*` (if any).

---

## Task 1: Dependencies

**Files:** `pubspec.yaml`
**Interfaces:** removes sentry/posthog; adds crashlytics, app_check, url_launcher, package_info_plus.

- [ ] **Step 1: Edit `pubspec.yaml`.** Remove `sentry_flutter` + `posthog_flutter`. Add (compatible with firebase_core ^4.15 / Flutter 3.47.4): `firebase_crashlytics: ^5.x`, `firebase_app_check: ^0.4.x`, `url_launcher: ^6.x`, `package_info_plus: ^8.x` (pick versions `fvm flutter pub get` resolves; if a pin conflicts, choose the nearest resolvable).

- [ ] **Step 2: Resolve + confirm no stray refs.**

Run: `fvm flutter pub get` then grep for leftover imports: `grep -rn "sentry\|posthog" lib/` — expected: nothing (or only comments to clean).
Expected: resolves cleanly; no sentry/posthog imports remain.

- [ ] **Step 3: Commit.**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(release): swap Sentry/PostHog for Firebase Crashlytics/Analytics + add app_check/url_launcher/package_info"
```

---

## Task 2: Analytics client implementation (non-throwing)

**Files:**
- Modify: `lib/core/analytics/client.dart`
- Test: `test/core/analytics/client_test.dart`

**Interfaces:** `track`/`identify`/`reset` log via Firebase Analytics behind an injectable sink; every call is internally guarded so it never throws.

- [ ] **Step 1: Make the analytics calls go through an injectable sink** so it's testable + non-throwing. Refactor `client.dart`:
  - Add a `AnalyticsSink` seam: `typedef LogEvent = Future<void> Function(String name, Map<String, Object?> params);` with a default that calls `FirebaseAnalytics.instance.logEvent(name: name, parameters: params.map((k,v)=> MapEntry(k, v as Object)))` (drop null values). Similar seams for identify/reset, or keep those minimal.
  - `Future<void> track(AppEvent event) async { if (_shouldDropInDev) { debugPrint(...); return; } try { await _log(event.name, event.props); } catch (e, s) { debugPrint('[analytics] track failed: $e'); } }` — **the try/catch is the key change**: a failed send never throws, so the ~11 controllers calling `track` inside `AsyncValue.guard` are safe as-is.
  - Expose a `@visibleForTesting` setter to override the sink.

- [ ] **Step 2: Failing test.**

```dart
// test/core/analytics/client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';

void main() {
  test('track forwards name + props to the sink', () async {
    final calls = <(String, Map<String, Object?>)>[];
    analytics.debugSetLogSink((name, params) async => calls.add((name, params)));
    await analytics.track(const MealRated(stars: 5, showedUp: true));
    expect(calls.single.$1, 'meal_rated');
    expect(calls.single.$2['stars'], 5);
  });

  test('track never throws even if the sink fails', () async {
    analytics.debugSetLogSink((name, params) async => throw Exception('boom'));
    // must complete without throwing:
    await analytics.track(const MealRated(stars: 5, showedUp: true));
  });
}
```

(Adjust `debugSetLogSink` to whatever the seam is named; the test forces `_shouldDropInDev` false via a `debugSetForceSend(true)` seam or by running in a non-debug harness — provide a small `@visibleForTesting` override to bypass `_shouldDropInDev` so the sink is exercised.)

- [ ] **Step 3: Run to fail, implement, run to pass.**

Run: `fvm flutter test test/core/analytics/client_test.dart`

- [ ] **Step 4: Confirm TRACKING-PLAN matches the registry.** Cross-check `docs/TRACKING-PLAN.md` lists every `AppEvent` in `events.dart`; add any missing rows (no new events — just completeness).

- [ ] **Step 5: Commit.**

```bash
git add lib/core/analytics/client.dart docs/TRACKING-PLAN.md test/core/analytics/client_test.dart
git commit -m "feat(release): wire Firebase Analytics sink (non-throwing) + tracking-plan check"
```

---

## Task 3: Crashlytics + App Check wiring

**Files:**
- Modify: `lib/main_common.dart`, `docs/SECURITY.md`
- Test: n/a (plugin init — verified by compile + a guarded init; do not unit-test the plugins)

**Interfaces:** crash capture + App Check activation in the shared bootstrap, both collection-off/debug-provider in debug.

- [ ] **Step 1: Read `main_common.dart`** to see the current bootstrap (Firebase.initializeApp, dotenv, runApp). Insert after `Firebase.initializeApp`:

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
// ...
await FirebaseAppCheck.instance.activate(
  androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
);
await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

(Keep the existing `WidgetsFlutterBinding.ensureInitialized()` + dotenv load ordering; App Check + Crashlytics go after Firebase init and before `runApp`.)

- [ ] **Step 2: Update `docs/SECURITY.md`** — add: App Check attests requests (Play Integrity / DeviceCheck; debug provider in dev — register the debug token in the console); enforcement is a per-product console toggle (user homework); the public Firebase config is fine because App Check + rules gate abuse; real secrets unchanged (Admin SA, signing, OAuth). Note the iOS Crashlytics dSYM upload is a signing-workflow step (deferred).

- [ ] **Step 3: Verify build + commit.**

Run: `fvm flutter analyze` (clean) + `fvm flutter test` (green — the bootstrap change shouldn't affect tests, which don't run `main`). If quick, `fvm flutter build apk --flavor stage -t lib/main_stage.dart --debug` to confirm the native plugins link.

```bash
git add lib/main_common.dart docs/SECURITY.md
git commit -m "feat(release): Firebase Crashlytics + App Check in bootstrap"
```

---

## Task 4: Soft Paris notice

**Files:**
- Create: `lib/features/meal/presentation/widgets/paris_notice.dart`
- Modify: `lib/features/meal/presentation/discovery_screen.dart`
- Test: `test/features/meal/presentation/paris_notice_test.dart`

**Interfaces:** a dismissible "Paris-only for now" banner on the discovery feed.

- [ ] **Step 1: Failing test** — the banner renders its message; tapping dismiss hides it (a `StatefulWidget` local flag).

- [ ] **Step 2: Build `ParisNotice`** — a tokened, dismissible info banner: "Convyve is Paris-only for now — we're just getting started here." with a close icon that hides it for the session (local `bool _dismissed`). No persistence.

- [ ] **Step 3: Show it** at the top of the discovery feed (above the list), not covering the FAB/app bar. Keep discovery logic intact.

- [ ] **Step 4: Run + commit.**

```bash
fvm flutter test test/features/meal/presentation/paris_notice_test.dart
git add lib/features/meal/presentation/widgets/paris_notice.dart lib/features/meal/presentation/discovery_screen.dart test/features/meal/presentation/paris_notice_test.dart
git commit -m "feat(release): soft Paris-only notice on discovery"
```

---

## Task 5: Settings screen

**Files:**
- Create: `lib/core/config/legal_urls.dart`, `lib/features/settings/presentation/settings_screen.dart`
- Modify: `lib/core/routing/router.dart` (`/settings`), `lib/features/user/presentation/profile_edit_screen.dart` (remove the delete action + its dialog, leaving profile fields), the Profile tab entry to reach `/settings`
- Test: `test/features/settings/presentation/settings_screen_test.dart`

**Interfaces:** `SettingsScreen` at `/settings` with legal links, account deletion (moved), sign-out, version.

- [ ] **Step 1: `legal_urls.dart`** — `const privacyPolicyUrl = 'https://convyve.com/privacy';` + `const termsOfServiceUrl = 'https://convyve.com/terms';` (placeholders the user swaps).

- [ ] **Step 2: Failing test** — pump `SettingsScreen`: shows "Privacy Policy", "Terms of Service", "Delete account", "Sign out", and a version string (override `package_info` / inject the version). Tapping "Delete account" opens the confirm dialog (reuses the AccountDeletion flow). Legal rows are present (don't actually launch a URL in test).

- [ ] **Step 3: Build `SettingsScreen`** (ConsumerWidget): a `ListView` of sections —
  - **Legal**: `ListTile`s for Privacy Policy + Terms → `launchUrl(Uri.parse(...))` from `url_launcher` (in `mode: LaunchMode.externalApplication`).
  - **Account**: "Delete account" → the SAME confirm dialog + `accountDeletionControllerProvider.notifier.delete()` moved from `profile_edit_screen`; "Sign out" → the existing sign-out (unregister push token then `authRepository.signOut()`), consolidated here.
  - **About**: app version via `package_info_plus` (`PackageInfo.fromPlatform()` → "vX.Y.Z (build N)") — inject/read behind a small provider so the test can override it.
  - Tokens throughout.

- [ ] **Step 4: Route + Profile entry.** Add `GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen())` (above-shell, pushed). Add a settings gear/action on the Profile tab (`profile_edit_screen`) → `context.push('/settings')`. Remove the "Delete account" button + dialog from `profile_edit_screen` (now in Settings). If discovery has a duplicate sign-out action, leave discovery as-is or remove only if trivially safe (don't break its tests).

- [ ] **Step 5: Run + commit.**

```bash
fvm flutter test test/features/settings test/features/user
git add lib/core/config/legal_urls.dart lib/features/settings lib/core/routing/router.dart lib/features/user/presentation/profile_edit_screen.dart test/features/settings
git commit -m "feat(release): Settings screen (legal, account deletion, sign out, version)"
```

---

## Task 6: Privacy policy draft

**Files:** Create `docs/legal/privacy.md`; review `docs/legal/terms.md`.

- [ ] **Step 1: Write `docs/legal/privacy.md`** — a clearly-marked **DRAFT (needs legal review)** covering: controller identity (Convyve, contact placeholder); data collected (account/profile incl. photos + DOB, coarse location, meal/match/message content, ratings, device push tokens, analytics/crash diagnostics); purposes (matching, safety, service operation, analytics, crash diagnostics); processors (Google Firebase — Auth, Firestore, Storage, Functions, Analytics, Crashlytics, Cloud Messaging); legal bases + GDPR rights (access, deletion, portability, objection — Paris/EU); retention + account deletion (the in-app delete cascade); 18+ requirement; security (App Check, rules); international transfers; children (none <18); changes + contact. Keep it factual to what the app does.

- [ ] **Step 2: Review `docs/legal/terms.md`** — if thin, extend: 18+ eligibility, acceptable conduct, user responsibility for in-person meetups + a safety disclaimer (Convyve isn't liable for offline interactions), content ownership/licence, prohibited use, blocking/reporting, termination, no-warranty, governing law (France) — DRAFT marker.

- [ ] **Step 3: Commit.**

```bash
git add docs/legal/privacy.md docs/legal/terms.md
git commit -m "docs(release): privacy policy draft + terms review"
```

---

## Task 7: Store listing + ASO drafts

**Files:** Create `docs/store/listing.md`.

- [ ] **Step 1: Write `docs/store/listing.md`** — App Store + Play drafts:
  - Name: **Convyve**; subtitle/short (≤30/≤80 chars): e.g. "Don't eat alone" / "Meet over a meal — post a table, match 1:1, dine together."
  - Keywords (ASO, ~100 chars iOS): meal, dinner, dining, solo, restaurant, friends, meet, social, table, Paris, foodie, companion.
  - Full description: the pillar ("try a new restaurant without going alone"), the loop (post a meal → match 1:1 → chat → meet), safety (women-only meals, block/report, ratings), Paris soft-launch, 18+.
  - Category: Social (primary) / Lifestyle. Age rating: 18+.
  - Screenshot captions (5): discovery feed, meal detail, request/match, chat, ratings/safety.
  - What's-new (v1.2.0): first release.
  - A submission checklist (data-safety form topics, 18+ rating questionnaire pointers, privacy URL, support URL).
  Mark **DRAFT — refine + upload at submission**.

- [ ] **Step 2: Commit.**

```bash
git add docs/store/listing.md
git commit -m "docs(release): store listing + ASO drafts"
```

---

## Task 8: QA sweep

**Files:** `docs/TEST-PLAN.md` (check-offs / notes), `docs/bugs/*` (if findings), any code fixes for P0/P1.

- [ ] **Step 1: Static + automated sweep.** Confirm: `fvm flutter analyze` clean; `fvm flutter test` green (full suite); `npm --prefix firebase/functions run build && npm --prefix firebase/functions test` green. Grep guardrails from TEST-PLAN §Security: no `cloud_firestore` import outside `data/` layers (`grep -rn "package:cloud_firestore" lib/ | grep -v "/data/"` → only firebase_client); `.env` gitignored.
- [ ] **Step 2: Universal edge-case review.** Walk the TEST-PLAN universal checklist for statically-verifiable items: every `AsyncValue` consumer renders loading/error/data (spot-check the newer screens: settings, rating sheet/card, safety sheet, chat); no obvious Firestore listener leaks (providers auto-dispose); timezone/`Timestamp` conversions go through the mappers. Note anything that needs a real device as a manual item.
- [ ] **Step 3: File + fix.** Any code-level P0/P1 (crash, data-loss, security) → fix in this task (small) or file `docs/bugs/<date>-<slug>.md` and fix. Document the manual-device checklist (real-device smoke, offline, push delivery, deep links) as pending in TEST-PLAN for the user.
- [ ] **Step 4: Commit.**

```bash
git add docs/TEST-PLAN.md docs/bugs
git commit -m "test(release): QA sweep — static/automated pass + manual checklist"
```

(If code fixes were needed, include them + their tests in the commit or a preceding one.)

---

## Task 9: Release doc + memory

**Files:** `docs/RELEASE.md`, memory build-state, `docs/PRD.md` (Paris soft-launch note).

- [ ] **Step 1: `docs/RELEASE.md`** — a release runbook / go-live checklist: the user-homework gates (Blaze; APNs key + Android SHA; Places key; signing certs/keystore + store accounts; App Check enforcement toggle; host the legal URLs; upload store listing + screenshots; 18+ rating + data-safety forms), the CI/CD release flow (release/* → main tag → CD), and the current state (all code hardening done; observability all-Firebase).
- [ ] **Step 2: `docs/PRD.md`** — note Paris-only is a soft-launch stance (not enforced).
- [ ] **Step 3: Memory** — Plan 11 on `feature/plan-11-release`: Firebase Crashlytics + Analytics wired (Analytics track() non-throwing; Sentry/PostHog removed), App Check activated (enforcement = console homework), soft Paris notice, Settings screen (legal links + account deletion moved + sign out + version), privacy/store/ASO drafts, QA sweep done. Remaining = submission homework.
- [ ] **Step 4: Commit.**

```bash
git add docs/RELEASE.md docs/PRD.md
git commit -m "docs(release): go-live runbook + Paris soft-launch note"
```

---

## Final: verify, build, PR

- [ ] `fvm flutter analyze` clean + `fvm flutter test` green; functions build/test green.
- [ ] Build both flavors (compile-verify the new native plugins link).
- [ ] Opus whole-branch review; fix findings; re-review.
- [ ] Push `feature/plan-11-release`; open PR to **`develop`**. CI gates it.

```bash
git push -u origin feature/plan-11-release
gh pr create --base develop --title "Plan 11: release hardening (Crashlytics, Analytics, App Check, Settings, legal/store drafts)" --body "..."
```

---

## Self-Review (done at authoring)

- **Spec coverage:** observability §2 → T1/T2/T3; App Check §3 → T3; Paris §4 → T4; Settings §5 → T5; legal §6 → T6; store §7 → T7; QA §8 → T8; docs §9/§10 → T9. Covered.
- **Non-throwing analytics:** T2 makes `track()` swallow errors internally — resolves the deferred "analytics inside AsyncValue.guard" without touching the ~11 controllers.
- **Deps:** T1 removes sentry/posthog + adds crashlytics/app_check/url_launcher/package_info; T2 (analytics) uses the already-present firebase_analytics; T3 uses crashlytics+app_check; T5 uses url_launcher+package_info. Ordering: deps first.
- **No placeholders:** the testable code (analytics client + its test, Paris notice, settings) is specified with real behavior + injectable seams; wiring (Crashlytics/App Check main_common) and docs (legal/store/release) are described concretely; the QA sweep is a defined static+automated procedure with a documented manual remainder (the app can't be run live here).
```
