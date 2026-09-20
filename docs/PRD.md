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
- [ ] {{Feature 1}}
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

---

## Out of scope for MVP (post-MVP backlog)

Things deliberately deferred. Anything that lives here cannot be argued back into MVP without an explicit re-scoping discussion.

- {{Item 1}}
- {{Item 2}}

## Constraints

- **Solo build, ~16 week target** to first TestFlight / internal release.
- **No backend code beyond Firebase** — Cloud Functions only when client-side won't do.
- **Free tier viable.** Firestore reads kept low via Riverpod caching + `.snapshots()` reuse.
- **{{Other project-specific constraint}}**

## Open questions

Track here. Resolve before implementation, never during.

- [ ] {{Question 1}}
- [ ] {{Question 2}}
