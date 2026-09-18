# not-eat-alone — v1 Design

**Date:** 2026-09-18
**Status:** Approved (design), pending implementation plan
**Stack:** Flutter + Firebase (from the `flutter/` template)

---

## 1. Product positioning

**not-eat-alone is a "don't-eat-alone" app, not a dating app.**

The hero object is the *meal at a restaurant*, not the person. The core user desire we serve: *"I want to try this new restaurant, but I don't want to go alone."* Romantic connection may emerge, but it is a side effect, never the pitch. This is the wedge that differentiates us from Tinder and generic dating apps, which are people-first; we are meal-first.

Consequences of this framing:
- Every match is anchored to a concrete, public restaurant and a fixed time — inherently lower-stakes and safer than a cold 1:1 date.
- Discovery is organized around meals/restaurants, not around browsing people.

## 2. v1 scope philosophy

v1 is a **complete, polished product**, not a thin MVP. No rush to store; a quality gate comes before release. v1 therefore includes the safety, moderation, and notification features a dating-adjacent app must have — but deliberately excludes the larger features listed in Non-goals.

## 3. Core loop (v1)

Meal-first, strictly **1:1** (host + one guest):

1. **Host posts a meal** — picks a restaurant (Places API), date/time, seats (fixed at 1 guest for v1), an optional note, and an optional **women-only** flag.
2. **Discovery** — nearby users browse open, future meals on a map/list.
3. **Request to join** — a user sends a join request (with an optional short message).
4. **Host approves** — host reviews requests and accepts exactly one (approve/deny per request). Accepting locks the meal.
5. **Match** — chat opens between host and guest.
6. **Meet** — they meet at the restaurant at the agreed time (app does not reserve the table).
7. **Post-meal** — both confirm the other showed up, and leave a rating.

## 4. Technical stack

From the repository's `flutter/` template:

- **Flutter** (Dart, strict typing), **Riverpod** (state), **go_router** (navigation).
- **Firebase**: Auth, Cloud Firestore, Storage (profile photos), Cloud Functions, Cloud Messaging (FCM).
- **Google Places API** — restaurant search / autocomplete / details for meal creation and discovery.
- **Google Maps SDK** — display restaurant location and the discovery map.
- **Cloud Functions** — push-notification triggers, content moderation, expired-meal cleanup, and any write that must not be trusted to the client.

## 5. Authentication & identity

- **Firebase Phone Auth as primary** (phone number = strong anti-spam and one-account anchor).
- Plus **Sign in with Apple** and **Google Sign-In**.
- Because social login is offered, **Sign in with Apple is mandatory on iOS** (App Store requirement).
- **18+ only.** Date of birth captured at onboarding; under-18 blocked. App store age rating set accordingly.

## 6. Environments

**One Firebase project** (`not-eat-alone`, #966331142604, org `daki-tle-26-org`) with **two app registrations** and **split Firestore**, wired via **Flutter flavors**:

| Flavor | App id (Android/iOS) | Firestore database | Purpose |
|---|---|---|---|
| `prod` | `com.daki.noteatalone` | `(default)` | Production |
| `stage` | `com.daki.noteatalone.stage` | `stage` | Staging / QA |

- Each flavor has its own `firebase_options_<flavor>.dart` / `google-services.json` / `GoogleService-Info.plist`, all pointing at the one project.
- **What is isolated:** Firestore (separate named databases) and FCM (per-app-registration tokens, so prod/stage devices never cross).
- **What is shared** (single-project trade-off, accepted): Auth user pool, Storage bucket, quotas, billing. Stage vs prod data in the shared surfaces is distinguished by **naming convention** (env-prefixed Storage paths; a test flag on stage accounts), not hard isolation.
- Flutter SDK pinned to **3.47.4** via FVM (`.fvmrc`); CI = **GitHub Actions**.
- **Follow-up (before Plan 3 writes Firestore):** deploy security rules/indexes to the `stage` database too — `firebase.json`'s `firestore` block currently targets only `(default)`; switch it to the array form with a target per database.
- Full-isolation fallback (separate `not-eat-alone-stage` project) remains available later if the shared Auth pool becomes a problem.

## 7. Data model (Firestore)

- **`users/{uid}`** — `displayName`, `photos[]`, `bio`, `gender`, `birthdate`, `verifiedFlags`, `rating`, `blockedUserIds[]`, `fcmTokens[]`, `createdAt`.
- **`meals/{mealId}`** — `hostId`, `restaurant { placeId, name, address, geo, photoRef }`, `dateTime`, `note`, `womenOnly` (bool), `status` (`open` | `matched` | `completed` | `cancelled`), `guestId` (nullable), `geohash`, `createdAt`.
- **`meals/{mealId}/requests/{uid}`** — `requesterId`, `message`, `status` (`pending` | `accepted` | `declined`), `createdAt`.
- **`matches/{matchId}`** — `mealId`, `hostId`, `guestId`, `status` (`active` | `completed` | `cancelled`), `createdAt`.
- **`chats/{matchId}/messages/{messageId}`** — `senderId`, `text`, `createdAt`, `readAt`.
- **`reports/{reportId}`** — `reporterId`, `targetType` (`user` | `meal` | `message`), `targetId`, `reason`, `context`, `createdAt`.
- **Ratings / show-up confirmations** — stored on the `matches` document (per-party show-up boolean + rating).

**Discovery query:** open + future meals near the user, filtered by the women-only rule, using a **geohash** range query (e.g. geoflutterfire-style bounding).

## 8. Screens & flows (v1)

1. Onboarding + auth (phone / Apple / Google) + 18+ gate.
2. Profile setup — photos, bio, gender, birthdate.
3. **Discover** — map + list of open meals near me.
4. Meal detail — restaurant info, host profile, time, note.
5. Create meal — restaurant search (Places), time, note, women-only toggle.
6. Request to join (with optional message).
7. Host inbox — pending requests, approve/deny.
8. Match screen → **Chat**.
9. Meal reminders (push).
10. Post-meal — confirm show-up + rate.
11. Settings — profile edit, blocked users, sign out, delete account.

## 9. Safety & moderation (v1 must-have)

- **Block** and **report** (user, meal, and individual messages).
- **Women-only meals** — enforced by the requester's declared gender (self-declared in v1; stronger verification deferred).
- **Host approves every join** — no auto-match; the host is always the gate.
- **Phone verification** as the identity anchor; **18+ gate**.
- Basic **profanity / image moderation** via Cloud Function on profile and chat content.
- **Safety-tips card** ("meet in the public restaurant, tell a friend, etc.").
- **Account deletion** flow (store requirement + trust).

## 10. Push notifications (FCM) — mandatory

Triggered via Cloud Functions:

- New join request → to host.
- Request accepted / declined → to guest.
- New chat message → to the other party.
- Meal reminders → T-24h and T-2h.
- Post-meal show-up / rating prompt.

## 11. Non-goals (deferred beyond v1)

- Swipe-on-people matching (the "C / hybrid" path) — **v2 growth lever**.
- Group meals (host + multiple guests, group chat) — **v2**.
- Real restaurant reservations (OpenTable/Resy-style integration).
- Restaurant-owner contracts / partner deals — **long-term vision & monetization fork**.
- Gender preference filters beyond women-only (arrive alongside swipe in v2).
- Monetization — v1 is **free**; ads + subscription come later.

## 12. Launch

- **Soft-launch restricted to Paris** first (concentrate liquidity — meal-first needs enough hosts and guests in the same city and time window to work).
- Store submission for iOS (App Store) and Android (Google Play) in the dating/social category, 18+ rating, with account-deletion and safety features in place.

## 13. Key risks to manage

- **Cold-start / liquidity** — meal-first only works with density; hence the single-city (Paris) launch.
- **No-shows** — mitigated by reminders, show-up confirmation, and ratings.
- **Safety & moderation** — table stakes for dating-adjacent apps; block/report/women-only/approval-gate are in v1.
- **Store review friction** — dating/social category needs account deletion, moderation, and Sign in with Apple; all included.
- **Places/Maps API cost** — usage-based billing; restrict keys, cache results, and watch quota.
