# Convyve — Meal Creation Design (Plan 4)

**Date:** 2026-09-21
**Status:** Approved (design), pending implementation plan
**Feature:** Host a meal — pick a restaurant (list search) + set time/note/women-only + create the meal doc. Built as a new clean `meal` feature. **No Places/Maps API key yet** — restaurants come from a fake provider behind an interface; the real Places API + map preview are a deferred keyed task.

---

## 1. Goal & constraint

A host can search a Paris restaurant (from a **list view**, backed by a fake provider), set date/time + an optional note + a women-only toggle, and create a `meals/{id}` document. The whole flow builds and tests now without any Google API key. The real Places-API restaurant source and a map preview swap in later (one datasource + one screen addition) once the key exists.

## 2. Domain (clean `meal` feature)

- `meal/domain/entities/restaurant.dart` — `Restaurant({ String placeId, String name, String address, double lat, double lng })` (pure value object).
- `meal/domain/entities/meal_status.dart` — `enum MealStatus { open, matched, completed, cancelled }`.
- `meal/domain/entities/meal.dart` — pure entity:
  `Meal({ String id, String hostId, Restaurant restaurant, DateTime dateTime, String? note, bool womenOnly = false, int seats = 1, MealStatus status = MealStatus.open, String? guestId, String geohash, DateTime? createdAt })`. (`seats` fixed at 1 for v1's 1:1 model.)
- `meal/domain/repositories/restaurant_search_repository.dart` — `abstract class RestaurantSearchRepository { Future<List<Restaurant>> search(String query); }`.
- `meal/domain/repositories/meal_repository.dart` — `abstract class MealRepository { Future<String> createMeal(Meal meal); }` (list/watch added in Plan 5).

Domain has zero Flutter/Firebase imports.

## 3. geohash (pure helper)

- `core/util/geohash.dart` — a pure Dart `String encodeGeohash(double lat, double lng, { int precision = 9 })` (standard base-32 geohash algorithm). Unit-tested against known reference values. No dependency added. Plan 5 discovery queries geohash prefixes.

## 4. Data

- `meal/data/datasources/fake_restaurant_search_datasource.dart` implements `RestaurantSearchRepository` with a curated in-memory list of ~15–20 real Paris restaurants (`placeId`, `name`, `address`, `lat`, `lng`); `search(query)` filters case-insensitively by name/address (empty query → the full list). **This is the swap point** for the real Places datasource later.
- `meal/data/dtos/meal_dto.dart` (+ `restaurant` nested) — freezed + json; `dateTime`/`createdAt` as `Timestamp`↔`DateTime` (UTC-normalized, same pattern as the user repo); `status`/`restaurant` serialized (status as `.name`, restaurant as a nested map). Extension mappers `meal/data/mappers/meal_mapper.dart`.
- `meal/data/repositories/meal_repository_impl.dart` — `createMeal`: computes `geohash = encodeGeohash(restaurant.lat, restaurant.lng)` if not already set, writes to the `meals` collection via the flavor-aware `db` (add-doc returns the new id, also stored as `id`), `createdAt = serverTimestamp`, wrapped in `RepositoryWriteException`.

## 5. Firestore rules

`firebase/firestore.rules` — add `meals/{mealId}`:
- `create`: signed-in && `request.resource.data.hostId == request.auth.uid` && required fields present (restaurant, dateTime, status, geohash).
- `read`: the host (owner) for now — broad signed-in read is opened in **Plan 5 (discovery)**.
- `update`/`delete`: host only (join/match transitions come in Plan 6).
Deploy to both `(default)` + `stage` databases (`firebase deploy --only firestore`).

## 6. Application / Presentation

- `meal/application/restaurant_search_controller.dart` — an `AsyncNotifier<List<Restaurant>>` (or a search-query provider) exposing `search(query)`; binds `RestaurantSearchRepository` via `restaurantSearchRepositoryProvider` (→ the fake datasource for now).
- `meal/application/create_meal_controller.dart` — an `AsyncNotifier`; `createMeal({ required Restaurant restaurant, required DateTime dateTime, String? note, required bool womenOnly })` — builds the `Meal` (hostId from `authRepository.currentUser!.uid`), calls `mealRepository.createMeal`, fires `MealCreated`.
- `meal/presentation/restaurant_search_screen.dart` — a **list view**: search field + results list (name/address rows); tapping a row selects it and advances to the meal-details screen. (No map.)
- `meal/presentation/create_meal_screen.dart` — shows the picked restaurant (name/address card), a date/time picker, an optional note field (≤200), a women-only toggle, and a "Create meal" button → `createMeal` → success (pop / confirmation). Tokens, all states.
- **Entry point:** a "Create a meal" button on `placeholder_home.dart` that opens the restaurant search screen (home/discovery proper is Plan 5).

## 7. Analytics

Declared in `lib/core/analytics/events.dart` + `docs/TRACKING-PLAN.md`, no PII:
- `restaurant_selected` (props: none, or `has_query` bool)
- `meal_created` (props: `women_only` bool)

## 8. Routing

Add routes `/meals/new` (restaurant search) and `/meals/new/details` (create-meal details, restaurant passed via `extra`). The home "Create a meal" button navigates to `/meals/new`. These are authed routes (only reachable when signed-in + profile-complete — the existing redirect already funnels unauthed/incomplete users away).

## 9. Testing

- `encodeGeohash` against known reference geohashes (e.g. a couple of well-known lat/lng → geohash pairs).
- `Meal`/`Restaurant` entity + DTO/mapper round-trip (incl. nested restaurant, status enum, Timestamp).
- `MealRepositoryImpl.createMeal` (fake_cloud_firestore) — writes the doc, computes geohash, sets hostId/status/createdAt; returns an id.
- `FakeRestaurantSearchDataSource.search` — filters by name/address; empty query → all.
- `RestaurantSearchController` + `CreateMealController` — search populates; createMeal builds the right Meal + fires `meal_created`.
- Restaurant search screen (list renders, tap selects) + create-meal screen (required fields → create called) widget tests.

## 10. Non-goals (deferred)

- **Real Places API** restaurant source + **map preview** (a later task, unlocked by the API key — swaps `FakeRestaurantSearchDataSource` and adds the map to the detail screens).
- Join request / match (Plan 6); discovery feed + geohash query + broad meals read rule (Plan 5); editing/cancelling meals; group meals / seats > 1.

## 11. Delivery

Own plan on branch `plan-4-meal` (stacked on `plan-3-profile`), executed subagent-driven. Ordered green: geohash helper → domain (restaurant/meal/status + repo interfaces) → fake restaurant datasource + provider → meal DTO/mapper + repo impl + rules → controllers + analytics → screens + home entry → routing → verify/build/PR.
