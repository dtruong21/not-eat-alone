## [P2] Discovery feed never drops a meal whose time passes, downloads every historical open meal, and nobody can cancel or expire a meal

**Repro:**
1. Open Discover with a meal starting in a few minutes; leave the screen open past the start time without pulling to refresh. The meal stays listed (and "Request to join" is rejected by the rules once it is past).
2. Create meals that nobody requests (or whose host never matches). They keep `status == 'open'` forever.
3. Inspect `MealRepositoryImpl.watchDiscoverable`: the query is `status == 'open'` plus the geohash prefix range only.

**Expected:** (edge cases 3 and 6) "Today's" feed advances without a manual refresh; the query cost does not grow with every meal ever created; a host can cancel their own meal and unmatched meals expire.
**Actual:** `discovery_controller.dart` evaluates `DateTime.now()` only inside the stream `map`, i.e. only when Firestore emits (test shows the stale entry). Expired `open` meals are never closed (`postMealReminder` only completes `matched` meals), the geohash prefix is precision 3 (all of Ile-de-France), and the stream has no `limit`/`dateTime` bound, so every client's listener downloads every past open meal of the region on each cold start and each is filtered in Dart (reads and cold-start time grow without bound). Separately the `meals` rules forbid client deletes and no cancel function exists (`MealStatus.cancelled` is never written; TEST-PLAN lists it as a deferred follow-up), so hosts and matched guests have no way to withdraw, the main no-show lever for the "low-pressure" pillar. The `discovery_viewed` event also fires on every emission (blocked-list change, snapshot), over-counting.

**Device/OS:** unit test harness (Flutter 3.47.4); query cost analysed from code/rules.
**Build:** develop @ 8cf1b41
**Frequency:** always.

**Hypothesis:** (1) Add a scheduled function that sets `status: 'expired'` (or deletes) `open` meals whose `dateTime` passed (the existing `status+dateTime` index serves it). (2) In the controller re-filter on a `Timer.periodic(1 min)` tick or schedule a refresh at the earliest listed `dateTime`. (3) Add a `cancelMeal` callable (host: open or matched; guest: withdraw) that also notifies the other side.

**Regression tests:** `test/features/meal/application/discovery_clock_edge_test.dart` ("a listed meal is dropped once its start time passes" skipped until fixed; 300-meal mapping test passes).
