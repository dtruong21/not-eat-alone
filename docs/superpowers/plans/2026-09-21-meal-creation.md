# Convyve — Plan 4: Meal Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A host can search a Paris restaurant (list view, fake provider — no Google key yet), set date/time + optional note + women-only, and create a `meals/{id}` document; the create-meal flow builds and tests without any Maps/Places key.

**Architecture:** New clean `meal` feature. Restaurants come from a `RestaurantSearchRepository` interface backed by a fake curated-Paris datasource (real Places impl deferred to a later keyed task). Meals persist via `MealRepository`/`MealRepositoryImpl` (Firestore `meals` collection, flavor-aware `db`), with a `geohash` computed by a pure helper for Plan 5 discovery. No map widget (list-first; map preview is deferred).

**Tech Stack:** Flutter 3.47.4 (FVM), Riverpod, freezed 4, cloud_firestore, go_router, mocktail, fake_cloud_firestore. **No new external deps** (geohash is a pure helper; no Places/Maps packages).

**Base branch:** `plan-3-profile` (this branch, `plan-4-meal`, is stacked on it).

## Global Constraints

- Flutter 3.47.4 via FVM — all commands `fvm flutter`/`fvm dart` (PATH += `$HOME/.pub-cache/bin`).
- **Clean Architecture** (MASTER-SPEC §2a): `presentation → application → domain ← data`; `domain/` has ZERO Flutter/Firebase imports; `cloud_firestore` only in `data/`.
- Entities = pure freezed (no json); DTOs = freezed + json in `data/dtos/`; mapping via extension methods in `data/mappers/`.
- Codegen gitignored — `fvm dart run build_runner build --delete-conflicting-outputs`; don't commit generated.
- `package:` imports only; typed exceptions in data repos; flavor-aware `db`.
- Analytics events declared in `lib/core/analytics/events.dart` + `docs/TRACKING-PLAN.md` before firing; no PII.
- Every `AsyncValue` consumer renders loading/error/data; tokens for all styling.
- Field rules: `seats` fixed 1; `note` ≤200; `status` default `open`; `womenOnly` default false; `geohash` precision 9.
- **No Google Maps/Places dependency or key** in this plan.
- Verify each task: `fvm flutter analyze --no-fatal-infos` = 0, `fvm flutter test --concurrency=1` all pass (`--concurrency=1` — parallel reporter garbles logs here).
- Commit messages end with a blank line then `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

### Task 1: `encodeGeohash` pure helper

**Files:** Create `lib/core/util/geohash.dart`; Test `test/core/util/geohash_test.dart`

**Interfaces:** Produces `String encodeGeohash(double lat, double lng, {int precision = 9})`.

- [ ] **Step 1: Failing test** — `test/core/util/geohash_test.dart` (canonical Wikipedia reference: 57.64911, 10.40744 → `u4pruydqqvj`):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/geohash.dart';

void main() {
  test('encodes the canonical reference point', () {
    expect(encodeGeohash(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
  });
  test('default precision is 9', () {
    expect(encodeGeohash(57.64911, 10.40744).length, 9);
    expect(encodeGeohash(57.64911, 10.40744), 'u4pruydqq');
  });
  test('prefix property: nearby points share a prefix', () {
    final a = encodeGeohash(48.8584, 2.2945); // Eiffel Tower
    final b = encodeGeohash(48.8600, 2.2950); // ~200m away
    expect(a.substring(0, 5), b.substring(0, 5));
  });
}
```

- [ ] **Step 2: Run, verify FAIL** — `fvm flutter test test/core/util/geohash_test.dart`.

- [ ] **Step 3: Implement** — `lib/core/util/geohash.dart`:
```dart
const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Standard base-32 geohash encoding of [lat]/[lng]. Nearby points share a
/// common prefix — used for proximity queries (Plan 5 discovery).
String encodeGeohash(double lat, double lng, {int precision = 9}) {
  var latMin = -90.0, latMax = 90.0;
  var lngMin = -180.0, lngMax = 180.0;
  final hash = StringBuffer();
  var isEven = true;
  var bit = 0;
  var ch = 0;
  while (hash.length < precision) {
    if (isEven) {
      final mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch |= 1 << (4 - bit);
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch |= 1 << (4 - bit);
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    isEven = !isEven;
    if (bit < 4) {
      bit++;
    } else {
      hash.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return hash.toString();
}
```

- [ ] **Step 4: Run, verify PASS.** — `fvm flutter test test/core/util/geohash_test.dart`.

- [ ] **Step 5: Verify + commit**
```bash
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add lib/core/util/geohash.dart test/core/util/geohash_test.dart
git commit -m "feat(meal): pure geohash encoder"
```

---

### Task 2: `meal` domain (entities + repository interfaces)

**Files:**
- Create: `lib/features/meal/domain/entities/restaurant.dart`, `.../meal_status.dart`, `.../meal.dart`, `lib/features/meal/domain/repositories/restaurant_search_repository.dart`, `.../meal_repository.dart`
- Test: `test/features/meal/domain/meal_test.dart`

**Interfaces:** Produces `Restaurant`, `MealStatus`, `Meal` (pure freezed) and the two abstract repositories.

- [ ] **Step 1: Restaurant** — `restaurant.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'restaurant.freezed.dart';

@freezed
abstract class Restaurant with _$Restaurant {
  const factory Restaurant({
    required String placeId,
    required String name,
    required String address,
    required double lat,
    required double lng,
  }) = _Restaurant;
}
```

- [ ] **Step 2: MealStatus** — `meal_status.dart`: `enum MealStatus { open, matched, completed, cancelled }`.

- [ ] **Step 3: Meal** — `meal.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal_status.dart';
import 'package:not_eat_alone/features/meal/domain/entities/restaurant.dart';
part 'meal.freezed.dart';

@freezed
abstract class Meal with _$Meal {
  const factory Meal({
    required String id,
    required String hostId,
    required Restaurant restaurant,
    required DateTime dateTime,
    required String geohash,
    String? note,
    @Default(false) bool womenOnly,
    @Default(1) int seats,
    @Default(MealStatus.open) MealStatus status,
    String? guestId,
    DateTime? createdAt,
  }) = _Meal;
}
```

- [ ] **Step 4: Repositories** — pure interfaces (import only entities):
`restaurant_search_repository.dart`: `abstract class RestaurantSearchRepository { Future<List<Restaurant>> search(String query); }`
`meal_repository.dart`: `abstract class MealRepository { Future<String> createMeal(Meal meal); }`

- [ ] **Step 5: Entity test + codegen** — `test/features/meal/domain/meal_test.dart`: build a `Meal` with a `Restaurant`, assert defaults (`womenOnly == false`, `seats == 1`, `status == MealStatus.open`) + `copyWith`. Run `fvm dart run build_runner build --delete-conflicting-outputs` then the test → PASS.

- [ ] **Step 6: Verify + commit**
```bash
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add lib/features/meal/domain test/features/meal/domain
git commit -m "feat(meal): domain entities (Restaurant/Meal/MealStatus) + repo interfaces"
```

---

### Task 3: Fake restaurant search datasource + provider

**Files:**
- Create: `lib/features/meal/data/datasources/fake_restaurant_search_datasource.dart`, `lib/features/meal/application/restaurant_providers.dart`
- Test: `test/features/meal/data/fake_restaurant_search_datasource_test.dart`

**Interfaces:** Produces `FakeRestaurantSearchDataSource implements RestaurantSearchRepository` and `restaurantSearchRepositoryProvider = Provider<RestaurantSearchRepository>(...)`.

- [ ] **Step 1: Fake datasource** — `fake_restaurant_search_datasource.dart`: a `class FakeRestaurantSearchDataSource implements RestaurantSearchRepository` holding a `static const` (or final) list of ~15–20 real Paris restaurants as `Restaurant` objects (distinct `placeId`s like `'fake_001'`, real-ish names/addresses/`lat`/`lng` around Paris). `search(query)`: trim + lowercase; empty → return the full list; else filter where `name` or `address` (lowercased) contains the query. (This is the DATA layer, but it has NO firebase import — it's an in-memory stand-in for the future Places datasource.)

- [ ] **Step 2: Provider** — `restaurant_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/meal/data/datasources/fake_restaurant_search_datasource.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/restaurant_search_repository.dart';

final restaurantSearchRepositoryProvider =
    Provider<RestaurantSearchRepository>((ref) => FakeRestaurantSearchDataSource());
```

- [ ] **Step 3: Test** — `fake_restaurant_search_datasource_test.dart`: empty query → full list (length > 10); a query matching a known name → contains that restaurant; a nonsense query → empty; case-insensitive.

- [ ] **Step 4: Verify + commit**
```bash
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add lib/features/meal/data/datasources lib/features/meal/application/restaurant_providers.dart test/features/meal/data/fake_restaurant_search_datasource_test.dart
git commit -m "feat(meal): fake Paris restaurant search datasource + provider"
```

---

### Task 4: Meal DTO/mapper + `MealRepositoryImpl` + rules

**Files:**
- Create: `lib/features/meal/data/dtos/meal_dto.dart` (+ nested restaurant), `lib/features/meal/data/mappers/meal_mapper.dart`, `lib/features/meal/data/repositories/meal_repository_impl.dart`, `lib/features/meal/application/meal_providers.dart`
- Modify: `firebase/firestore.rules`
- Test: `test/features/meal/data/meal_mapper_test.dart`, `test/features/meal/data/meal_repository_impl_test.dart`

**Interfaces:** Produces `MealDto` (+ `RestaurantDto`), mappers, `MealRepositoryImpl implements MealRepository`, `mealRepositoryProvider = Provider<MealRepository>((ref) => MealRepositoryImpl())`.

- [ ] **Step 1: DTOs** — `meal_dto.dart`: a `MealDto` (freezed+json) with `id`, `hostId`, `restaurant` (a nested `RestaurantDto` with placeId/name/address/lat/lng), `dateTime`, `geohash`, `note`, `womenOnly`, `seats`, `status` (String — `MealStatus.name`), `guestId`, `createdAt`. `dateTime`/`createdAt` handled as `Timestamp`↔`DateTime` (UTC-normalized) in the repo's converter (same pattern as `AppUserDto`/user repo).

- [ ] **Step 2: Mapper** — `meal_mapper.dart`: extensions `MealDto.toEntity()` (status String→`MealStatus.values.byName`, guarded → `MealStatus.open` on unknown; nested restaurant → `Restaurant`) and `Meal.toDto()`.

- [ ] **Step 3: Repo impl** — `meal_repository_impl.dart`: `createMeal(meal)`: ensure `geohash` (if the passed meal's geohash is empty, compute `encodeGeohash(meal.restaurant.lat, meal.restaurant.lng)`); create a new doc on `db.collection('meals')` (auto-id), writing the DTO map with `createdAt = FieldValue.serverTimestamp()` and `dateTime`/nested restaurant serialized; set the doc's `id` field to the generated id; return the id. Wrap failures in `RepositoryWriteException`. Constructor injects `FirebaseFirestore?` (default `db`).

- [ ] **Step 4: Rules** — in `firebase/firestore.rules`, add inside the documents match:
```
match /meals/{mealId} {
  allow create: if isSignedIn()
                && request.resource.data.hostId == request.auth.uid
                && request.resource.data.status is string
                && request.resource.data.geohash is string
                && request.resource.data.dateTime is timestamp;
  allow read, update, delete: if isSignedIn() && resource.data.hostId == request.auth.uid;
  // Plan 5 (discovery) will broaden `read` to any signed-in user.
}
```
Deploy: `firebase deploy --only firestore --project not-eat-alone` (both databases via the array config). Capture output.

- [ ] **Step 5: Tests** — `meal_mapper_test.dart`: DTO↔entity round-trip incl. nested restaurant + status enum + unknown-status→open guard. `meal_repository_impl_test.dart` (fake_cloud_firestore): `createMeal(meal with empty geohash)` → a doc exists in `meals` with a non-empty geohash, `hostId`, `status:'open'`, the id field set, and returns that id; a meal with womenOnly true persists it.

- [ ] **Step 6: Provider** — `meal_providers.dart`: `final mealRepositoryProvider = Provider<MealRepository>((ref) => MealRepositoryImpl());`

- [ ] **Step 7: Verify + commit**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add lib/features/meal/data lib/features/meal/application/meal_providers.dart firebase/firestore.rules test/features/meal/data
git commit -m "feat(meal): meal DTO/mapper, repository impl, meals firestore rules"
```

---

### Task 5: Controllers + analytics

**Files:**
- Create: `lib/features/meal/application/restaurant_search_controller.dart`, `lib/features/meal/application/create_meal_controller.dart`
- Modify: `lib/core/analytics/events.dart`, `docs/TRACKING-PLAN.md`
- Test: `test/features/meal/application/restaurant_search_controller_test.dart`, `test/features/meal/application/create_meal_controller_test.dart`

**Interfaces:** Produces `restaurantSearchControllerProvider` (`AsyncNotifier<List<Restaurant>>` with `search(query)`) and `createMealControllerProvider` (`AsyncNotifier<void>` with `create({required Restaurant restaurant, required DateTime dateTime, String? note, required bool womenOnly})`). Events `MealCreated({required bool womenOnly})`, `RestaurantSelected()`.

- [ ] **Step 1: Analytics** — add `RestaurantSelected()` (`restaurant_selected`, props `{}`) and `MealCreated({required bool womenOnly})` (`meal_created`, props `{'women_only': womenOnly}`) to `events.dart`; mirror in `docs/TRACKING-PLAN.md`. No PII.

- [ ] **Step 2: Search controller** — `restaurant_search_controller.dart` (`AsyncNotifier<List<Restaurant>>`): `build()` returns the full list (`ref.read(restaurantSearchRepositoryProvider).search('')`); `search(query)` → `AsyncValue.guard(() => repo.search(query))` into state.

- [ ] **Step 3: Create controller** — `create_meal_controller.dart` (`AsyncNotifier<void>`): `create({restaurant, dateTime, note, womenOnly})` → uid from `ref.read(authRepositoryProvider).currentUser!.uid`; build a `Meal(id: '', hostId: uid, restaurant: restaurant, dateTime: dateTime, geohash: '', note: note, womenOnly: womenOnly)` (repo fills geohash + id); `await ref.read(mealRepositoryProvider).createMeal(meal)`; fire `MealCreated(womenOnly: womenOnly)`. `AsyncValue.guard` for loading/error.

- [ ] **Step 4: Tests** — search controller: `search('nonsense')` → empty state; `search('')` → full list. create controller (mocktail: `mealRepositoryProvider`, `authRepositoryProvider` currentUser→`AuthUser(uid:'h1')`): `create(...)` → `mealRepository.createMeal` called with a Meal whose `hostId=='h1'`, `womenOnly` as passed; `meal_created` fired with the right `women_only` prop.

- [ ] **Step 5: Verify + commit**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add lib/features/meal/application lib/core/analytics/events.dart docs/TRACKING-PLAN.md test/features/meal/application
git commit -m "feat(meal): restaurant-search + create-meal controllers + analytics"
```

---

### Task 6: Screens + home entry

**Files:**
- Create: `lib/features/meal/presentation/restaurant_search_screen.dart`, `lib/features/meal/presentation/create_meal_screen.dart`
- Modify: `lib/features/home/placeholder_home.dart`
- Test: `test/features/meal/presentation/restaurant_search_screen_test.dart`, `test/features/meal/presentation/create_meal_screen_test.dart`

**Interfaces:** Consumes the controllers + `image`-free list UI. `CreateMealScreen` receives the picked `Restaurant`.

- [ ] **Step 1: Restaurant search screen** — `restaurant_search_screen.dart` (list view): a search `TextField` (debounced or on-submit) that calls `restaurantSearchControllerProvider.notifier.search(q)`; a `ListView` of results (`name` + `address` rows); tapping a row fires `RestaurantSelected` and navigates to `/meals/new/details` passing the `Restaurant` via `extra`. Tokens; loading/error/empty states.

- [ ] **Step 2: Create-meal screen** — `create_meal_screen.dart`: reads the `Restaurant` from route `extra`; shows a restaurant card (name/address), a date/time picker (future dates only), an optional note field (≤200), a women-only `Switch`, and a "Create meal" button → `createMealControllerProvider.notifier.create(...)`; on success show a confirmation + pop to home; render loading/error. Tokens.

- [ ] **Step 3: Home entry** — in `placeholder_home.dart`, add a "Create a meal" button (e.g. a `FloatingActionButton` or primary button) that navigates to `/meals/new`. Keep the existing sign-out action.

- [ ] **Step 4: Widget tests** — search screen: results render from an overridden controller; tapping a row navigates (assert via a router/nav mock or a pushed route). create screen: with a Restaurant + a chosen date + tapping create → `create(...)` called with the right args. Override providers with mocktail; use a testable date hook if the native picker is awkward.

- [ ] **Step 5: Verify + commit**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add lib/features/meal/presentation lib/features/home/placeholder_home.dart test/features/meal/presentation
git commit -m "feat(meal): restaurant search + create-meal screens + home entry"
```

---

### Task 7: Routing

**Files:** Modify `lib/core/routing/router.dart`; Test `test/core/routing/redirect_test.dart` (only if a guard changes — it should NOT)

**Interfaces:** Adds routes `/meals/new` → `RestaurantSearchScreen`, `/meals/new/details` → `CreateMealScreen` (restaurant via `extra`).

- [ ] **Step 1: Add routes** — in `router.dart`, add the two `GoRoute`s under the authed area. `/meals/new/details`'s builder reads `state.extra as Restaurant` (guard: if `extra` is null — deep-link / restart — redirect to `/meals/new`). `authRedirect` is UNCHANGED (these are normal authed routes; the existing redirect already funnels unauthed/incomplete users to signin/age/profile). Confirm the redirect still returns null for a fully-onboarded user on `/meals/new` (it's not in the auth/onboarding set) — if the final home-redirect branch would bounce it, ensure `/meals/**` is treated as a normal in-app route (not redirected).

- [ ] **Step 2: Verify** — `fvm flutter test --concurrency=1` (redirect tests still green — a fully-onboarded user on `/meals/new` stays), `fvm flutter analyze --no-fatal-infos` (0).

- [ ] **Step 3: Commit**
```bash
git add lib/core/routing/router.dart test/core/routing/redirect_test.dart
git commit -m "feat(meal): routes for restaurant search + create meal"
```

---

### Task 8: Verify, build, PR

- [ ] **Step 1: Full suite** — `fvm dart run build_runner build --delete-conflicting-outputs`, `fvm flutter analyze --no-fatal-infos` (0), `fvm flutter test --concurrency=1` (all pass).
- [ ] **Step 2: Build both flavors** — `fvm flutter build apk --debug --flavor stage -t lib/main_stage.dart` and prod; both succeed.
- [ ] **Step 3: Smoke (coordinator)** — build+launch stage on the iOS Simulator; from home tap "Create a meal" → search list → pick → details → create; confirm a `meals` doc is written (needs a signed-in session — document what was exercised). Update `docs/TEST-PLAN.md` with a Meal-creation checklist.
- [ ] **Step 4: PR**
```bash
git push -u origin plan-4-meal
gh pr create --base plan-3-profile --head plan-4-meal --title "Plan 4: meal creation" --body "<summary>"
```
(End the PR body with a blank line then `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.)

---

## Self-review notes

- **Spec coverage:** domain (§2 → Task 2); geohash (§3 → Task 1); fake datasource (§4 → Task 3); DTO/mapper/repo/rules (§4/§5 → Task 4); controllers/analytics (§6/§7 → Task 5); screens + home entry (§6 → Task 6); routing (§8 → Task 7); testing (§9 → per task); non-goals (§10 → respected: no Places/Maps dep, no join/match, no discovery query, no map widget). ✔
- **Ordering (green between tasks):** helper → domain (additive) → fake datasource+provider (additive) → DTO/repo/rules (additive) → controllers+analytics (additive) → screens+home entry (additive; screens reachable only after Task 7) → routing (wires the entry) → verify/PR.
- **Type consistency:** `Restaurant`/`Meal`/`MealStatus` across entity/DTO/mapper/repo/controller/screens; `encodeGeohash` used in the repo impl (Task 4) exactly as defined (Task 1); `RestaurantSearchRepository`/`MealRepository` interfaces bound to fake datasource / impl in providers; `createMeal(Meal) → Future<String>` identical in Tasks 4/5.
- **Placeholder scan:** none — geohash code, rules, entities, and provider snippets are concrete. UI screens specify structure + tests without pasting full widget trees (consistent with prior plans).
- **No-key adherence:** no `google_maps_flutter`/Places dependency anywhere; restaurants are the fake datasource; map preview explicitly deferred.
