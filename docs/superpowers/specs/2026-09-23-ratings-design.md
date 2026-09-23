# Convyve — Post-Meal & Ratings Design (Plan 10)

**Date:** 2026-09-23
**Status:** Approved (design), pending implementation plan
**Feature:** After a meal, both matched parties get prompted (in-app card + a post-meal push) to confirm show-up and rate each other. Ratings aggregate onto the target's user doc via a Cloud Function; a scheduled Function drives the post-meal push. Built on the `matching` (matches/meals) + `user` features + the Plan-8 Functions codebase.

---

## 1. Goal & constraints

Close the loop after a meetup: capture whether the other person showed up and a 1–5 star rating (plus an optional short comment), and surface each user's aggregate rating as a trust signal. Aggregation is server-side (a user must never be able to write their own rating) via a Cloud Function; the post-meal reminder push uses a scheduled Function. Both need the Firebase Blaze plan (already required by push/deletion). The in-app path works without any of that.

Single Firebase project, split databases. Ratings live in the flavor's database. Triggers (rating-created + the schedule) run in the Plan-8 Functions codebase, registered per database where they are Firestore triggers.

## 2. Rating model

`ratings/{matchId}_{raterUid}`:

```
{ id, matchId, raterUid, targetUid, stars (1..5 int), showedUp (bool), comment (string, optional ≤200), createdAt }
```

One rating per rater per match (fixed id). Immutable in v1.

### Rules

```
match /ratings/{ratingId} {
  allow read: if isSignedIn() && resource.data.raterUid == request.auth.uid; // own only
  allow create: if isSignedIn()
                && request.resource.data.raterUid == request.auth.uid
                && request.resource.data.raterUid != request.resource.data.targetUid
                && request.resource.data.stars is int
                && request.resource.data.stars >= 1 && request.resource.data.stars <= 5
                && request.resource.data.showedUp is bool
                && (!('comment' in request.resource.data) || request.resource.data.comment.size() <= 200)
                && isMatchParticipant pair check: both rater + target are the two participants of matches/{matchId};
  allow update, delete: if false;
}
```

The participant check: `get(/matches/$(request.resource.data.matchId)).data` — require `raterUid` and `targetUid` are exactly its `hostId`/`guestId` (in either arrangement). Time-gating (only after the meal) is enforced client-side; the rule allows a rating any time after the match exists (acceptable — a rating pre-meal is a non-issue and the client gates it).

## 3. Aggregate (Cloud Function)

`AppUser` gains `ratingCount` (int, default 0) and `ratingAvg` (double, default 0) — display-only, Function-written. (Internally the user doc also carries `ratingSum` for atomic incremental averaging.)

- `onRatingCreated` — Firestore trigger on `ratings/{ratingId}` create, registered for **both** databases (shared handler, like the Plan-8 triggers). In a transaction on `users/{targetUid}` (in the triggering database): `ratingSum += stars`, `ratingCount += 1`, `ratingAvg = ratingSum / ratingCount`. Pure helper `nextAggregate(prevSum, prevCount, stars)` returning `{sum, count, avg}` — unit-tested.
- **The `users/{uid}` update rule is tightened** so a client update cannot change `ratingSum`/`ratingCount`/`ratingAvg`: require those three unchanged (`request.resource.data.X == resource.data.X`, treating missing as 0). The Function (admin) bypasses rules. Profile edits (displayName/bio/gender/photoUrls/dob/ageVerified) still allowed.

## 4. Post-meal push (scheduled Cloud Function)

- `postMealReminder` — a scheduled Function (`onSchedule`, hourly, region `europe-west1`), running per database. Each run: query `meals` where `status == 'matched'` and `dateTime <= now` and `dateTime > now - 90m` (a window covering the last run) and `postMealNotified != true`. For each: push both `hostId` + `guestId` — "How was it? Rate {other}'s meal" (reusing the Plan-8 `sendToUser` + a new payload builder), set `status = 'completed'` and `postMealNotified = true`.
  - The window + the `postMealNotified` flag dedupe across runs; a meal missed by one run is caught by the next (until it ages out of the window — the flag is the real guard, the window is an efficiency bound; use a generous window or drop the lower bound and rely on the flag + `status=='matched'`).
  - Scheduled Functions require Blaze + Cloud Scheduler (auto-provisioned on deploy). Documented in `docs/CICD.md`.
- This introduces the scheduled-Function infrastructure deferred in Plan 8; the T-24h/T-2h *pre-meal* reminders remain deferred (a follow-up can add more `onSchedule` handlers the same way).

## 5. In-app post-meal flow

- A `PostMealCard` appears on the matched chat (`ChatScreen`) when `now > meal.dateTime` and the current user hasn't yet rated this match (watch `ratings/{matchId}_{myUid}` existence). Tapping opens a `RatingSheet`.
- `RatingSheet` — a modal: a 1–5 star selector, a "Did they show up?" toggle (default yes), an optional short comment field (≤200), Submit (disabled until stars picked) → `RatingController.submit(...)` → close + a thank-you SnackBar. All states, tokens.
- The chat needs the `Meal` (for `dateTime`) and the match (for `targetUid`). `ChatScreen` currently derives `otherUid` from `chatListProvider`; extend that lookup to also expose the meal's `dateTime` (the match's `mealId` → the meal doc, or carry it on the chat-list item). A small `matchMealProvider(matchId)` (reads the meal by `mealId == matchId`) supplies `dateTime`.

## 6. Aggregate display

- Show a compact rating widget (⭐ `ratingAvg` · `ratingCount` reviews) wherever a user is surfaced: the meal-detail host block, the chat header, and the profile. A `RatingBadge(uid)` widget reads `userDocProvider(uid)` and renders the aggregate (or "New" when `ratingCount == 0`). Reused across those screens.

## 7. Analytics

Declared in `events.dart` + `docs/TRACKING-PLAN.md`, no PII:
- `meal_rated` (props: `stars` int, `showed_up` bool)
- `post_meal_prompt_shown`

## 8. Feature layout

```
lib/features/rating/
  domain/       entities/rating.dart + repositories/rating_repository.dart
  data/         dtos/rating_dto.dart + mappers/ + repositories/rating_repository_impl.dart
  application/  rating_providers.dart + rating_controller.dart + my_rating_provider.dart (has-rated?) + match_meal_provider.dart
  presentation/ rating_sheet.dart + widgets/post_meal_card.dart + widgets/rating_badge.dart
```

`AppUser` (+ dto/mapper) gains `ratingCount`/`ratingAvg`. Functions: `onRatingCreated` + `postMealReminder` + payload builder. Rules: `ratings` block + tightened `users` update. Display wired into meal-detail/chat/profile.

## 9. Testing

- Entity/DTO: `Rating` round-trip (incl. optional comment, null createdAt); `AppUser` with rating fields.
- `RatingRepositoryImpl` (fake_cloud_firestore): `submit` writes `ratings/{matchId}_{raterUid}` with stars/showedUp/targetUid; `hasRated(matchId, uid)` / `watchMyRating` reflects existence.
- Aggregate helper `nextAggregate` (Functions jest): sum/count/avg math incl. first rating.
- Controller: `submit` fires `meal_rated`, no-ops without stars, error surfaces.
- Widgets: rating sheet (Submit gated on stars; submit calls controller); post-meal card shows only after meal time + when unrated; rating badge shows avg/count and "New" at 0.
- Rules (manual/emulator): a non-participant can't rate; a user can't rate themselves; stars out of 1..5 rejected; a client cannot write its own `ratingAvg`/`ratingCount` on `users/{uid}`; ratings read-own-only.
- Scheduled/aggregate Functions: pure helpers unit-tested; the trigger/schedule execution is emulator/manual (documented).

## 10. Non-goals (deferred)

- Editing or deleting a submitted rating; a rating cooldown/appeal.
- Aggregating no-shows into a reliability score or auto-consequences (no-show is recorded only).
- Rating-comment-specific moderation queue (report the user via Plan 9).
- Blind double-reveal (ratings are private; only the aggregate is public).
- Pre-meal T-24h/T-2h reminders (the scheduled infra lands here; those specific reminders stay deferred).

## 11. Delivery

Own plan on branch `feature/plan-10-ratings` (off `develop`), executed subagent-driven. Ordered so the tree stays green: rating model + rules → AppUser rating fields + tightened users rule → rating repo + providers → rating sheet + post-meal card + rating badge + chat wiring → analytics → `onRatingCreated` aggregate Function + pure helper → `postMealReminder` scheduled Function + payload builder → CI/CD (functions already wired; note Blaze+Scheduler) + docs → verify/build/PR to `develop`.
