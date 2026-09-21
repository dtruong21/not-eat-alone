# Test Plan

The canonical checklist `qa-engineer` runs before any release. Living document — grow it as features ship.

> **Rule:** No release ships without a green run of this plan on iOS Simulator + Android Emulator + at least one real device.

---

## How to use this file

1. Per feature, add a section under § Feature checklists. Use the template below.
2. Before each release, `qa-engineer` runs every box. Any fail → file a bug via `/bug`, link the slug back here.
3. Move features from "active" to "stable" once they've passed 3 consecutive releases with no regression bugs filed.

---

## Test categories (Flutter)

The pyramid for this template — write the cheap ones first, fall back to the expensive ones only when you must.

| Category | Tool | Runs in | When to use |
|---|---|---|---|
| **Unit** | `flutter_test` | Pure Dart | Notifier logic, repositories with mocked Firestore, pure functions |
| **Widget** | `flutter_test` + `ProviderScope` test harness (`test/helpers/pump_app.dart`) | Flutter test renderer | Single screen / widget behavior, state transitions, golden path of a feature |
| **Golden** | `flutter_test` (`matchesGoldenFile`) | Flutter test renderer | Visual regressions on key screens — run on one host platform only (CI matrix pinned) |
| **Integration** | `integration_test` package | Real simulator/emulator | End-to-end golden flows (sign-in, create-first-thing, etc.) |

**Rule:** Mocks via `mocktail` only. Register fallback values for non-primitive matchers in `setUpAll`. No codegen-based mocks.

---

## Universal edge cases (run for every release)

Failure modes that bite mobile + Firebase apps regardless of feature:

### Data + time

- [ ] Timezone math. Date-keyed data must respect local TZ, not UTC.
- [ ] Date rollover at midnight — "today" advances without manual refresh.
- [ ] DST transition — math still correct on clock-change days.
- [ ] Long strings (≥1000 chars) in text fields don't crash.
- [ ] Long lists (≥100 items) render without dropped frames.
- [ ] `Timestamp` → `DateTime` conversion uses the registered `JsonConverter` everywhere (no raw `.toDate()` calls leaking into models).

### Network

- [ ] Offline write queues (toggle airplane mode mid-action).
- [ ] Reconnect syncs queued writes.
- [ ] Slow network throttle (Network Link Conditioner / Android emulator throttle) doesn't break UI.
- [ ] Firestore cache renders previously-fetched data on cold offline launch.

### Auth

- [ ] Anonymous → real-account linking preserves uid + data.
- [ ] Sign-out clears all local state (Riverpod providers invalidated, in-memory caches dropped).
- [ ] Account deletion cascade leaves zero orphan docs.
- [ ] Token refresh works after 1h+ idle.

### Permissions

- [ ] Push notification permission denied — feature still works, nudges silently disabled.
- [ ] Camera/photo permission denied — graceful fallback.

### Lifecycle

- [ ] Cold start (after force-kill) reaches the right screen within 3s on mid-tier Android.
- [ ] Background → foreground after 10+ min doesn't crash or duplicate state.
- [ ] Deep link cold-opens app to the linked screen (go_router `initialLocation` path).

### Memory + perf

- [ ] 5 min of typical use → no obvious memory growth (DevTools memory tab).
- [ ] No Firestore listener leaks — every `.snapshots()` subscription is owned by a Riverpod provider that auto-disposes.

### Security

- [ ] Firestore rules deny reads of another user's data (test via Rules Playground or emulator).
- [ ] `.env` is gitignored — `git log --all -p -- .env` returns nothing.
- [ ] No `cloud_firestore` imports outside `lib/core/firebase/` (`grep -r "package:cloud_firestore" lib/ --include="*.dart" | grep -v "lib/core/firebase"` returns nothing).

### Visual + a11y

- [ ] Dark mode parity for every shipped screen (both `ThemeMode.light` and `ThemeMode.dark`).
- [ ] Dynamic type at 200% (`MediaQueryData.textScaleFactor`) doesn't truncate critical text.
- [ ] Screen reader (VoiceOver / TalkBack) reaches every action — every interactive widget has a `Semantics` label or wraps a Material widget that provides one.

---

## Feature checklists

Add one section per shipped feature. Template:

### Feature: {{feature-name}}

Status: active | stable | retired
Related PRD entry: `docs/PRD.md § Feature: {{feature-name}}`

**Golden path:**
- [ ] {{step 1 + expected result}}
- [ ] {{step 2 + expected result}}

**Edge cases (specific to this feature):**
- [ ] {{edge case 1}}
- [ ] {{edge case 2}}

**Known issues:**
- {{link to active bug docs/bugs/<date>-<slug>.md if any}}

---

### Feature: Auth & 18+ onboarding

Status: active
Related PRD entry: `docs/PRD.md § Auth`

**Golden path:**
- [ ] Signed-out launch lands on `/auth/signin` (verified 2026-09-19, iOS Simulator, stage flavor — screen renders Google/Apple/phone, phone defaults to +33).
- [ ] Google sign-in (iOS stage) → age gate on first run → home. *(Needs a real Google account tap; not automatable — run manually.)*
- [ ] New user hits the 18+ age gate; DOB ≥ 18 → writes `users/{uid}` (ageVerified) → home; DOB < 18 → blocked message + auto sign-out.
- [ ] Returning verified user skips the age gate → straight to home.
- [ ] Sign out → returns to `/auth/signin`.
- [ ] Phone: `+33` number → "Send code" → OTP screen → verify → age gate/home. *(Needs APNs + a real SMS — pending native setup.)*

**Edge cases (specific to this feature):**
- [ ] DOB exactly 18 today = allowed; one day short = blocked (unit-tested in `age_test.dart`).
- [ ] DOB stored UTC-midnight — no timezone day-drift on read (unit-tested in `users_repository_test.dart`).
- [ ] Malformed `users` doc surfaces `RepositoryParseException`, not a raw crash.
- [ ] Non-owner cannot read/write another user's `users/{uid}` doc (Firestore rules).
- [ ] Redirect never loops across signin / age-gate / home / OTP (unit-tested in `redirect_test.dart`).

**Pending native config (blocks live tests):**
- Apple sign-in: provider + App ID capability not yet enabled.
- Phone: APNs auth key (iOS), Android SHA-256 + Play Integrity not yet registered.

**Known issues:**
- none filed

---

### Feature: Profile

Status: active
Related PRD entry: `docs/PRD.md § Profile`

**Golden path:**
- [ ] After the 18+ gate, an incomplete-profile user is forced to `/onboarding/profile` (routing unit-tested); cannot reach home or skip.
- [ ] Setup: enter displayName + pick ≥1 photo + select gender → Continue enables → profile saved (`profile_completed` fired) → router advances to home.
- [ ] Returning complete-profile user skips setup → straight to home.
- [ ] Edit (settings) → change name/bio/gender/photos → Save persists (partial merge, doesn't clobber dob/ageVerified).
- [ ] Photo upload works end-to-end (needs Storage enabled + a real image). *(Blocked until Storage bucket + rules deployed — see below.)*

**Edge cases (specific to this feature):**
- [ ] `profileComplete` = name non-blank && ≥1 photo && gender set (unit-tested).
- [ ] Photo cap: 6 max; add tile hidden/disabled at 6 (controller no-ops at ≥6).
- [ ] Remove photo updates the doc before deleting the Storage object (no dangling URL).
- [ ] DOB is not editable in the profile (age shown, derived).
- [ ] Non-owner cannot write another user's photos (Storage rules: owner-only write, signed-in read).
- [ ] Env-prefixed Storage paths (`stage/` vs `prod/`) keep flavors apart in the shared bucket.

**Pending (blocks live photo tests):**
- Firebase **Storage not yet enabled** on the project — click "Get Started" in the console, then `firebase deploy --only storage`. Until then, `upload()` I/O is unverified (only path-building + delete are unit-tested).

**Known issues:**
- none filed

---

### Feature: Meal creation

Status: active
Related PRD entry: `docs/PRD.md § Meals`

**Golden path:**
- [ ] From home, "Create a meal" → restaurant search (list) → search filters the Paris list → tap a restaurant → details.
- [ ] Details: pick a future date/time, optional note, women-only toggle → "Create meal" → a `meals/{id}` doc is written (hostId = me, status `open`, geohash set) → back to home with confirmation.
- [ ] Women-only toggle persists on the meal doc.
- [ ] Host can read/update/delete only their own meals (rules); a non-host cannot (rules-tested manually once discovery opens read in Plan 5).

**Edge cases (specific to this feature):**
- [ ] geohash computed at creation from the restaurant lat/lng (unit-tested against the canonical reference).
- [ ] Create-meal error (write fails) renders an error, does NOT fire `meal_created` (analytics only on success).
- [ ] Deep-link/restart on `/meals/new/details` with no restaurant → falls back to search (no crash).
- [ ] `seats` fixed at 1 (1:1); date/time is future-only.

**Deferred (needs the Google API key — 30-day GCP wait):**
- Real **Places API** restaurant search (currently a fake 20-restaurant Paris list behind `RestaurantSearchRepository` — swap one datasource).
- **Map preview** of the restaurant (list-first now; map added with the same keyed task).

**Known issues:**
- none filed

---

## Pre-release gate (must pass — no exceptions)

Before `/release` cuts a build:

- [ ] `flutter analyze` is clean (zero warnings)
- [ ] `flutter test` is green
- [ ] `flutter test integration_test` is green on iOS Simulator + Android Emulator
- [ ] Golden tests pass on the canonical host (no unintentional re-baselines)
- [ ] All universal edge cases pass on iOS + Android simulator
- [ ] All feature checklists for this release pass
- [ ] Zero open P0/P1 bugs (`docs/bugs/`)
- [ ] No new console warnings introduced this release
- [ ] Real-device smoke test (NOT simulator) on at least one device per platform
- [ ] Memory + perf check (DevTools — flat memory line, no jank > 16ms in steady state)
- [ ] Firestore rules deployed to the matching environment

---

## How to file a failure

When a checkbox doesn't pass:

1. Run `/bug <title> — <repro>` — files `docs/bugs/<YYYY-MM-DD>-<slug>.md`.
2. Link the bug slug under the relevant checklist item: `- [ ] {{step}} — see bug-<slug>`.
3. Don't uncheck other items just because one failed — keep the rest green so the team sees what *does* work.
