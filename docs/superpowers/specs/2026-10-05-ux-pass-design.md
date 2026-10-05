# Convyve — Front-end & UX Pass (Plan 15)

**Date:** 2026-10-05
**Status:** Draft. Part A (capture + audit) is planned in detail; Part B (fixes) is planned after the audit.
**Goal:** The app is functionally complete but has never been looked at as a whole. Photograph every screen in realistic states on a real simulator, audit it against `docs/DESIGN.md` and basic accessibility, then fix what the audit finds. The same screenshots feed the store listing.

---

## 1. Why now, and what we know

- All v1 flows exist and are covered by unit, widget and E2E tests. Those tests check structure; nobody has judged looks, spacing, contrast, states or copy on a device.
- Reviews of the last features found visual problems only by accident: a meal line at ~1.15:1 contrast (the theme's border colour used as text), a tile that overflowed on 320 px phones, a snackbar that never dismissed. The same `colors.outline`-as-text pattern appears in about 39 other places; the enabled `FilledButton` background equals the card surface; the home of every "empty / loading / error" state is unverified.
- Typography is Nunito via the `google_fonts` package, which downloads the font from Google at runtime. That means a font flash on first launch, a fallback font offline, and a request to Google servers carrying the user's IP (a GDPR point for an EU launch). Bundling the font as an app asset is likely part of Part B.
- The Places API key and the Blaze plan are about a month away, so this is the right time for a design pass. It is independent of those two.

## 2. Part A — Capture and audit

### 2.1 How we capture (real rendering, no mocks)

A dedicated capture test boots the real app on the iOS Simulator against the Firebase emulators (the same machinery as the E2E suite), seeds a realistic world, drives the app to each screen state, and, at each one, hands off to the host to take a native screenshot.

- **Seeded world** (admin REST helpers, rules bypass): about 8 users with profile photos, about 10 meals across times, restaurants and women-only, requests in several states (pending, approved, denied, on a past meal), one match with a realistic chat (short, long, many messages, seen marker), a rating, a block. Avatars are generated placeholder images served from a local HTTP server on `127.0.0.1` (ATS does not apply to IP addresses), so photo layouts are exercised without shipping any real photos.
- **Handoff:** the test writes `/tmp/convyve-ux/<name>.ready` (the simulator shares the host filesystem), a host script runs `xcrun simctl io <device> screenshot` and writes `<name>.ack`, the test continues. Bounded waits throughout.
- **Matrix:** device sizes (the existing "Convyve E2E" iPhone 17 Pro plus a small-phone simulator such as iPhone SE) × light/dark (`xcrun simctl ui <device> appearance`) × text size (default and a large accessibility size via `xcrun simctl ui <device> content_size`).
- **Screens and states** (13 screens): sign-in; phone verify; age gate (incl. under-18); profile setup and edit; Discover (data, empty, loading, location-denied banner, Paris notice); create meal; restaurant search; meal detail (open, requested, not selected, matched, own meal, women-only disabled); requests inbox (data, empty, past-meal chip); chats list (data, empty); chat (messages, composer, safety tips, seen marker); rating sheet and the post-meal card; report sheet; settings; error and offline-ish states where reachable.
- Output goes to `ux_audit/out/` (gitignored). The harness is not part of CI and not under `integration_test/` (so `make e2e` does not run it); run it with `make ux-capture`, which uses `flutter drive --driver ux_audit/driver.dart --target ux_audit/capture_test.dart` (not `flutter test`, which only runs on a device for files under `integration_test/`).

### 2.2 The audit

The optional `ux-designer` agent (and the `frontend-design` skill's guidance) reads the screenshots with `docs/DESIGN.md`, `lib/core/design/`, and each screen's code, and writes `docs/ux/AUDIT.md`:

- Per screen: what works, what doesn't, each finding with severity (P0 broken or unreadable, P1 clear UX problem, P2 polish), a screenshot reference, and the proposed fix.
- Cross-cutting: contrast (WCAG AA 4.5:1 for text, 3:1 for UI), tap targets (44 pt), type scale and weights, spacing rhythm, colour-token misuse, button hierarchy (the same-as-surface `FilledButton`), loading/empty/error state completeness, motion, dark-mode parity, large-text behaviour, copy tone and consistency, and localisation readiness (the copy is English-only for a Paris launch).
- A ranked fix list that becomes Part B's plan.

## 3. Part B — Fixes (planned after the audit)

Grouped to keep reviews small: (1) theme/token fixes that touch everything (text colours, button fills, font bundling, contrast tests), (2) onboarding/auth, (3) Discover and meal flows, (4) requests/chat/ratings, (5) profile/settings, then re-capture "after" screenshots and a store screenshot set (`docs/store/screenshots/` with captions) that feeds `docs/store/listing.md`. Each fix lands with widget tests (layout at narrow width and large text where relevant) and is verified against a fresh capture.

## 4. Decisions made, and one to raise after the audit

- Design direction: keep the Warm Playful system in `docs/DESIGN.md`; the pass fixes deviations from it rather than redesigning.
- **Language:** the app is English-only. A Paris launch probably wants French; that is a product decision with real scope (string extraction, translations, date/number formats). The audit will list the cost; the decision is the owner's.
- Non-goals: new features, backend or rules changes, Android capture (the harness targets the iOS simulator; Android review can reuse the screens' widget-level fixes).

## 5. Delivery

Branch `feature/ux-pass` off `develop`, subagent-driven. Part A is its own plan; Part B's plan is written from the audit and approved before execution.
