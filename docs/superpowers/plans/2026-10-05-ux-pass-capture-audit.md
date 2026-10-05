# UX Pass, Part A: Capture Harness and Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Photograph every screen state of the real app on the iOS Simulator (light/dark, two phone sizes, default and large text) with realistic seeded data, then produce a ranked UX audit (`docs/ux/AUDIT.md`) that becomes Part B's fix plan.

**Architecture:** A capture test (`ux_audit/capture_test.dart`, outside `integration_test/` so CI never runs it) boots the real app on the Firebase emulators with the existing harness, seeds a rich world through the admin REST helpers, drives to each screen state and, at each, hands off to the host by writing `/tmp/convyve-ux/<name>.ready`; a host script (`tool/ux_capture.sh`) takes `xcrun simctl io <device> screenshot` and writes `<name>.ack`. A local HTTP server on `127.0.0.1` serves generated avatar images. The audit is written by the `ux-designer` agent from the screenshots, `docs/DESIGN.md`, and the code.

**Tech Stack:** Flutter via FVM, `integration_test` + Firebase emulators (existing harness in `integration_test/support/`), `xcrun simctl`, Python 3 stdlib (image generation, `http.server`), bash.

Spec: `docs/superpowers/specs/2026-10-05-ux-pass-design.md`.

## Global Constraints

- Flutter via FVM always (`fvm flutter ...`). Never use the `iPhone 17 Pro` simulator by that name for capture: use the dedicated `Convyve E2E` simulator (and a second small-phone simulator created for this plan, named `Convyve UX Small`); another project's agent uses the generic one.
- The capture harness is NOT part of CI and not under `integration_test/`. `make e2e` and CI are untouched, and must stay green.
- No changes to `lib/`, `firestore.rules`, or CI in Part A. If the capture needs an app-side hook, STOP and report instead of adding it.
- Output images go to `ux_audit/out/` and are gitignored; only the harness, the scripts, `docs/ux/AUDIT.md` and a small set of referenced audit screenshots under `docs/ux/shots/` are committed (keep each PNG under ~400 KB; downscale if needed).
- The Auth emulator mints its own uids: always use the `.uid` of the `User` returned by `signInTestUser`.
- `fvm flutter analyze`: 0 errors/warnings, no new lints in new Dart files. `fvm flutter test` green.
- Do not run `firebase deploy`. Don't commit anything under `graphify-out/` or `.superpowers/`.
- Commit trailer: the `Co-Authored-By:` line the harness specifies at that time.

---

### Task 1: Capture harness + proof on four screens

**Files:**
- Create: `ux_audit/capture_test.dart`, `ux_audit/support/world.dart` (the seeded world), `ux_audit/support/handoff.dart` (the ready/ack handshake), `tool/ux_capture.sh` (host loop), `tool/ux_images.py` (avatar generator + `http.server` launcher)
- Modify: `Makefile` (a `ux-capture` target), `.gitignore` (`ux_audit/out/`)

**Interfaces:**
- Produces: `Future<void> shot(String name)` in `handoff.dart`: writes `/tmp/convyve-ux/<name>.ready`, waits (bounded, ~30 s) for `<name>.ack`, deletes both.
- Produces: `seedWorld()` returning the ids the capture needs (host/guest uids, meal ids, match id).
- Consumes: `integration_test/support/{app_harness,auth,seed,emulator_admin}.dart`.

- [ ] **Step 1: Feasibility probe (before building anything else).** Prove the handshake works: a minimal test running on the `Convyve E2E` simulator writes `/tmp/convyve-ux/probe.ready` and the host takes a screenshot with `xcrun simctl io booted screenshot /tmp/convyve-ux/probe.png`. Confirm the simulator app can write to the host's `/tmp` and that a real Nunito font renders (not the fallback). If the app cannot write to `/tmp`, find a host-visible path that works (e.g. the simulator's data container via `xcrun simctl get_app_container`) and use that instead; document the finding.
- [ ] **Step 2: Avatars.** `tool/ux_images.py` generates N placeholder avatars (distinct gradient backgrounds with initials; pure stdlib PNG writing, 512x512) into `ux_audit/out/avatars/` and serves them on `http://127.0.0.1:8765/`. Seed `photoUrls` with those URLs. Verify an avatar renders in the app (iOS ATS allows IP-address hosts; if it does not, report).
- [ ] **Step 3: The seeded world** (`world.dart`): about 8 users (varied names, ages, bios, gender, photos, rating aggregates, profile-complete) and about 10 meals (future times from tonight to next week; varied Paris restaurants with long and short names; one women-only; one own meal for the signed-in user; notes of varied length); requests in several states (pending from two guests on the viewer's meal; one on a past meal; one approved with a match); one match with a chat of about 15 realistic messages (short, long, multi-line, a seen marker, timestamps spread over days); a rating; a block. Write with the admin REST helpers where the rules forbid a client write (past meals, matches, decided requests).
- [ ] **Step 4: Capture four screens** as the proof: sign-in (signed out), Discover (data), meal detail (open meal by another host), chat (the seeded match). Use the existing `signInTestUser`/`pumpApp` patterns, bounded waits, and `shot('01_signin')` etc.
- [ ] **Step 5: Host script and Makefile.** `tool/ux_capture.sh <device-name> <out-subdir>` boots/uses the named simulator, starts the image server, loops watching `/tmp/convyve-ux/*.ready`, takes a screenshot into `ux_audit/out/<out-subdir>/<name>.png`, writes `.ack`, and exits when the test process ends. `make ux-capture DEVICE='Convyve E2E' OUT=iphone17-light-default` runs the emulators with `firebase emulators:exec` (same flags as `make e2e`), the host script, and `fvm flutter drive --driver ux_audit/driver.dart --target ux_audit/capture_test.dart -d "$(DEVICE)"` together (drive, not `flutter test`: flutter_tools only runs a test on a device when it is under `integration_test/`), and cleans up stray processes.
- [ ] **Step 6: Run it** for the four screens; look at the four PNGs (Read tool) and confirm they show real content (photos, text in Nunito), not blanks or the fallback font. Include the four images in the report.
- [ ] **Step 7: Commit** `feat(ux): screenshot capture harness (real app on the simulator, handoff to simctl) with a seeded world`

---

### Task 2: All screens and states, and the capture matrix

**Files:**
- Modify: `ux_audit/capture_test.dart` (+ `ux_audit/support/*`), `tool/ux_capture.sh`, `Makefile`
- Create: `tool/ux_matrix.sh` (runs the whole matrix), `ux_audit/README.md` (how to run; what each shot name means)

- [ ] **Step 1: Cover every screen and state** in the spec §2.1 list, named `NN_screen_state` (zero-padded so they sort in flow order). Reach states through the real UI wherever practical and through seed changes otherwise (e.g. empty Discover by signing in as a user in a far-away location; the loading state by capturing at the first frame; the error state through a seeded condition or a provider override only if the UI can't reach it, documenting each such case). Under-18 age gate, location-denied banner, and the Paris notice need the matching simulator permission/privacy state: reuse the Makefile's `ios-privacy` step and document what each run assumes.
- [ ] **Step 2: The matrix script.** `tool/ux_matrix.sh` creates the small-phone simulator `Convyve UX Small` if missing (iPhone SE class; use the same device-type/runtime discovery as the Makefile's boot step), then runs `make ux-capture` for: {iPhone 17 Pro, small phone} × {light, dark} × {default text, a large accessibility text size}, switching `xcrun simctl ui <device> appearance light|dark` and `content_size` between runs, and restoring defaults at the end. Output: `ux_audit/out/<device>-<theme>-<size>/NN_*.png`.
- [ ] **Step 3: Run the full matrix once.** Verify the file counts per directory are equal, no screen is blank (check each PNG's size is above a threshold and spot-check ten by viewing them), and note anything that couldn't be captured and why in the README.
- [ ] **Step 4: Commit** `feat(ux): capture every screen state across the device/theme/text-size matrix`

---

### Task 3: The audit

**Files:**
- Create: `docs/ux/AUDIT.md`, `docs/ux/shots/` (the referenced screenshots only, downscaled)

This task is performed by the `ux-designer` agent type with the screenshots, not by an implementation agent.

- [ ] **Step 1: Inputs.** The agent reads `docs/DESIGN.md`, `docs/design-mood.svg`, `lib/core/design/{tokens,theme}.dart`, and for each screen its presentation file, and views the screenshots under `ux_audit/out/` (all four matrix directories for the screens that differ, and at least the default light capture for every screen).
- [ ] **Step 2: Output `docs/ux/AUDIT.md`** with: (a) a summary table (screen, P0/P1/P2 counts); (b) per screen: what works, findings (id, severity, evidence = screenshot path, cause in code with file:line where known, proposed fix, effort S/M/L); (c) cross-cutting findings (contrast measured numerically from the actual colours, tap targets, the `outline`-as-text and same-surface-button issues with a count and the list of places, type scale, spacing rhythm, state completeness, motion, dark-mode parity, large-text behaviour, copy tone and consistency, google_fonts runtime download vs bundling, localisation readiness with a rough cost to add French); (d) a ranked fix backlog grouped as in the spec §3 (theme/tokens, onboarding/auth, Discover/meal, requests/chat/ratings, profile/settings), each item sized.
- [ ] **Step 3: Evidence discipline.** Every P0/P1 finding cites a screenshot; copy only the cited screenshots into `docs/ux/shots/` (downscaled so each is under about 400 KB). No finding may rest on guessing the rendering from code.
- [ ] **Step 4: Commit** `docs(ux): UX audit of every screen (findings, severities, ranked fix backlog)`

---

### Task 4: Review the audit and hand off to Part B

- [ ] **Step 1:** The controller reviews `docs/ux/AUDIT.md` for evidence (screenshots cited), accuracy against the code, and that the backlog is sized and ordered; a reviewer agent checks a sample of findings against the actual screenshots.
- [ ] **Step 2:** Present the audit summary and the language question to the owner, then write Part B's plan from the approved backlog.
