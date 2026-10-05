# Convyve — Inbox Feedback (Plan 14)

**Date:** 2026-10-05
**Status:** Draft, pending approval
**Feature:** Make the host's request inbox honest. The host sees which meal each request is for, can tell when its meal time has passed (Approve is disabled, Deny stays), and always gets feedback when an Approve or Deny succeeds or fails.

---

## 1. Problems

Found while closing the meal-lifecycle rules (Plan 13), all in `RequestInboxTile` / `InboxActionController`:

1. **Failures are swallowed.** `_approve` shows a snackbar only for `MealNoLongerOpenException`; every other error (a stale tile, the new "decided once" rule, a past meal, offline) is dropped. `_deny` ignores the result entirely. The tile just does nothing.
2. **No success feedback.** After Approve the tile silently disappears; the host isn't told a chat now exists or how to reach it.
3. **No meal context.** A tile shows only the guest's name and age. A host with several meals can't tell which one a request is for.
4. **Requests on a meal that has already started** are still shown as actionable. The rules now reject approving them (and creating them), so the host taps Approve and gets nothing (problem 1).

## 2. Design

### 2.1 Meal context on the tile

A new provider in `matching/application`:

```dart
/// The meal a request is for (null if missing). One cached fetch per meal id.
final requestMealProvider = FutureProvider.family<Meal?, String>(
  (ref, mealId) => ref.watch(mealRepositoryProvider).getMeal(mealId),
);
```

The tile watches `requestMealProvider(request.mealId)` and, when it has data, shows a second line under the guest's label: the restaurant name and the meal's date and time. Loading and error render nothing extra (the tile works exactly as today; the server rules remain the source of truth). The date/time formatting reuses the existing helper used by Discover/meal detail if it can be shared without a layering violation; otherwise a small shared formatter in `core/util/`.

### 2.2 Past meals

When the loaded meal's `dateTime` is before now:

- a chip "Meal time has passed" replaces the meal line's emphasis;
- **Approve is disabled** (the rules reject it anyway);
- **Deny stays enabled** so the host can clear the request.

The check uses the device clock; the server clock is authoritative, so a request right at the boundary can still fail with the generic message below. No hiding: marked and clearable is simpler and keeps the badge count (`pendingRequestCountProvider`) truthful about what is actually in the inbox.

### 2.3 Outcome feedback

`InboxActionController.deny` returns the outcome like `approve` already does (`Future<Object?>`: the error or `null`), so the tile never re-reads state after the await (the unmount-after-await rule from Plan 12/13: capture `ScaffoldMessenger` and `GoRouter` before the await; use only captured objects afterwards).

A pure function maps an outcome to a message, with unit tests:

| Action | Outcome | Snackbar |
|---|---|---|
| Approve | success | "Approved. You can chat now." with action **Chat** (opens `/chats/{mealId}`) |
| Approve | `MealNoLongerOpenException` | "This meal is no longer open." (unchanged) |
| Approve | any other error | "Couldn't approve this request. It may already have been handled." |
| Deny | success | "Request denied." |
| Deny | any error | "Couldn't deny this request. It may already have been handled." |

One generic wording for "other error" is deliberate: the app layer can't distinguish permission-denied reasons (already decided, past meal, offline) without leaking Firebase types upward, and all of them mean "nothing changed; the list will refresh". No new repository exception types.

### 2.4 Out of scope

- Hiding requests whose meal passed, or server-side expiry (a scheduled function that denies stale requests): possible later; this plan only marks them.
- Excluding past requests from the app-bar badge count.
- The picker/rate-button clock-skew items and the cancel-meal function from the Plan 13 follow-ups.
- Analytics: no new events (`request_approved` / `request_denied` fire as today).

## 3. Tests

**Unit (`test/`)**
- The outcome → message mapping, every row of §2.3.
- `InboxActionController.deny` returns `null` on success and the error on failure; `keepAlive` behaviour unchanged.
- `requestMealProvider` delegates to `MealRepository.getMeal`.

**Widget (`test/features/matching/presentation/widgets/request_inbox_tile_test.dart`)**
- Meal line renders restaurant + date/time when the meal loads; nothing extra while loading/on error/null.
- Past meal: chip shown, Approve disabled, Deny enabled.
- Approve success snackbar with the Chat action; Chat action navigates (use the existing router test pattern).
- Approve failure (generic) and `MealNoLongerOpenException` snackbars; Deny success and failure snackbars.
- Unmount mid-flight: the tile is removed while the action is in flight; no exception, the snackbar still shows (regression test for the ref-after-await class).

**E2E (`integration_test/inbox_feedback_test.dart`, real UI + rules)**
- A pending request on a past, still-open meal (seeded with the admin helpers): the inbox shows the "Meal time has passed" chip with Approve disabled; Deny works and the tile disappears with the "Request denied." snackbar.
- A normal request on a future meal: the tile shows the restaurant name and date; Approve succeeds, the "Approved" snackbar appears, and the Chat action opens the chat.

## 4. Risks

- **Extra read per tile.** One cached `getMeal` per distinct meal id; `FutureProvider.family` caches per id. Acceptable at inbox sizes.
- **Boundary clock skew** between device and server: covered by the generic failure message, same limitation as the rate button.
- **Navigation in a snackbar action** from a tile that may unmount: use the captured `GoRouter`, as the earlier regression tests establish.

## 5. Delivery

Branch `feature/inbox-feedback` off `develop`, subagent-driven, merged to `develop` only. Order keeps the tree green: pure message mapping + controller return type + provider (unit-tested) → tile UI + widget tests → E2E scenario → docs/changelog (remove the now-fixed items from the TEST-PLAN follow-ups).
