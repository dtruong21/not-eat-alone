# Tracking Plan

The analytics PRD. Every event in the product is defined here BEFORE it's instrumented in code. Without this doc, you end up with 200 random events nobody can interpret six months from now.

> **Rule:** If an event is not in this doc, it does not get fired in code. New event? Add the row here first via `/track`, then implement.

---

## North-star metric (NSM)

The single number that, if it goes up, means the product is working.

**NSM:** {{e.g. "Weekly active users who completed ≥1 check-in"}}

**Why this one:** {{one sentence — what user behavior it captures}}

**How we'd compute it:** {{SQL-ish description of the query against the event stream}}

---

## Supporting metrics (2-4 max)

The dials that move the NSM. Resist the urge to track everything.

| Metric | Definition | Why it matters |
|---|---|---|
| {{Activation rate}} | {{% of new signups who reach key moment within 24h}} | Leading indicator of NSM |
| {{Retention W1}} | {{% of new users who return in week 1}} | Tells us we have product-market fit signal |
| {{Feature adoption}} | {{% of WAU using feature X}} | Tells us which features earn their keep |

---

## Naming convention

- **Event names:** `noun_verb` in snake_case. Past tense for verbs. Examples: `habit_created`, `checkin_marked_done`, `friend_request_accepted`.
- **Property names:** snake_case. Scalars only — no nested objects.
- **User properties:** snake_case. Prefix with `total_` for counts, `last_` for timestamps, `is_` for booleans.

Bad: `addedHabit`, `userClickedFriendsTab`, `checkin/complete`.
Good: `habit_created`, `friends_tab_viewed`, `checkin_marked_done`.

---

## Identification strategy

- Anonymous users get a stable anonymous ID from the analytics SDK (PostHog / Firebase Analytics).
- On sign-up, call `identify(uid)` with the Firebase Auth uid. Analytics merges anonymous events into the identified profile.
- On sign-out, call `reset()` so the device doesn't continue attributing events to the prior user.
- Never send PII (email, name, content) as event properties. Reference by `user_id` only — joins happen at query time, not at send time.

---

## Privacy — what we DO NOT track

- ❌ Content of user-generated text (notes, journal entries, names of habits)
- ❌ Email, real name, phone number, location
- ❌ Advertising identifiers (IDFA, AAID)
- ❌ Cross-app tracking
- ❌ Anything not in this doc

This list is enforced in `lib/core/analytics/events.dart` via the typed event registry — if a property isn't declared, the Dart compiler rejects the send.

---

## Event registry

Every event the product fires lives in this table. Add a row via `/track <event_name>`.

| Event | When it fires | Properties | Feeds metric |
|---|---|---|---|
| `app_opened` | App enters foreground from cold start or background | `is_cold_start: bool` | WAU, retention |
| `signup_completed` | New user finishes account creation | `method: 'email' \| 'google' \| 'apple' \| 'phone' \| 'anonymous'` | Signups |
| `signin_started` | User initiates a sign-in flow (before the provider/OTP completes) | `method: 'email' \| 'google' \| 'apple' \| 'phone'` | Auth funnel drop-off |
| `signin_completed` | Returning user signs in | `method: 'email' \| 'google' \| 'apple' \| 'phone'` | Auth method mix |
| `age_gate_passed` | User clears the age-verification gate | — | Signup funnel |
| `age_gate_failed` | User fails the age-verification gate (under minimum age) | — | Signup funnel, compliance |
| `signout_completed` | User explicitly signs out | — | (rare — investigate spikes) |
| `profile_completed` | User finishes forced onboarding profile setup (name, gender, ≥1 photo) | — | Onboarding funnel |
| `profile_photo_added` | User uploads a profile photo | `count: int` (photo count after upload) | Profile completeness |
| `profile_edited` | User saves changes to their profile from settings | — | Engagement |
| `restaurant_selected` | User picks a restaurant from search results while creating a meal | — | Meal-creation funnel |
| `meal_created` | User finishes creating a meal (restaurant, time, optional note, women-only toggle) | `women_only: bool` | Meals created, women-only adoption |
| `discovery_viewed` | Discovery feed loads or refreshes with a (possibly empty) result list | `count: int` (number of meals shown) | Discovery engagement, feed health |
| `meal_opened` | User opens a meal's detail view from the discovery feed | `women_only: bool` | Meal engagement, women-only funnel |
| `join_requested` | Guest sends a request to join a meal | `women_only: bool` (No PII) | Request funnel, women-only adoption |
| `request_approved` | Host approves a pending join request | — (No PII) | Request funnel, host responsiveness |
| `request_denied` | Host denies a pending join request | — (No PII) | Request funnel |
| `match_created` | A match is created after a host approves a request | `women_only: bool` (No PII) | Matches created, women-only adoption |
| `chat_opened` | User opens a match's chat thread | — (No PII) | Chat engagement |
| `message_sent` | User sends a chat message | — (No PII) | Chat engagement, messages per match |
| `push_permission_granted` | OS notification-permission prompt is resolved (on registration attempt) | `granted: bool` (No PII — the device token is never sent as a property) | Push opt-in rate |
| `push_opened` | User taps a push notification and the app opens/routes from it | `type: string` (push route type, e.g. `'match'`, `'message'`) (No PII) | Push engagement, re-engagement funnel |
| `user_blocked` | User blocks another user | — (No PII) | Safety, block rate |
| `user_reported` | User submits a report against a user, meal, or message | `target_type: string` (category — `'user'` \| `'meal'` \| `'message'`; No PII, no uid/target id) | Safety, report rate |

{{Add project-specific events below as `/track` runs append them.}}

---

## User property registry

Sparse — only properties that drive segmentation or are needed for cross-event analysis.

| Property | When set | Type | Use |
|---|---|---|---|
| `signup_date` | On `signup_completed` | ISO date string | Cohort analysis |
| `signup_method` | On `signup_completed` | `'email' \| 'google' \| 'apple' \| 'phone' \| 'anonymous'` | Auth-channel cohorts |
| `app_version` | On `app_opened` | semver string | Roll out / regression tracking |
| `platform` | On `app_opened` | `'ios' \| 'android' \| 'web'` | Platform-specific issues |

---

## Implementation discipline

- The typed event registry lives at [`lib/core/analytics/events.dart`](../lib/core/analytics/events.dart). It is the **source of truth in code**. The table above is its human-readable mirror.
- Events fire via `track(name, props)` from `lib/core/analytics/client.dart`. Never call the analytics SDK directly from widgets or notifiers.
- A new event requires both a row in this doc AND a typed entry in `events.dart`. The `/track` command writes both.
- Add an event only when you have a metric question that needs answering. Speculative events are clutter.

---

## Review cadence

- **Per release:** `qa-engineer` verifies that every new event in this release actually fires in the dev build (instrumentation drift is real).
- **Monthly:** review this doc (a `/weekly-review`-style pass) against the dashboards. Any event with zero usage in the last 30 days gets deleted (from both this doc and `events.dart`).
- **Per pivot:** if the NSM changes, this doc is rewritten before any events get added or changed.
