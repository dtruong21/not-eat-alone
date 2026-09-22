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

### Feature: Discovery

Status: active
Related PRD entry: `docs/PRD.md § Discovery`

**Golden path:**
- [ ] A fully-onboarded user lands on the **discovery feed** at `/` (replaces the placeholder home).
- [ ] The feed lists open, future meals near the user (device GPS via geolocator; **Paris-center fallback** if location denied), sorted by distance; each card shows restaurant, time, distance, host name/photo.
- [ ] Tap a meal → detail (restaurant + host profile + time/note/women-only); "Request to join" is present but **disabled** (Plan 6).
- [ ] Pull-to-refresh re-reads location + refreshes the feed. "Create a meal" FAB works.
- [ ] Seed script (`scripts/seed`, firebase-admin → **stage** DB) populates ~12 users + ~18 meals so the feed has content. `npm run wipe` cleans them.

**Edge cases (specific to this feature):**
- [ ] My own meals are excluded from the feed; past meals excluded.
- [ ] **Women-only meals hidden** from non-women viewers; visible (with badge) to women.
- [ ] Location denied/error → Paris center; feed still works.
- [ ] geohash prefix query (precision 4 ~Paris cell) + client distance sort; any signed-in user can READ meals + host profiles (rules opened; writes still owner-only).
- [ ] Empty state ("No meals near you yet") when nothing matches.

**Deferred (needs the Google API key — 30-day GCP wait):**
- **Map view** of the feed (list-first now; map added with the same keyed task as Places).

**Known issues:**
- none filed

---

### Feature: Requests & match

Status: active
Related PRD entry: `docs/PRD.md § Matching`

**Golden path:**
- [ ] From meal detail, a signed-in non-host guest taps "Request to join" → a `requests/{mealId_guestId}` doc is written (`status: pending`) → button becomes disabled "Requested" with a "Waiting for the host" hint.
- [ ] The host opens the discovery app-bar inbox (`/requests`) → sees the pending request as a tile (guest photo/name/derived age) with **Approve** and **Deny** actions.
- [ ] Host taps **Approve** → a client transaction locks the meal (`status` leaves `open`), creates a `matches/{mealId}` doc, marks this request `approved`, and denies every other pending request on the same meal ("sibling" denials) → the approved guest's meal-detail button flips to a "Matched!" banner; denied guests see "Not selected".
- [ ] A second guest who requests the now-locked meal is rejected (request creation blocked once the meal is no longer `open`).
- [ ] `matches/{mealId}` is the hand-off doc Plan 7 (chat) reads from.

**Edge cases (specific to this feature):**
- [ ] A host cannot request their own meal — meal-detail shows a "Your meal" chip instead of a request button, no request stream touched.
- [ ] Requesting a non-`open` meal (already matched/cancelled/completed) is rejected client + rules side.
- [ ] Denied requests are terminal — no re-request, no state flip back to pending.
- [ ] Approving a request whose meal raced shut (approved by a concurrent transaction first) throws `MealNoLongerOpenException`; the inbox surfaces a SnackBar ("This meal is no longer open.") instead of crashing, and does not deny/approve anything.
- [ ] Discovery app-bar inbox badge (`pendingRequestCountProvider`) shows the live pending count and hides itself at 0 (unit-tested in `discovery_inbox_badge_test.dart`).
- [ ] Women-only meals are unaffected by the request/match flow — the existing discovery-time gender filter is untouched; requests/matches carry no gender logic of their own.
- [ ] `join_requested` / `request_approved` / `request_denied` / `match_created` all fire from the controller layer (`create_request_controller.dart`, `inbox_action_controller.dart`), never inline in widgets.

**Manual rules note:**
- [ ] Firestore rules (`firebase/firestore.rules`) restrict `requests/{id}` writes to the guest (create, pending only) and the host (status transition pending→approved/denied only); `matches/{mealId}` is host/guest-readable, write-restricted to the approve transaction. Verify via Rules Playground or emulator — a non-host cannot approve/deny another host's request, and a non-participant cannot read a match doc.

**Known issues:**
- none filed

---

### Feature: Chat

Status: active
Related PRD entry: `docs/PRD.md § Chat`

**Golden path:**
- [ ] Host approves a request → guest's meal-detail "Matched!" banner is tappable → pushes `/chats/{mealId}` straight into the new chat.
- [ ] Chats tab (`/chats`) lists every match as a row (other participant photo/name, last-message preview, relative time); tapping a row opens `/chats/:matchId`.
- [ ] Chat screen: app bar shows the other participant's name/photo (looked up via `chatListProvider`); sending a message via the composer writes to `matches/{matchId}/messages` and appears immediately (mine, right-aligned).
- [ ] The other participant, viewing the same match in a second session, sees the message arrive in realtime (left-aligned) and the sender's bubble flips to "Seen" once the other participant opens the chat (`reads/{uid}.lastReadAt` compared to the message's `createdAt`).
- [ ] Bottom-nav tab switching preserves each tab's navigation stack (Chats list ↔ chat detail) independently of Discover/Requests/Profile (`StatefulShellRoute`, unit-tested in `app_shell_test.dart`).

**Edge cases (specific to this feature):**
- [ ] A signed-in user who is **not** a participant on a match cannot read its `messages`/`reads` subcollections — verify via Rules Playground or emulator (`firebase/firestore.rules`).
- [ ] Blank/whitespace-only text is blocked client-side (`ChatController.send` no-ops on blank; composer's send button stays disabled while the field is empty) and rejected repository-side (`sendMessage` throws on 0/`>2000` chars).
- [ ] Chats-tab unread dot: shown when the last message on a match is inbound (`senderId != me`); hidden once I've sent the most recent message. (Simplified heuristic — a full compare against my own `reads` doc is deferred, not required for MVP.)
- [ ] Empty states: no matches yet → "No chats yet — match on a meal to start talking"; a match with no messages yet → "Say hi 👋".
- [ ] `chat_opened` fires once per chat-screen open (guarded in `initState`, not on every rebuild); `message_sent` fires only after a successful write.
- [ ] Route guard: `/chats/:matchId` with a missing/blank `matchId` falls back to the chat list instead of crashing on a null path param.

**Manual rules note:**
- [ ] `matches/{matchId}/messages/{id}` and `matches/{matchId}/reads/{uid}` are readable/writable only by `match.hostId`/`match.guestId` (participants array) — verify a third user is denied both read and write via emulator.

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
