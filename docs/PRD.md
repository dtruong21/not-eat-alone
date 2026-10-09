# Convyve — Product Requirements

> **Rule zero — v1 is an MVP.** Every feature in this doc that's tagged `in-MVP` must serve a pillar outcome AND be the smallest version of itself that still delivers that outcome. Default verdict on new proposals is POST-MVP. Make us argue features INTO v1, not out of it.

## Vision

Post a meal at a restaurant, match 1:1 with someone nearby, and don't eat alone.

People want to try new restaurants but often won't go alone. Convyve lets someone post a specific meal — a restaurant and a time — and match 1:1 with a nearby person who wants to join. Anchoring every match to a public restaurant at a fixed time keeps first meetings lighter and safer than a conventional date. Dating may follow, but the product is meal-first, not people-first.

## Target user

{{Who specifically. Not "everyone." A concrete persona.}}

## Pillars

Every MVP feature must serve one of these. Anything else gets cut to post-MVP. Replace these with the actual pillars for your project — typically 2–4 of them.

### Pillar 1 — Meal-first

Every match is organized around trying a specific restaurant, not browsing people.

**Features:**
- [ ] Open restaurant in Maps (meal detail) — see Feature specs
- [ ] {{Feature 2}}

### Pillar 2 — Low-pressure

A public restaurant at a fixed time keeps first meetings light, not a loaded date.

**Features:**
- [ ] {{Feature 1}}

### Pillar 3 — Trust & safety

Joiners are approval-gated, women-only meals exist, and block/report is always on.

**Features:**
- [ ] {{Feature 1}}

### Pillar 4 — Liquidity over reach

Depth in one city (Paris) beats thin coverage everywhere.

**Features:**
- [ ] {{Feature 1}}

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

## Out of scope for MVP (post-MVP backlog)

Things deliberately deferred. Anything that lives here cannot be argued back into MVP without an explicit re-scoping discussion.

- Embedded map / restaurant pin in the app (Maps SDK Android + iOS, restricted keys; setup steps preserved in `docs/RELEASE.md` Phase 3.1 §9). Revisit after v1 if users report trouble finding venues.
- {{Item 2}}

## Constraints

- **Solo build, ~16 week target** to first TestFlight / internal release.
- **No backend code beyond Firebase** — Cloud Functions only when client-side won't do.
- **Free tier viable.** Firestore reads kept low via Riverpod caching + `.snapshots()` reuse.
- **Paris soft-launch (v1).** Liquidity beats reach — v1 is Paris-only, enforced by defaulting location fallback to Paris center, not by hard geo-gating. A dismissible in-app notice ("Coming soon in Paris") greets first-time users (deferred to post-v1: full geo-expansion, multi-city seed data, location-based marketing).

## Open questions

Track here. Resolve before implementation, never during.

- [ ] {{Question 1}}
- [ ] {{Question 2}}
