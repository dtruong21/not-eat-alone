# Convyve — Roadmap

Updated **2026-10-09** — reflects actual state, not the original plan. The original phased plan is in `docs/superpowers/plans/2026-09-18-not-eat-alone-roadmap.md`; per-feature behavior lives in `docs/PRD.md`.

> **v1 = MVP, no exceptions.** This roadmap covers what ships in v1 (the minimum across all pillars) and what's deferred to v1.1+. If you find yourself adding "just one more thing" to v1, it goes under § Intentionally deferred instead.

## Status legend

- ✅ Shipped (built, tested, merged)
- 🧪 Built — waiting on a real-device check or a deploy
- 🚧 In progress
- ⏳ Up next (committed)
- ⏸️ Deferred (post-MVP candidate)
- ❌ Not started

**Store submission is planned for November 2026.** Everything below Phase 11 is the path to that date.

---

## Phase 0 — Foundation ✅

Boots, signs in, persists, instrumented.

- ✅ Flutter 3.47.4 (FVM), Dart strict (`very_good_analysis`), go_router, Riverpod, flavors (`prod` / `stage`) on one Firebase project with split Firestore
- ✅ Material 3 theme from the Warm Playful tokens (`lib/core/design/`)
- ✅ Firebase Auth + Firestore with security rules (`firebase/firestore.rules`)
- ✅ Analytics: typed event registry + Firebase Analytics sink; north-star metric defined (`docs/TRACKING-PLAN.md`)
- ✅ Crashlytics + App Check activated (enforcement still off — see Phase 11)
- ✅ CI: GitHub Actions PR gate (analyze, test, unsigned stage builds) + backend CD (rules); Node 22 for Functions

## Phase 1 — Meal-first core loop ✅

- ✅ Auth: phone, Apple, Google + 18+ gate; profile setup/edit with photos
- ✅ Create a meal: **real Places search** (Paris) via the `searchRestaurants` Cloud Function, time, note, women-only
- ✅ Discovery: list of open, future meals; meal detail
- ✅ Open restaurant in Maps (link-out; embedded map deferred)
- ✅ Request to join → host inbox approve/deny → match → 1:1 chat

## Phase 2 — Low-pressure ✅ / 🧪

- ✅ Push notifications: new request, approved/denied, new message, post-meal prompt (tap opens the match chat)
- 🧪 Pre-meal reminders T-24h / T-2h (`mealReminder`) — built; needs deploy and a stage-device check (`docs/TEST-PLAN.md`)
- ✅ Post-meal: confirm show-up + rate; rating aggregate on profile

## Phase 3 — Trust & safety ✅

- ✅ Host approves every join; women-only meals (self-declared)
- ✅ Block, report (user / meal / message), safety-tips card
- ✅ Account deletion cascade (including ratings), Contact support in Settings
- ✅ Match / meal integrity rules (no fabricated matches, host immutable, decide-once requests)
- ⏸️ Automated profanity / image moderation — decided 2026-10-09: ship the Paris soft launch without it (see PRD)

## Phase 4 — Quality ✅ / 🚧

- ✅ Emulator E2E harness, QA sweeps, 470+ unit/widget tests
- ✅ UX pass part A (capture + audit) and 16a (tokens, buttons, font, contrast)
- 🚧 UX 16b — shared widgets, router, dates (branch `feature/ux-16b-shared`, in review locally)

---

## Phase 11 — Release hardening, polish + submit ⏳

Work through `docs/RELEASE.md` in order. None of it is code-blocking.

- 🧪 **Device verification (two phones, stage build):** push flows, meal reminders, post-meal rate push, Open in Maps hand-off (Apple Maps pin vs search), `directions_opened` in DebugView
- ⏳ Backend: confirm all 12+ functions deployed on Node 22 (`firebase functions:list`); App Check debug tokens registered, then **enforce App Check** for Firestore / Storage / Functions
- ⏳ Native auth: APNs key, Android SHA-256 (debug, upload, Play App Signing), Sign in with Apple capability
- ⏳ Support mailbox: replace the placeholder `supportEmail` and match it to the store Support URL
- ⏳ Privacy policy + Terms of Service hosted over HTTPS; `legal_urls.dart` updated
- ⏳ Signing: iOS certificate + profile, Android keystore, Play App Signing
- ⏳ Store accounts, App Store Connect + Play Console apps created
- ⏳ App Store + Play Store metadata, 18+ age rating, UGC answers (report, block, support contact; **moderation risk** noted in PRD)
- ⏳ Store screenshots (5 per platform from real builds)
- ⏳ CI gates green on `main`; manual device QA; `release/v1.0.0` → `main` → tag + submit

---

## Critical path to first release

| When | Goal |
|------|------|
| Now – mid Oct | Merge UX 16b; deploy reminders; device verification round 1 |
| Late Oct | Backend hardening (App Check enforcement), native auth config, legal hosting, support mailbox |
| Early Nov | Signing, store accounts, metadata + screenshots, manual device QA |
| November | Release branch → tag → submit to App Store + Play |

## Slip absorber

If the schedule slips, **UX polish beyond 16b** is the first thing to drop, then reminders tuning; the trust & safety pillar does not get cut. Ship fewer things well rather than more poorly. Document any cut in `docs/PRD.md § Out of scope`.

## Intentionally deferred (post-MVP)

Cuts from the original plan. Track here so they don't sneak back in:

- Embedded map / restaurant pin and a discovery map (Maps SDK keys + native setup; steps preserved in `docs/RELEASE.md` Phase 3.1)
- Automated profanity / image moderation
- Comments on ratings; edit/delete ratings
- Geofence expansion beyond Paris; multi-city
- Swipe matching, group meals, reservations, restaurant partnerships, extra gender filters (v2+)
- Monetization — v1 is free

## Tracking per-feature spec status

`/spec` writes a PRD entry → `docs/PRD.md` is the source of truth for what each feature does. The phase checklist here only tracks *whether* a feature has shipped; *what* it does is in PRD.
