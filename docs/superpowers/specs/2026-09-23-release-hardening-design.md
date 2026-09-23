# Convyve — Release Hardening & Store Design (Plan 11)

**Date:** 2026-09-23
**Status:** Approved (design), pending implementation plan
**Feature:** The final pre-launch pass — all-Firebase observability (Crashlytics + Analytics), App Check to secure backend access, a soft Paris-only notice, a Settings screen (legal links + account deletion + sign-out + version), drafted legal + store/ASO content, and a QA sweep. Store submission itself stays as user homework.

---

## 1. Goal & constraints

Get the app launch-ready: crashes reported, analytics flowing, backend access attested, legal reachable in-app, a clean settings home, and a QA pass — while producing the drafts (privacy policy, store listing/ASO) the user reviews before submitting. The actual submission (signed builds, store-console config, 18+ rating, listing upload) needs the user's signing assets + store accounts + the Blaze plan, and stays deferred. Observability standardizes on Firebase (no third-party keys to secure), which also answers "secure my keys."

## 2. Observability — all Firebase

### Crashlytics

- Add `firebase_crashlytics`. In `main_common.dart` (the shared bootstrap), after `Firebase.initializeApp`:
  - `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;`
  - `PlatformDispatcher.instance.onError = (error, stack) { FirebaseCrashlytics.instance.recordError(error, stack, fatal: true); return true; };`
  - `await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);` (off in debug).
- iOS needs the Crashlytics run-script/dSYM upload build phase (documented as a native setup note; the Flutter plugin handles most). Android is automatic via the Firebase gradle plugin.

### Analytics (implement the skeleton)

- `lib/core/analytics/client.dart` currently no-ops. Implement `track`/`identify`/`reset` over `firebase_analytics` (already a dependency): `track(event)` → `FirebaseAnalytics.instance.logEvent(name: event.name, parameters: event.props.cast<String, Object>())`; `identify(uid, props)` → `setUserId(id: uid)` + `setUserProperty` per field; `reset()` → `setUserId(id: null)`.
- Keep the existing `_shouldDropInDev` guard (debug still prints, doesn't send unless `ANALYTICS_IN_DEV`).
- **Resolve the deferred "analytics inside `AsyncValue.guard`" concern by making `track()` never throw**: wrap the `logEvent` call in try/catch inside `client.dart` (a failed analytics call must never fail a successful write). This is cleaner than restructuring the ~11 controllers that call `track` inside a guard — they stay as-is, now safely.
- Firebase Analytics event-name/param constraints (≤40-char snake_case names; String/num param values) — our typed registry already complies (names are `noun_verb`, props are scalars). Note it.

### Dependency cleanup

- Remove the now-unused `sentry_flutter` + `posthog_flutter` from `pubspec.yaml` (they were scaffolding for the deferred choice; we standardized on Firebase). Remove any stray references.

## 3. App Check — secure backend access ("secure my keys")

The Firebase config shipped in the app is public by design (SECURITY.md); **App Check** is what actually stops that config being used from outside the genuine app.

- Add `firebase_app_check`. After `Firebase.initializeApp` (before `runApp`): `await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.playIntegrity, appleProvider: AppleProvider.deviceCheck)`. For debug builds use the debug providers (`AndroidProvider.debug` / `AppleProvider.debug`) gated on `kDebugMode` so local dev/CI works without Play Integrity.
- **Enforcement is a console toggle (user homework):** the client attaches App Check tokens now; the user enables enforcement per Firebase product (Firestore, Storage, Functions, Auth) in the console when ready, after registering the debug token + the Play Integrity / DeviceCheck app attestations. Documented in `docs/SECURITY.md`.
- Update `docs/SECURITY.md`: the secret model — `firebase_options`/`google-services` are public + App-Check-gated; real secrets stay the Admin service account + signing keys + OAuth secrets (unchanged); `.env` holds no secrets currently (analytics/crash are keyless via Firebase). This is the "keys are secured" story.

## 4. Soft Paris gating

- Discovery is already Paris-scoped (geohash precision 3 + Paris-center fallback). Add a soft, dismissible notice on the discovery feed: "Convyve is Paris-only for now — we're just getting started here." A small info banner (tokened), dismissible for the session (a local flag; no persistence needed). No hard location block.
- Note in `docs/PRD.md`/PRINCIPLES that Paris-only is a soft-launch stance, not enforced.

## 5. Settings screen

- New route `/settings` reachable from the Profile tab (a gear action or a "Settings" list entry). A `settings` feature (or under `user/presentation`) with `SettingsScreen`:
  - **Legal**: "Privacy Policy" + "Terms of Service" rows opening the hosted URLs via `url_launcher` (add the dep). URLs are constants (placeholder `https://convyve.com/privacy` + `/terms`) the user swaps for the real hosts.
  - **Account**: "Delete account" — **moved here** from `profile_edit_screen` (the same confirm-dialog + `AccountDeletionController` flow); and "Sign out".
  - **About**: app version + build (via `package_info_plus`, add the dep) — "Convyve vX.Y.Z (build N)".
- Keep `profile_edit_screen` focused on profile fields; the delete action leaves it (Settings owns destructive/account actions). Sign-out consolidates here too (remove the ad-hoc sign-out from discovery if it duplicates — keep one home).

## 6. Legal content (drafts)

- `docs/legal/privacy.md` — a privacy-policy draft covering: what data is collected (profile, photos, location coarse, messages, ratings, device tokens), how it's used (matching, safety, analytics/crash via Firebase), third parties (Google/Firebase), retention + account deletion, 18+ requirement, contact, GDPR (EU/Paris) rights. Clearly marked **DRAFT — needs legal review**.
- `docs/legal/terms.md` already exists — review/extend if thin (age 18+, conduct, no-liability for meetups, safety disclaimer, account termination).
- These are drafts for the user's legal sign-off; hosting them (at the URLs Settings links) is user homework.

## 7. Store metadata + ASO (drafts)

- `docs/store/listing.md` — App Store + Play listing drafts: app name (Convyve), subtitle/short description, keywords (ASO — "meal, dinner, friends, dining, solo, restaurant, meet, social dining, Paris"), full description, category (Social/Lifestyle), age rating 18+, screenshot captions (discovery, meal detail, chat, ratings, safety), what's-new. A launch checklist. Drafts for the user to refine + upload.
- Use the `aso` skill's guidance for keyword/positioning if helpful; keep it a doc.

## 8. QA sweep

- Run the full `docs/TEST-PLAN.md` checklist against the current codebase (the `qa-engineer` path / `qa-sweep`). File any P0/P1 as `docs/bugs/*`; the QA gate blocks release on open P0/P1. Given the app can't be run live here (no signed build/device), the sweep is the automated + static portions (unit/widget suite green, analyze clean, rules review, the universal edge-case checklist as far as statically verifiable), plus a documented manual-device checklist for the user. Fix any code-level P0/P1 found.

## 9. Analytics/tracking-plan

- No new events (Plan 11 wires the sink, not new tracking). Confirm `docs/TRACKING-PLAN.md` matches the typed registry (every `AppEvent` present) as part of the sweep.

## 10. Non-goals (deferred — user homework / later)

- Signed release builds + the mobile signing workflow (needs certs/keystore).
- Store-console configuration: 18+ age rating, data-safety/privacy questionnaires, listing + screenshot upload, actual submission.
- Enabling App Check **enforcement** in the console (client is ready; enforcement is a toggle after attestation setup).
- Blaze upgrade (Functions), APNs key + Android SHA (sign-in + push delivery), Places API key (real restaurants + maps) — standing homework.
- Hard Paris geo-blocking; multi-city.
- iOS Crashlytics dSYM upload automation (documented note; wired in the signing workflow later).

## 11. Delivery

Own plan on branch `feature/plan-11-release` (off `develop`), executed subagent-driven. Ordered so the tree stays green: deps (remove sentry/posthog, add crashlytics/app_check/url_launcher/package_info) → Crashlytics wiring → Analytics client impl (non-throwing) → App Check wiring + SECURITY.md → Paris soft notice → Settings screen (+ move account deletion, url_launcher legal links, version) → legal privacy draft → store/ASO drafts → QA sweep (+ TRACKING-PLAN check, fix code P0/P1) → docs (RELEASE checklist, memory) + verify/build/PR to `develop`.
