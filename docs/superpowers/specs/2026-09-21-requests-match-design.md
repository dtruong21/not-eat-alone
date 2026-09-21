# Convyve — Requests & Match Design (Plan 6)

**Date:** 2026-09-21
**Status:** Approved (design), pending implementation plan
**Feature:** The core 1:1 handshake — a guest requests to join an open meal, the host reviews requests in an inbox and approves one, which locks the meal, creates a match, and auto-denies the other pending requests. Built on the clean `meal` and `user` features.

---

## 1. Goal & constraints

Close the discovery loop. A signed-in, onboarded guest opens a meal and taps **Request to join**. The host sees pending requests in a dedicated inbox, opens a requester's profile, and taps **Approve** or **Deny**. Approving one requester atomically locks the meal (`status: matched`, `guestId` set), creates a `matches/{mealId}` doc, and denies every other pending request on that meal (so a second guest is rejected). No Cloud Functions and no new external keys — the approve transition runs as a client-side Firestore transaction on the host's device, which is safe because Firestore rules already restrict meal writes to the host.

Strictly 1:1 (one seat): the first approved request wins; the meal leaves discovery the moment it is `matched` (the Plan 5 feed already filters to `status == open`).

## 2. Feature layout (Pragmatic Clean)

New feature folder `lib/features/matching/` with the standard layers. It reuses the existing `meal` and `user` features (reads meals and user profiles) but owns the request/match model.

```
lib/features/matching/
  domain/
    entities/     join_request.dart, request_status.dart, match.dart
    repositories/ request_repository.dart
  data/
    dtos/         join_request_dto.dart, match_dto.dart
    mappers/      join_request_mapper.dart, match_mapper.dart
    repositories/ request_repository_impl.dart
  application/    request_providers.dart, meal_request_state_provider.dart,
                  create_request_controller.dart, host_inbox_provider.dart,
                  inbox_action_controller.dart
  presentation/   request_inbox_screen.dart, widgets/request_inbox_tile.dart
```

The meal-detail screen (currently in `meal/presentation/`) is modified in place to host the live request button.

## 3. Domain model (pure freezed, no json)

- `request_status.dart` — `enum RequestStatus { pending, approved, denied }`. No `withdrawn` in v1 (guests cannot cancel; YAGNI).
- `join_request.dart`:

  ```dart
  @freezed
  abstract class JoinRequest with _$JoinRequest {
    const factory JoinRequest({
      required String id,          // "${mealId}_${guestId}"
      required String mealId,
      required String guestId,
      required String hostId,      // denormalized from the meal for inbox queries + rules
      @Default(RequestStatus.pending) RequestStatus status,
      DateTime? createdAt,         // serverTimestamp — nullable for optimistic snapshots
    }) = _JoinRequest;
  }
  ```

- `match.dart`:

  ```dart
  @freezed
  abstract class Match with _$Match {
    const factory Match({
      required String id,          // == mealId (one match per meal)
      required String mealId,
      required String hostId,
      required String guestId,
      DateTime? createdAt,         // serverTimestamp
    }) = _Match;
  }
  ```

Both entities are pure — no Firebase/Flutter imports.

## 4. Repository interface (domain)

`domain/repositories/request_repository.dart`:

```dart
abstract class RequestRepository {
  /// Guest creates a pending request for [mealId] hosted by [hostId].
  /// id = "${mealId}_${guestId}"; idempotent (create fails if it already exists).
  Future<void> createRequest({required String mealId, required String hostId});

  /// The guest's own request on a meal (for the meal-detail button state).
  Stream<JoinRequest?> watchRequest({required String mealId, required String guestId});

  /// All pending requests across the host's meals (the inbox), newest first.
  Stream<List<JoinRequest>> watchPendingForHost(String hostId);

  /// Host approves [request]: locks the meal, creates the match, denies siblings.
  /// Throws [MealNoLongerOpenException] if the meal is not `open`.
  Future<void> approve(JoinRequest request);

  /// Host denies a single [request].
  Future<void> deny(JoinRequest request);
}
```

`guestId` for `watchRequest` / `createRequest` is the current auth uid, supplied by the application layer (`firebase_auth` stays out of domain).

## 5. Data layer

- `data/dtos/` — `JoinRequestDto` and `MatchDto` are freezed + json_serializable. `RequestStatus` serializes as its `.name` string. `Timestamp` ↔ `DateTime` handled in the mapper (`.toDate().toUtc()` on read, `FieldValue.serverTimestamp()` on write), mirroring `app_user_mapper` / `meal` conventions. Mapper parse failures throw the shared `RepositoryParseException`; writes throw `RepositoryWriteException`.
- `data/repositories/request_repository_impl.dart` — the only place in this feature that imports `cloud_firestore`. Uses the flavor-aware `db` handle from `core/firebase/firebase_client.dart`.

  - `createRequest` — writes `requests/{mealId}_{guestId}` with `{ mealId, guestId, hostId, status: 'pending', createdAt: serverTimestamp }` using `set` with an existence guard is unnecessary; use a plain `set` (idempotent by fixed id — re-requesting a still-pending meal just rewrites the same pending doc; rules block writes once the meal is not `open`).
  - `watchRequest` — `requests/{mealId}_{guestId}`.snapshots() → `JoinRequest?` (null when absent).
  - `watchPendingForHost` — `requests` where `hostId == host` and `status == 'pending'`, `orderBy createdAt desc`.
  - `approve(request)` — a `db.runTransaction`:
    1. Read `meals/{request.mealId}`. If missing or `status != 'open'`, throw `MealNoLongerOpenException`.
    2. Update the meal: `status = 'matched'`, `guestId = request.guestId`.
    3. Update `requests/{request.id}`: `status = 'approved'`.
    4. Create `matches/{request.mealId}`: `{ mealId, hostId: request.hostId, guestId: request.guestId, createdAt: serverTimestamp }`.

    After the transaction commits, a follow-up query+batch denies the losers: `requests` where `mealId == request.mealId` and `status == 'pending'`, set each (except the approved one) to `denied`. (Firestore transactions cannot run queries, so this is a post-commit `WriteBatch`; the meal is already `matched`, so no new pending requests can appear — rules block them.)
  - `deny(request)` — update `requests/{request.id}`: `status = 'denied'`.

- `MealNoLongerOpenException` — a typed exception in this feature's data layer (or reuse the shared repository-exception module), surfaced to the inbox controller so the host sees "This meal is no longer open."

## 6. Firestore rules

Add to `firebase/firestore.rules` (deploy to both `(default)` and `stage`):

```
match /requests/{requestId} {
  allow read: if isSignedIn()
              && (resource.data.guestId == request.auth.uid
                  || resource.data.hostId == request.auth.uid);
  allow create: if isSignedIn()
                && request.resource.data.guestId == request.auth.uid
                && request.resource.data.status == 'pending'
                && request.resource.data.hostId != request.auth.uid            // can't request own meal
                && exists(/databases/$(database)/documents/meals/$(request.resource.data.mealId))
                && get(/databases/$(database)/documents/meals/$(request.resource.data.mealId)).data.status == 'open'
                && get(/databases/$(database)/documents/meals/$(request.resource.data.mealId)).data.hostId == request.resource.data.hostId;
  allow update: if isSignedIn()
                && resource.data.hostId == request.auth.uid
                && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status']);
  allow delete: if false;
}

match /matches/{matchId} {
  allow read: if isSignedIn()
              && (resource.data.hostId == request.auth.uid
                  || resource.data.guestId == request.auth.uid);
  allow create: if isSignedIn()
                && request.resource.data.hostId == request.auth.uid;
  allow update, delete: if false;
}
```

The existing `meals/{mealId}` update rule (host-only) already permits the transaction's meal write; no change there. The guest never writes the meal.

New composite index in `firebase/firestore.indexes.json`: `requests` collection, fields `hostId` (asc) + `status` (asc) + `createdAt` (desc).

## 7. Application (Riverpod)

- `request_providers.dart` — `requestRepositoryProvider` binds `RequestRepositoryImpl` to the interface.
- `meal_request_state_provider.dart` — `mealRequestStateProvider = StreamProvider.family<JoinRequest?, String>` keyed by `mealId`; reads the current uid from the auth provider and calls `watchRequest`. Drives the meal-detail button. (Returns null / a default for a signed-out edge, but discovery is behind the onboarded redirect so a uid is always present.)
- `create_request_controller.dart` — `AsyncNotifier` with `request(Meal meal)`: calls `createRequest(mealId: meal.id, hostId: meal.hostId)`, fires `join_requested` (prop `women_only`) on success.
- `host_inbox_provider.dart` — `hostInboxProvider = StreamProvider<List<JoinRequest>>` → `watchPendingForHost(myUid)`. A derived `pendingRequestCountProvider` (int) for the discovery badge.
- `inbox_action_controller.dart` — `AsyncNotifier` with `approve(JoinRequest)` and `deny(JoinRequest)`; fires `request_approved` + `match_created` (approve) or `request_denied` (deny). Surfaces `MealNoLongerOpenException` as an error state.
- Guest profiles for inbox tiles reuse the `user` feature: a `userDocProvider` family (`StreamProvider.family<AppUser?, String>` over `UserRepository.watch(uid)`) — add it to the `user` feature's application layer if not already present.

Analytics is fired via the typed registry in `lib/core/analytics/`; keep `analytics.track` calls consistent with the existing deferral (outside the write's `AsyncValue.guard` when the real backend lands — same note as Plan 4/5).

## 8. Presentation

- `meal/presentation/meal_detail_screen.dart` (modified) — replace the disabled "Request to join" stub with a live control driven by `mealRequestStateProvider(meal.id)`:
  - no request → **Request to join** button (calls `createRequestController.request(meal)`); shows loading while writing.
  - `pending` → **Requested** (disabled, with a subtle "waiting for host" hint).
  - `approved` → a **Matched!** banner ("You're in — chat coming soon" placeholder for Plan 7).
  - `denied` → **Not selected** (terminal; button stays disabled, no re-request in v1).
  - Also hide/disable the button when the viewer is the host of that meal (a host doesn't request their own meal).
  - All `AsyncValue` states rendered (loading/error/data).
- `matching/presentation/request_inbox_screen.dart` — route `/requests`. Consumes `hostInboxProvider`:
  - loading / error / empty ("No pending requests") / list states.
  - each row = `request_inbox_tile.dart`: guest photo, display name, derived age (via the `userDoc` family), plus **Approve** and **Deny** buttons wired to `inboxActionController`. On approve success the tile leaves the list (the request is no longer pending); on `MealNoLongerOpenException` show a snackbar and let the stream drop it.
- `meal/presentation/discovery_screen.dart` (modified) — add an inbox action to the app bar: an icon that routes to `/requests`, with a count badge from `pendingRequestCountProvider` (hidden at 0).

Tokens for all colors/spacing/type (warm-playful); no magic numbers.

## 9. Analytics

Declared in `lib/core/analytics/events.dart` + mirrored in `docs/TRACKING-PLAN.md`, no PII:

- `join_requested` (props: `women_only` bool)
- `request_approved`
- `request_denied`
- `match_created` (props: `women_only` bool)

## 10. Routing

- Add `/requests` → `RequestInboxScreen`. Behind the existing fully-onboarded redirect (no new redirect state). Keep all Plan 4/5 routes.
- The `authRedirect` literal-path guards are unchanged (`/requests` is a normal in-app route, not an auth/onboarding path).

## 11. Testing

- Entities: `JoinRequest` / `Match` construction; `RequestStatus` name serialization; DTO round-trip (incl. null `createdAt`).
- `RequestRepositoryImpl` (fake_cloud_firestore):
  - `createRequest` writes a pending doc at the composite id with denormalized `hostId`.
  - `watchRequest` streams the guest's doc (and null when absent).
  - `watchPendingForHost` returns only this host's pending requests, newest first.
  - `approve` — meal flips to `matched` + `guestId`; `matches/{mealId}` created; the approved request is `approved`; **a second still-pending request on the same meal becomes `denied`** (the rejection criterion); a pending request on a *different* meal is untouched.
  - `approve` on a meal already `matched`/not `open` throws `MealNoLongerOpenException` and writes nothing.
  - `deny` sets a single request to `denied`, leaves the meal `open`.
- Controllers: `createRequestController.request` fires `join_requested`; `inboxActionController.approve` fires `request_approved` + `match_created`; `deny` fires `request_denied`; approve error surfaces without firing success events.
- Screens (widget, overridden providers): meal-detail renders each of the four button states + the host-viewing-own-meal case; inbox renders tiles, approve removes a tile, empty/error states; discovery badge shows the pending count and hides at 0.
- Rules (manual / emulator note in TEST-PLAN): a guest cannot create a request on a non-`open` meal or on their own meal; a non-host cannot update a request; both parties can read the match, a third user cannot.

## 12. Non-goals (deferred)

- Chat on a match + a matches-list screen (Plan 7) — the `matches/{mealId}` doc is created here purely so Plan 7 can consume it.
- Push notifications for new request / approve / deny (Plan 8).
- Guest withdrawing a request; host cancelling a meal or un-matching.
- Re-requesting after a denial (denied is terminal per meal/guest in v1).
- Moving the approve transition into a Cloud Function (safety-phase hardening — the client transaction is rules-guarded, but a Function would also protect the "deny siblings" batch from a host that quits mid-flight).
- Multi-seat / group meals.

## 13. Delivery

Own plan on branch `plan-6-requests` (off `main`, already checked out), executed subagent-driven. Ordered so the tree stays green: domain (entities + repo interface) → DTOs + mappers → repository impl (create/watch/deny) → approve transaction + sibling-deny → rules + index + deploy → providers + controllers + analytics → meal-detail button + inbox screen + discovery badge + routing → verify/build/PR.
