# not-eat-alone — 0-to-Store Roadmap

**Date:** 2026-09-18
**Spec:** [`../specs/2026-09-18-not-eat-alone-v1-design.md`](../specs/2026-09-18-not-eat-alone-v1-design.md)
**Stack:** Flutter + Firebase (adapted from the `flutter/` template)

The v1 design spans many subsystems, so it is decomposed into a sequence of
**phased plans**. Each phase produces working, testable software on its own and
is safe to merge before the next begins. Only **Plan 1** is written in full
detail up front; each later plan is written just-in-time before its phase
begins (so details stay fresh and reflect what earlier phases actually built).

## Phase sequence

| Plan | Phase | Goal | Deliverable (done = testable) |
|---|---|---|---|
| **1** | **Foundation & environments** | Repo becomes the app; Flutter shell + stage/prod flavors wired to two Firebase projects. | App builds and runs on iOS + Android, both flavors, each connected to its correct Firebase project, showing a placeholder home. Template cleanup complete. |
| **2** | **Auth & 18+ onboarding** | Phone + Apple + Google sign-in, Sign in with Apple on iOS, 18+ date-of-birth gate, auth-state routing. | A user can sign in via each method, is blocked if under 18, and lands on an authed home; sign-out works. |
| **3** | **Profile** | `users/{uid}` model, profile setup + edit (photos to Storage, bio, gender, birthdate), Firestore rules for users. | A user can create and edit a complete profile; another user cannot write it (rules-tested). |
| **4** | **Meal creation (Places + Maps)** | Restaurant search via Places API, `meals/{id}` model with geohash, create-meal flow (time, note, women-only). | A host can search a Paris restaurant, create a meal, and see it persisted with a valid geohash. |
| **5** | **Discovery** | Map + list of open, future meals near the user (geohash query), meal-detail screen. | A user in Paris sees nearby open meals on map + list and opens a meal detail. |
| **6** | **Requests & match** | Join request, host inbox (approve/deny), `matches/{id}` creation, meal status transitions, rules. | Guest requests → host approves → meal locks → match created; second guest is rejected. |
| **7** | **Chat** | Realtime 1:1 chat on a match, read receipts, rules restricting access to the two parties. | Matched users exchange messages in realtime; a third user is denied by rules. |
| **8** | **Push notifications** | FCM token management + Cloud Functions triggers: new request, accept/deny, new message, T-24h/T-2h reminders, post-meal prompt. | Each event delivers a push to the correct device on a physical test device. |
| **9** | **Safety & moderation** | Block, report (user/meal/message), women-only enforcement, content-moderation Function, account deletion, safety-tips card. | Blocking hides content both ways; reports persist; women-only rejects non-women; account deletion purges data. |
| **10** | **Post-meal & ratings** | Show-up confirmation + rating on a match, user rating aggregate. | After a meal, both parties confirm + rate; the target's aggregate rating updates. |
| **11** | **Release hardening & store** | Analytics/tracking-plan wiring, Sentry, legal (privacy/ToS), store metadata, 18+ rating, Paris gating, QA sweep, submission prep. | Signed stage + prod builds pass the QA gate; store listings + legal docs ready for App Store + Play submission. |

## Cross-cutting standing rules (from template `CLAUDE.md` / `MASTER-SPEC.md`)

- MVP-first, UX priority, QA gate before release, analytics-first, token discipline.
- All Firestore access wrapped in `lib/core/firebase/*_repository.dart`.
- Every user-facing event defined in `lib/core/analytics/events.dart` and the tracking plan.
- Firestore rules + Cloud Functions carry security; client is never trusted for authorization.

## Notes

- **Paris gating** appears in Plan 5 (discovery query bound) and is enforced/confirmed in Plan 11 (launch).
- **Monetization** (ads + subscription) is explicitly out of every v1 phase.
- Group meals, swipe, and reservations remain out of scope until a future v2 roadmap.
- **Env architecture (decided in Plan 1):** one Firebase project, two app registrations, split Firestore (`(default)`=prod, `stage`=stage); Auth/Storage shared, distinguished by naming convention; FCM split per app. See spec §6.
- **Plan 3 prerequisite:** deploy Firestore rules/indexes to the `stage` database (not just `(default)`) — update `firebase.json`'s `firestore` block to the array form (one target per database) before the first stage Firestore writes.
- **Deferred from Plan 1:** re-add `riverpod_lint` + `custom_lint` once upstream `custom_lint` supports analyzer ≥13; wire `sentry_flutter` (bumped to v9, currently unused) in Plan 11.
