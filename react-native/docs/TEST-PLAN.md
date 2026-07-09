# Test Plan

The canonical checklist `qa-engineer` runs before any release. Living document — grow it as features ship.

> **Rule:** No release ships without a green run of this plan on iOS Simulator + Android Emulator + at least one real device.

---

## How to use this file

1. Per feature, add a section under § Feature checklists. Use the template below.
2. Before each release, `qa-engineer` runs every box. Any fail → file a bug via `/bug`, link the slug back here.
3. Move features from "active" to "stable" once they've passed 3 consecutive releases with no regression bugs filed.

---

## Universal edge cases (run for every release)

Failure modes that bite mobile + Firebase apps regardless of feature:

### Data + time

- [ ] Timezone math. Date-keyed data must respect local TZ, not UTC.
- [ ] Date rollover at midnight — "today" advances without manual refresh.
- [ ] DST transition — math still correct on clock-change days.
- [ ] Long strings (≥1000 chars) in text fields don't crash.
- [ ] Long lists (≥100 items) render without dropped frames.

### Network

- [ ] Offline write queues (toggle airplane mode mid-action).
- [ ] Reconnect syncs queued writes.
- [ ] Slow-3G throttle (Chrome DevTools → Network → Slow 3G) doesn't break UI.
- [ ] Firestore cache renders previously-fetched data on cold offline launch.

### Auth

- [ ] Anonymous → real-account linking preserves uid + data.
- [ ] Sign-out clears all local state (Zustand stores, query cache).
- [ ] Account deletion cascade leaves zero orphan docs.
- [ ] Token refresh works after 1h+ idle.

### Permissions

- [ ] Push notification permission denied — feature still works, nudges silently disabled.
- [ ] Camera/photo permission denied — graceful fallback.

### Lifecycle

- [ ] Cold start (after force-kill) reaches the right screen within 3s on mid-tier Android.
- [ ] Background → foreground after 10+ min doesn't crash or duplicate state.
- [ ] Deep link cold-opens app to the linked screen.

### Memory + perf

- [ ] 5 min of typical use → no obvious memory growth.
- [ ] No Firestore listener leaks (every `useEffect` calls `unsubscribe()`).

### Security

- [ ] Firestore rules deny reads of another user's data (test via Rules Playground or emulator).
- [ ] `.env` is gitignored — `git log --all -p -- .env` returns nothing.

### Visual + a11y

- [ ] Dark mode parity for every shipped screen.
- [ ] Dynamic type at 200% doesn't truncate critical text.
- [ ] Screen reader (VoiceOver / TalkBack) reaches every action.

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

## Pre-release gate (must pass — no exceptions)

Before `/release` cuts a build:

- [ ] All universal edge cases pass on iOS + Android simulator
- [ ] All feature checklists for this release pass
- [ ] Zero open P0/P1 bugs (`docs/bugs/`)
- [ ] No new console warnings introduced this release
- [ ] Real-device smoke test (NOT simulator) on at least one device per platform
- [ ] Memory + perf check (Xcode Instruments or Android Profiler) — flat memory line, no GC stalls
- [ ] Firestore rules deployed to the matching environment

---

## How to file a failure

When a checkbox doesn't pass:

1. Run `/bug <title> — <repro>` — files `docs/bugs/<YYYY-MM-DD>-<slug>.md`.
2. Link the bug slug under the relevant checklist item: `- [ ] {{step}} — see bug-<slug>`.
3. Don't uncheck other items just because one failed — keep the rest green so the team sees what *does* work.
