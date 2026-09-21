# Convyve — Discovery Design (Plan 5)

**Date:** 2026-09-21
**Status:** Approved (design), pending implementation plan
**Feature:** Discover nearby open meals — a **list feed** (no map; deferred with the Places/Maps key task) — + a meal-detail screen, plus a stage **seed script** so the feed has content. Built on the clean `meal`/`user` features.

---

## 1. Goal & constraints

A signed-in, onboarded user in Paris sees a list of open, future meals near them (sorted by distance), can open a meal to see its restaurant + host profile, and (Plan 6) will request to join. No Google Maps/Places key — location comes from device GPS via `geolocator` (free), the feed is list-only, and proximity uses the stored geohash + a client-side distance sort.

## 2. Location (geolocator, Paris fallback)

- Add `geolocator` (free; no Google key). `core/location/location_service.dart` — `Future<({double lat, double lng})> currentOrParis()`: request permission + read position; on denied/error/timeout return **Paris center `(48.8566, 2.3522)`**. Exposed via `locationProvider` (a `FutureProvider`).
- iOS: add `NSLocationWhenInUseUsageDescription` to `Info.plist`. Android: add `ACCESS_COARSE_LOCATION` (fine not required) to the manifest.
- `core/util/distance.dart` — pure `double distanceMeters(double lat1, double lng1, double lat2, double lng2)` (Haversine), unit-tested.

## 3. Query (geohash, client-side refine)

- `MealRepository.watchDiscoverable({ required String geohashPrefix })` — streams `meals` where `status == 'open'` and `geohash >= prefix` and `geohash < prefix + '~'` (a prefix range on the coarse cell). The prefix is `encodeGeohash(userLat, userLng, precision: 4)` (~one Paris-sized cell; covers greater Paris). `matched`/`completed`/`cancelled` meals are excluded by the status filter.
- The **discovery controller** then, client-side: drops past meals (`dateTime` ≤ now), drops the viewer's own meals (`hostId == myUid`), **hides women-only meals unless the viewer's `gender == Gender.woman`**, computes `distanceMeters` to each, and sorts ascending by distance.
- (Finer geohash-neighbour queries + server-side filtering are the multi-city scale-up; a Paris-only launch fits one coarse cell + client refine.)

## 4. Data / repository

- Extend `MealRepositoryImpl` with `watchDiscoverable` using a `.withConverter<Meal>`-style read (`MealDto.fromJson` → `toEntity`; `Timestamp`→`DateTime` for `dateTime`/`createdAt`). Read path only — no new write path (so the deferred `MealDto.restaurant` `toJson` hardening isn't triggered here; `fromJson` already parses the nested restaurant map).
- The meal-detail screen gets its `Meal` from the feed via route `extra` (no extra fetch); the **host profile** is read via the existing `UserRepository.watch(hostId)`.

## 5. Rules

`firebase/firestore.rules`:
- `meals/{mealId}` — broaden `read` to any signed-in user: `allow read: if isSignedIn();` (keep create host-only; keep update/delete host-only for now — join transitions come in Plan 6).
- `users/{uid}` — broaden `read` to any signed-in user (discovery shows host profiles): `allow read: if isSignedIn();` (create/update stay owner-only).
- Deploy to both `(default)` + `stage`.

## 6. Application / Presentation

- `meal/application/discovery_controller.dart` — combines `locationProvider` + `mealRepositoryProvider.watchDiscoverable(prefix)` + `currentUserDocProvider` (viewer uid + gender); exposes an `AsyncValue<List<DiscoverableMeal>>` (a small view model = meal + distanceMeters), filtered + distance-sorted per §3. Fires `DiscoveryViewed`.
- `meal/presentation/discovery_screen.dart` — **the new home** (route `/`): a list of meal cards (restaurant name, time, distance, host name/thumbnail, women-only badge shown only to women), pull-to-refresh (re-reads location + stream), empty/loading/error states, a "Create a meal" FAB, and the sign-out action (moved here from the placeholder). Replaces `PlaceholderHome` at `/`.
- `meal/presentation/meal_detail_screen.dart` — restaurant card, host profile block (photo/name/derived age/bio via `UserRepository.watch(hostId)`), date/time, note, women-only; a **"Request to join" button that is present but stubbed/disabled** (a TODO for Plan 6). Fires `MealOpened`.

## 7. Seed script (firebase-admin → stage only)

- `scripts/seed/seed_stage.mjs` — Node + `firebase-admin`, targeting the **`stage`** Firestore database of project `not-eat-alone`. Writes:
  - ~12 `users/{seed_uid}` — complete profiles (`seed_user_01`.., displayName, gender mix, `dob`, `ageVerified: true`, `photoUrls` = placeholder image URLs, `bio`).
  - ~18 `meals/{seed_meal_id}` — `status: 'open'`, hosts = seed users, restaurants = the fake Paris list (import/duplicate the coords), varied future `dateTime`s, some `womenOnly: true`, `geohash` computed from the restaurant coords, `seats: 1`, `createdAt`.
  - Idempotent (fixed ids, `set` with merge) + a `--wipe` flag (deletes seed docs by id prefix). Explicitly refuses to run against `(default)`/prod (targets the `stage` database via the Admin SDK's `getFirestore(app, 'stage')`).
- `scripts/seed/package.json` (firebase-admin dep) + `scripts/seed/README.md` (how to run). **`scripts/seed/service-account.json` is gitignored** — the user downloads it from the console.

## 8. Analytics

Declared in `events.dart` + `docs/TRACKING-PLAN.md`, no PII:
- `discovery_viewed` (props: `count` = meals shown)
- `meal_opened` (props: `women_only` bool)

## 9. Routing

- `/` → `DiscoveryScreen` (replaces `PlaceholderHome`; the redirect states are unchanged — a fully-onboarded user lands on discovery).
- `/meals/:id` (or `/meals/detail`) → `MealDetailScreen` (Meal passed via `extra`; null-guard → back to `/`). Keep `/meals/new` + `/meals/new/details` from Plan 4.
- `PlaceholderHome` is removed (or kept only if something still refs it — it should not after `/` swaps).

## 10. Testing

- `distanceMeters` against a known pair (e.g. Paris↔a point ~1km away ≈ 1000m ± tolerance).
- `watchDiscoverable` (fake_cloud_firestore): returns only `open` meals within the prefix; excludes other statuses/prefixes.
- Discovery controller: filters (past/own/women-only-by-gender) + distance sort — with a fake location + seeded meals + viewer gender variations (woman sees women-only; man does not; own meal excluded; past excluded).
- Discovery screen: renders cards from an overridden controller; women-only badge visibility by viewer gender; tap → detail nav. Meal-detail screen: renders host profile from an overridden user repo; join button present + disabled.
- Rules: (manual/emulator) signed-in non-host can READ a meal + a host user doc; still cannot create a meal as another host.
- Seed script: a dry-run/self-check that it constructs the right doc shapes (a small unit around the doc-builder function, or a documented manual run against stage).

## 11. Non-goals (deferred)

- Real Places API + **map view** of the feed (the later keyed task).
- Join request / match + the "Request to join" wiring + meal status transitions (Plan 6); chat (Plan 7).
- Server-side gender/geo filtering, finer geohash neighbours, pagination (scale-up).
- Editing/cancelling meals.

## 12. Delivery

Own plan on branch `plan-5-discovery` (off `main`), executed subagent-driven. Ordered green: geolocator dep + permissions + location service → distance helper → meals read (`watchDiscoverable`) + rules → discovery controller + analytics → discovery + detail screens + routing (swap `/`) → seed script → verify/build/PR.
