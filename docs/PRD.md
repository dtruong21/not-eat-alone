# Convyve — Product Requirements

> **Rule zero — v1 is an MVP.** Every feature in this doc that's tagged `in-MVP` must serve a pillar outcome AND be the smallest version of itself that still delivers that outcome. Default verdict on new proposals is POST-MVP. Make us argue features INTO v1, not out of it.

## Vision

Post a meal at a restaurant, match 1:1 with someone nearby, and don't eat alone.

People want to try new restaurants but often won't go alone. Convyve lets someone post a specific meal — a restaurant and a time — and match 1:1 with a nearby person who wants to join. Anchoring every match to a public restaurant at a fixed time keeps first meetings lighter and safer than a conventional date. Dating may follow, but the product is meal-first, not people-first.

## Target user

**Primary:** adults (18+) in Paris who want to try a specific restaurant but don't want to go alone — people who would happily share a table with a stranger if it is in a public place, at a fixed time, with someone the host chose to approve.

**Also served:** women who want women-only meals (self-declared in v1); newcomers to the city who have the appetite but not the dining company yet.

*Working hypothesis from the v1 design — to be validated with the first soft-launch testers (see Open questions).*

## Pillars

Every MVP feature must serve one of these. Anything else gets cut to post-MVP. Replace these with the actual pillars for your project — typically 2–4 of them.

### Pillar 1 — Meal-first

Every match is organized around trying a specific restaurant, not browsing people.

**Features:**
- [x] Create a meal: restaurant (real Places search, Paris), date/time, optional note
- [x] Discovery: list of open, future meals near you
- [x] Meal detail: restaurant, host, time, note
- [x] Open restaurant in Maps (meal detail) — see Feature specs (built; real-device check pending)
- [ ] Embedded map / discovery map — post-MVP (see backlog)

### Pillar 2 — Low-pressure

A public restaurant at a fixed time keeps first meetings light, not a loaded date.

**Features:**
- [x] Strictly 1:1 meals at a public restaurant at a fixed time
- [x] Request to join (optional message) → host approves or denies → chat opens on match
- [x] Post-meal: confirm show-up and rate
- [x] Push notifications: new request, approved/denied, new message, post-meal rating prompt
- [x] Pre-meal reminders: push 24h and 2h before a matched meal — see Feature specs

### Pillar 3 — Trust & safety

Joiners are approval-gated, women-only meals exist, and block/report is always on.

**Features:**
- [x] Host approves every join — no auto-match
- [x] Women-only meals (self-declared gender in v1)
- [x] Block and report (user, meal, message)
- [x] 18+ gate; sign-in with phone, Apple or Google
- [x] Safety-tips card
- [x] Account deletion
- [x] Contact support (Settings; address shown in-app)
- [ ] Private vs public profile split — closes the P1 date-of-birth exposure (see Feature specs)
- [ ] Profanity / image moderation (Cloud Function) — not built; deferred by decision (see Open questions)

### Pillar 4 — Liquidity over reach

Depth in one city (Paris) beats thin coverage everywhere.

**Features:**
- [x] Paris-only soft launch (location fallback to Paris center; restaurant search limited to a Paris bounding box)
- [x] Dismissible "Coming soon in Paris" notice for first-time users
- [ ] Geofence expansion / "expand search" prompt — post-MVP

## Feature specs

Detailed specs for committed MVP features. The pillar checklists above are the commitments; entries here are the implementation contracts. Add one block per feature using the format below.

### Feature: {{feature-name}}
Pillar: {{which pillar}}
Status: in-MVP | post-MVP | cut

**User story:**
As a {{user}}, I want {{capability}} so that {{outcome}}.

**Acceptance criteria:**
- [ ] {{criterion 1}}
- [ ] {{criterion 2}}
- [ ] Empty state: {{what shows}}
- [ ] Offline: {{behavior}}
- [ ] Error: {{behavior}}

**Out of scope (cut from this feature):**
- {{thing 1}}
- {{thing 2}}

### Feature: Open restaurant in Maps (meal detail)
Pillar: 1 — Meal-first (supports 2 — Low-pressure)
Status: in-MVP (reduced form: link-out only). The embedded map / pin is **post-MVP**.

**Verdict:** The outcome that matters is "I can find the restaurant on the day." That needs a one-tap hand-off to the user's own maps app, not a map rendered inside Convyve. The link-out costs one row on the meal detail, uses `url_launcher` (already a dependency), and needs no Maps SDK, no API keys and no billing exposure. The embedded pin adds two restricted SDK keys, native setup on both platforms and ongoing cost for no extra outcome, so it is cut from v1.

**User story:**
As a guest who was approved for a meal, I want to open the restaurant in my maps app so that I can get there without copying the address by hand.

**Acceptance criteria:**
- [ ] Meal detail's restaurant card shows an "Open in Maps" action (only the existing restaurant card; no new section, no new route).
- [ ] Tap opens the platform maps app at the restaurant's `lat/lng` with the restaurant name as label (Apple Maps on iOS, Google Maps URL/intent on Android). No API key involved.
- [ ] Fires `directions_opened` (no PII, no coordinates) via the typed registry; event is in `docs/TRACKING-PLAN.md` first (`/track`).
- [ ] Empty: if the meal has no usable coordinates (missing or 0,0, e.g. legacy meals), the action is hidden — the address text stays as today.
- [ ] Loading: none (pure local hand-off; the card renders with the meal).
- [ ] Offline: the action still launches the maps app (the hand-off is local); the maps app owns its own offline behavior.
- [ ] Error: if no app can handle the URL, show a snackbar "Couldn't open Maps" and keep the screen state unchanged.
- [ ] Accessibility: `Semantics` label "Open <restaurant name> in Maps", button role, ≥ 48dp target, readable in dark mode and at large text sizes.

**Out of scope (cut from this feature):**
- Embedded map or pin inside the app (`google_maps_flutter`), Maps SDK keys, native key injection.
- Turn-by-turn directions, distance/ETA, "nearby" map discovery, live location sharing.
- Showing a map on the discovery list or in the create-meal flow.

---

### Feature: Meal reminders (T-24h and T-2h)
Pillar: 2 — Low-pressure (reduces no-shows, which protects Pillar 1 and the liquidity of Pillar 4)
Status: in-MVP

**Verdict:** The smallest version that still cuts no-shows is two server-sent pushes to the two people of a matched meal. No new screens, no settings, no per-user preferences, no in-app inbox; tapping the push opens the match chat, where they can coordinate. Reuses the existing push pipeline and the `push_opened` event.

**User story:**
As a host or guest with a matched meal, I want a reminder the day before and a couple of hours before so that I remember to show up and can message my match if something changes.

**Acceptance criteria:**
- [ ] Both participants of a `matched` meal get one push ~24h before (window 22–24h) and one ~2h before (window 1–2h) the meal time. Meals matched inside a window get that reminder at the next run; a meal matched later than a window's start never gets the stale reminder.
- [ ] Each reminder is sent at most once per meal (idempotency flag on the meal); a scheduler retry or overlap never duplicates it. A lost reminder is preferred over a duplicate.
- [ ] Content: title "Your meal is today/tomorrow" (24h) or "Your meal is coming up" (2h); body "<restaurant> at <HH:mm>" in Paris time (v1 is Paris-only), restaurant name truncated. No other PII.
- [ ] Tap opens the match chat (`/chats/:mealId`) and fires `push_opened` with `type: 'meal_reminder'`.
- [ ] Cancelled, open (unmatched) and already-past meals get nothing.
- [ ] Empty: a user with no registered device token is skipped silently. Offline: delivery is FCM's job (delivered when the device is back). Error: a failing send for one participant or meal is logged and does not block the rest of the run.
- [ ] Runs for both databases (`(default)` and `stage`).

**Out of scope (cut from this feature):**
- User-configurable reminder times or an opt-out toggle beyond the OS notification permission.
- Email/SMS reminders, calendar invites, "add to calendar".
- Reminders to people with pending (unapproved) requests.
- Time-zone handling beyond Paris.

---

### Feature: Private vs public profile (close the date-of-birth exposure)
Pillar: 3 — Trust & safety
Status: in-MVP (release blocker: QA P1 `docs/bugs/2026-10-09-users-collection-exposes-dob-to-all-signed-in-users.md`)

**Verdict:** Today any signed-in account can read and list every `users/{uid}` doc: exact date of birth, gender, bio, photos, rating. For a dating-adjacent app launching in the EU this is not acceptable, and accepting it would also require a privacy-policy change and store privacy labels saying "date of birth visible to other users". Fixing it is cheaper than disclosing it, so it earns its way into v1. Smallest version: split what other people legitimately see from what only the owner (and the security rules) may read, and lock the age-gate fields. No new screens, no new features, no change to what users see.

**User story:**
As a person on Convyve, I want other users to see only my name, photo, bio, age and rating so that my exact date of birth and gender are never exposed to strangers.

**Acceptance criteria:**
- [ ] Two documents per user: **public** `profiles/{uid}` (display name, photo URLs, bio, age in years, rating count/average) and **private** `users/{uid}` (date of birth, age-verified flag, gender, created-at). Nothing else is added.
- [ ] Rules: any signed-in user may `get` a public profile; `list`/query on `profiles` is denied (no enumeration); only the owner may write their own public profile (never the rating fields, which only the `onRatingCreated` / deletion functions write). `users/{uid}` is readable and writable by the owner only; the rules themselves may still read it (e.g. women-only checks use `gender`). `fcmTokens` stays owner-only.
- [ ] 18+ gate lock: once `ageVerified` is true, the owner can no longer change `dob` or `ageVerified`. Before it is true (age-gate retry) they can. Self-attestation remains the v1 trust model; stronger verification is out of scope and the privacy policy says so.
- [ ] Age: other users see an age in years only. The owner's app keeps the public age correct (written on profile save and refreshed at sign-in when it differs from the date of birth). No month/day/year of birth is ever in a public document.
- [ ] All screens that show another person (discovery, meal detail host block, request inbox, chat, rating badge) read the public profile; none reads another user's `users/{uid}`.
- [ ] Existing accounts are backfilled once (script run per database) before the rules are deployed; account deletion also removes the public profile; rating aggregates move to the public profile (functions updated, aggregate math unchanged).
- [ ] Empty: a person with no public profile yet (not backfilled / brand new) renders as a neutral placeholder name and avatar, never a crash or a blocked screen.
- [ ] Offline: previously loaded profiles show from cache; no new loading state is introduced.
- [ ] Error: a failed public-profile read shows the screen's existing error/placeholder state; it never exposes the private document as a fallback.
- [ ] Rules tests (emulator): another user cannot read or list `users`, cannot list `profiles`, cannot write another's profile, cannot change `dob`/`ageVerified` after verification, cannot write rating fields; the owner can read/edit their own documents; women-only request rules still work.
- [ ] `docs/legal/privacy.md` and the store privacy labels list exactly what is public (name, photos, bio, age, rating) and what is private (date of birth, gender).

**Out of scope (cut from this feature):**
- Server-side age or identity verification (ID check, document upload) — v1 stays self-attested behind phone sign-in.
- Hiding the 18+ gate from the owner's own device, or tamper-proof age (the owner can still lie about age before verification).
- Age bands/ranges instead of exact age; per-field visibility settings; showing profiles only to matched users.
- Other rule-hardening gaps from the same QA sweep (report payload limits, server-set message timestamps) — tracked in `docs/bugs/2026-10-09-firestore-rules-hardening-gaps.md`.
- Changing women-only enforcement logic.

---

## Out of scope for MVP (post-MVP backlog)

Things deliberately deferred. Anything that lives here cannot be argued back into MVP without an explicit re-scoping discussion.

- Embedded map / restaurant pin in the app and a discovery map (Maps SDK Android + iOS, restricted keys; setup steps preserved in `docs/RELEASE.md` Phase 3.1 §9). Revisit after v1 if users report trouble finding venues.
- Swipe-on-people matching, group meals, restaurant reservations, restaurant partnerships, extra gender-preference filters (v2+; from the v1 design non-goals).
- Monetization — v1 is free; ads/subscription later.
- Comments on ratings, edit/delete ratings.

## Constraints

- **Solo build, ~16 week target** to first TestFlight / internal release.
- **No backend code beyond Firebase** — Cloud Functions only when client-side won't do.
- **Free tier viable.** Firestore reads kept low via Riverpod caching + `.snapshots()` reuse.
- **Paris soft-launch (v1).** Liquidity beats reach — v1 is Paris-only, enforced by defaulting location fallback to Paris center, not by hard geo-gating. A dismissible in-app notice ("Coming soon in Paris") greets first-time users (deferred to post-v1: full geo-expansion, multi-city seed data, location-based marketing).

## Open questions

Track here. Resolve before implementation, never during.

- [ ] **Scope tension.** The approved v1 design (`docs/superpowers/specs/2026-09-18-not-eat-alone-v1-design.md`) calls v1 "a complete, polished product" with a discovery map and Maps SDK; this PRD's rule zero says v1 is a minimum. Current call: list-only discovery + "Open in Maps" link-out, embedded map post-MVP. Confirm or re-scope before launch.
- [x] **Moderation — decided 2026-10-09: ship the Paris soft launch without automated profanity/image moderation.** Mitigations in v1: host approves every join, report (user/meal/message) and block are always available, 18+ phone-verified accounts, small soft-launch audience. Revisit before any geo-expansion or after the first reported abuse. **Risk to watch:** Apple (Guideline 1.2) and Google Play user-generated-content rules expect a way to filter objectionable content as well as report/block and published contact info; a reviewer may reject the build. If so, the smallest fix is a server-side blocklist check on chat messages and profile text, not image moderation.
- [x] **Reminders — decided 2026-10-09: build the T-24h / T-2h meal reminders into v1** (no-show risk is the main liveness risk; see Feature specs).
- [x] **North-star metric — defined 2026-10-09:** weekly completed meals (see `docs/TRACKING-PLAN.md`). Targets to be set after four weeks of soft-launch data.
- [ ] **Persona.** Validate the target user with the first 20 beta testers (who they are, why they'd join a stranger's meal).
