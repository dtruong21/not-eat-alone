# Convyve — Plan 5: Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An onboarded user sees a distance-sorted **list** of nearby open meals (device GPS via geolocator, Paris fallback; no Maps key), opens a meal to see restaurant + host profile, and the `stage` DB is populated by a seed script so the feed has content.

**Architecture:** `geolocator` gives lat/lng (Paris fallback); the meal's stored `geohash` bounds a Firestore query (`status==open` + geohash prefix range), and the discovery controller client-side filters (future · not-mine · women-only-by-gender) + sorts by Haversine distance. Discovery replaces the placeholder home. A firebase-admin Node script seeds stage users + meals.

**Tech Stack:** Flutter 3.47.4 (FVM), Riverpod, freezed 4, cloud_firestore, geolocator, go_router, mocktail, fake_cloud_firestore; Node + firebase-admin (seed).

**Base branch:** `main` (this branch, `plan-5-discovery`).

## Global Constraints

- Flutter 3.47.4 via FVM — `fvm flutter`/`fvm dart` (PATH += `$HOME/.pub-cache/bin`).
- **Clean Architecture**: `presentation → application → domain ← data`; `domain/` zero framework imports; `cloud_firestore`/`geolocator` SDKs only in `data/` or a `core/` service wrapper.
- Entities pure freezed (no json); DTOs freezed+json in `data/`; extension mappers; codegen gitignored (`fvm dart run build_runner build --delete-conflicting-outputs`).
- `package:` imports only; typed exceptions in data repos; flavor-aware `db`.
- Analytics declared in `events.dart` + `docs/TRACKING-PLAN.md` before firing; no PII.
- Every `AsyncValue` consumer renders loading/error/data; tokens for styling; **watch for rebuild loops** (a prior screen shipped an infinite onChanged→setState loop — no unconditional post-frame notifies; `ref.listen` only for one-shot side effects).
- **No Google Maps/Places dependency or key.** Location = `geolocator` only. Paris center fallback = `(48.8566, 2.3522)`.
- Seed writes to the **stage** Firestore database ONLY; the service-account key is gitignored.
- Verify each task: `fvm flutter analyze --no-fatal-infos` = 0, `fvm flutter test --concurrency=1` all pass.
- Commit messages end with a blank line then `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` (use this EXACT line regardless of the implementer model).

---

### Task 1: `distanceMeters` Haversine helper

**Files:** Create `lib/core/util/distance.dart`; Test `test/core/util/distance_test.dart`

**Interfaces:** Produces `double distanceMeters(double lat1, double lng1, double lat2, double lng2)`.

- [ ] **Step 1: Failing test** — `test/core/util/distance_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/util/distance.dart';

void main() {
  test('same point is 0', () {
    expect(distanceMeters(48.8566, 2.3522, 48.8566, 2.3522), closeTo(0, 0.001));
  });
  test('one degree of longitude at the equator ~111.32 km', () {
    expect(distanceMeters(0, 0, 0, 1), closeTo(111319, 300));
  });
  test('one degree of latitude ~111.19 km', () {
    expect(distanceMeters(0, 0, 1, 0), closeTo(111194, 300));
  });
}
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement** — `lib/core/util/distance.dart`:
```dart
import 'dart:math';

/// Great-circle distance in metres between two lat/lng points (Haversine).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  final dLat = _radians(lat2 - lat1);
  final dLng = _radians(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_radians(lat1)) * cos(_radians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _radians(double degrees) => degrees * pi / 180.0;
```

- [ ] **Step 4: Run, verify PASS.**

- [ ] **Step 5: Verify + commit**
```bash
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add lib/core/util/distance.dart test/core/util/distance_test.dart
git commit -m "feat(discovery): Haversine distanceMeters helper"
```

---

### Task 2: geolocator + `LocationService` (Paris fallback)

**Files:**
- Modify: `pubspec.yaml`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`
- Create: `lib/core/location/location_service.dart`, `lib/core/location/location_providers.dart`
- Test: `test/core/location/location_service_test.dart`

**Interfaces:** Produces `LatLng` (`typedef LatLng = ({double lat, double lng})` or a tiny value class), `LocationService.currentOrParis() → Future<LatLng>` (Paris on any denial/error), `locationProvider` (`FutureProvider<LatLng>`).

- [ ] **Step 1: Add dep** — `fvm flutter pub add geolocator` then `fvm flutter pub get`. If a version solve fails, capture the decisive error + STOP BLOCKED (do not downgrade existing packages).

- [ ] **Step 2: Permissions** —
  - iOS `ios/Runner/Info.plist`: add `<key>NSLocationWhenInUseUsageDescription</key><string>Convyve uses your location to show meals near you.</string>`.
  - Android `android/app/src/main/AndroidManifest.xml`: add `<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>` (above `<application>`).

- [ ] **Step 3: Service** — `location_service.dart`:
```dart
import 'package:geolocator/geolocator.dart';

typedef LatLng = ({double lat, double lng});

const parisCenter = (lat: 48.8566, lng: 2.3522);

class LocationService {
  /// Injectable for tests: returns the device position or throws.
  LocationService({Future<Position> Function()? getPosition, Future<LocationPermission> Function()? checkPermission, Future<LocationPermission> Function()? requestPermission})
      : _getPosition = getPosition ?? (() => Geolocator.getCurrentPosition()),
        _checkPermission = checkPermission ?? Geolocator.checkPermission,
        _requestPermission = requestPermission ?? Geolocator.requestPermission;

  final Future<Position> Function() _getPosition;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;

  /// The device location, or Paris centre on any denial/error/timeout.
  Future<LatLng> currentOrParis() async {
    try {
      var perm = await _checkPermission();
      if (perm == LocationPermission.denied) perm = await _requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return parisCenter;
      }
      final pos = await _getPosition();
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return parisCenter;
    }
  }
}
```

- [ ] **Step 4: Provider** — `location_providers.dart`: `final locationServiceProvider = Provider((ref) => LocationService());` and `final locationProvider = FutureProvider<LatLng>((ref) => ref.watch(locationServiceProvider).currentOrParis());`

- [ ] **Step 5: Test** — `location_service_test.dart`: inject stubs — permission `denied`→`denied` (request stays denied) → returns `parisCenter`; `getPosition` throws → returns `parisCenter`; granted + a stub position `(1.0, 2.0)` → returns `(lat:1.0, lng:2.0)`.

- [ ] **Step 6: Verify + commit**
```bash
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml lib/core/location test/core/location
git commit -m "feat(discovery): geolocator LocationService with Paris fallback"
```

---

### Task 3: `watchDiscoverable` + rules + index

**Files:**
- Modify: `lib/features/meal/domain/repositories/meal_repository.dart`, `lib/features/meal/data/repositories/meal_repository_impl.dart`, `firebase/firestore.rules`, `firebase/firestore.indexes.json`
- Test: `test/features/meal/data/meal_repository_impl_test.dart` (extend)

**Interfaces:** Produces `Stream<List<Meal>> watchDiscoverable({ required String geohashPrefix })` on `MealRepository`.

- [ ] **Step 1: Interface** — add to `meal_repository.dart`:
```dart
Stream<List<Meal>> watchDiscoverable({required String geohashPrefix});
```

- [ ] **Step 2: Impl** — in `meal_repository_impl.dart`, add `watchDiscoverable`: query `_firestore.collection('meals').where('status', isEqualTo: 'open').where('geohash', isGreaterThanOrEqualTo: geohashPrefix).where('geohash', isLessThan: '$geohashPrefix~').snapshots()`; map each doc via `MealDto.fromJson({...doc.data(), 'id': doc.id})` → `toEntity()`, converting `Timestamp`→`DateTime` for `dateTime`/`createdAt` (reuse the same converter helper the write path / user repo uses). Wrap stream errors so a parse failure surfaces as a `RepositoryParseException` in the stream. (`'~'` (0x7E) sorts after every base-32 geohash char, giving the prefix upper bound.)

- [ ] **Step 3: Composite index** — the `status ==` + `geohash` range needs a composite index. Add to `firebase/firestore.indexes.json` an index on collection `meals`, fields `status` (ASC) + `geohash` (ASC). (If the file has an empty `indexes: []`, add the entry.)

- [ ] **Step 4: Rules** — in `firebase/firestore.rules`: change `meals/{mealId}` `read` to `allow read: if isSignedIn();` (keep create host-only, update/delete host-only). Change `users/{uid}` `read` to `allow read: if isSignedIn();` (keep create/update owner-only). Deploy: `firebase deploy --only firestore --project not-eat-alone` (rules + indexes, both DBs). Capture output.

- [ ] **Step 5: Test** — extend `meal_repository_impl_test.dart` (fake_cloud_firestore): seed 3 meals — an `open` meal with geohash starting the prefix, an `open` meal with a different prefix, and a `matched` meal in-prefix; `watchDiscoverable(prefix).first` returns ONLY the first (open + in-prefix). (fake_cloud_firestore supports range queries; if a composite-index limitation bites the fake, filter status client-side in the test's expectation and note it — but prefer the real query.)

- [ ] **Step 6: Verify + commit**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add lib/features/meal firebase/firestore.rules firebase/firestore.indexes.json test/features/meal/data/meal_repository_impl_test.dart
git commit -m "feat(discovery): watchDiscoverable query + open meals/users read rules + index"
```

---

### Task 4: Discovery controller + view model + analytics

**Files:**
- Create: `lib/features/meal/application/discovery_controller.dart`, `lib/features/meal/domain/entities/discoverable_meal.dart`
- Modify: `lib/core/analytics/events.dart`, `docs/TRACKING-PLAN.md`
- Test: `test/features/meal/application/discovery_controller_test.dart`

**Interfaces:**
- Produces: `DiscoverableMeal({ required Meal meal, required double distanceMeters })` (pure); `discoveryControllerProvider` (a `StreamProvider`/`AsyncNotifier` of `List<DiscoverableMeal>`). Events `DiscoveryViewed({required int count})`, `MealOpened({required bool womenOnly})`.

- [ ] **Step 1: View model** — `discoverable_meal.dart`: a pure freezed `DiscoverableMeal` with `meal` (Meal) + `distanceMeters` (double).

- [ ] **Step 2: Analytics** — add `DiscoveryViewed({required int count})` (`discovery_viewed`, `{'count': count}`) and `MealOpened({required bool womenOnly})` (`meal_opened`, `{'women_only': womenOnly}`) to `events.dart`; mirror in `docs/TRACKING-PLAN.md`.

- [ ] **Step 3: Controller** — `discovery_controller.dart`: watches `locationProvider` (a `LatLng`), derives `prefix = encodeGeohash(loc.lat, loc.lng, precision: 4)`, watches `mealRepositoryProvider.watchDiscoverable(prefix)` and `currentUserDocProvider` (viewer: `uid`, `gender`). Produce `List<DiscoverableMeal>`:
  - filter: `meal.dateTime.isAfter(DateTime.now())`, `meal.hostId != viewer.uid`, and `!(meal.womenOnly && viewer.gender != Gender.woman)`;
  - map to `DiscoverableMeal(meal, distanceMeters(loc.lat, loc.lng, meal.restaurant.lat, meal.restaurant.lng))`;
  - sort ascending by `distanceMeters`.
  Fire `DiscoveryViewed(count: result.length)` when a list is produced. Surface loading/error via `AsyncValue`. (Compose the streams with Riverpod `ref.watch`; guard the `location`/`currentUserDoc` loading states — while loading, emit `AsyncLoading`, not a wrong list.)

- [ ] **Step 4: Test** — `discovery_controller_test.dart` (ProviderContainer; override `locationProvider` → a fixed `LatLng`, `mealRepositoryProvider.watchDiscoverable` → a stream of hand-built meals, `currentUserDocProvider` → an `AppUser` with a chosen gender/uid):
  - a past meal is excluded; my own meal (hostId==my uid) excluded; a women-only meal is EXCLUDED for a man viewer and INCLUDED for a woman viewer; results are sorted by distance (nearest first).

- [ ] **Step 5: Verify + commit**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add lib/features/meal/application/discovery_controller.dart lib/features/meal/domain/entities/discoverable_meal.dart lib/core/analytics/events.dart docs/TRACKING-PLAN.md test/features/meal/application/discovery_controller_test.dart
git commit -m "feat(discovery): discovery controller (filter + distance sort) + analytics"
```

---

### Task 5: Discovery + meal-detail screens + routing swap

**Files:**
- Create: `lib/features/meal/presentation/discovery_screen.dart`, `lib/features/meal/presentation/meal_detail_screen.dart`
- Modify: `lib/core/routing/router.dart`; Remove: `lib/features/home/placeholder_home.dart` (and its test) once `/` no longer uses it
- Test: `test/features/meal/presentation/discovery_screen_test.dart`, `test/features/meal/presentation/meal_detail_screen_test.dart`

**Interfaces:** `DiscoveryScreen` at `/`; `MealDetailScreen(meal:)` at `/meals/detail` (Meal via `extra`).

- [ ] **Step 1: Discovery screen** — `discovery_screen.dart` (ConsumerWidget): `ref.watch(discoveryControllerProvider)` → cards (restaurant name, `dateTime`, distance e.g. "1.2 km", host name + thumbnail via the meal's `hostId`→`ref.watch(userRepositoryProvider).watch(hostId)` or a small host provider, a "Women only" badge shown only when the viewer is a woman). Loading/empty ("No meals near you yet")/error states. A "Create a meal" `FloatingActionButton` → `/meals/new`, and the **sign-out** action in the AppBar (moved from PlaceholderHome). Pull-to-refresh: `ref.invalidate(locationProvider)` (+ the controller). Tap a card → `context.push('/meals/detail', extra: meal)` + fire `MealOpened(womenOnly: meal.womenOnly)`. Tokens; no rebuild loops.

- [ ] **Step 2: Meal-detail screen** — `meal_detail_screen.dart`: takes `Meal meal`; restaurant card (name/address), host block via `ref.watch(userRepositoryProvider).watch(meal.hostId)` (photo/name/derived age/bio; loading/error), date/time, note, women-only badge; a **"Request to join" button that is present but `onPressed: null` (disabled) with a "coming soon" hint** (Plan 6 wires it). Tokens.

- [ ] **Step 3: Routing** — in `router.dart`: change `/` builder from `PlaceholderHome` to `const DiscoveryScreen()`; add `GoRoute(path: '/meals/detail', builder: (c, s) { final m = s.extra; return m is Meal ? MealDetailScreen(meal: m) : const DiscoveryScreen(); })`. Import both screens. Remove the `PlaceholderHome` import/route. `authRedirect` unchanged.

- [ ] **Step 4: Remove PlaceholderHome** — delete `lib/features/home/placeholder_home.dart` + `test/features/home/placeholder_home_test.dart` (grep first: nothing else should reference `PlaceholderHome`; the router was the only user). If the flavor-title smoke was asserted only there, add an equivalent tiny assertion in the discovery screen test (title/AppBar present).

- [ ] **Step 5: Widget tests** — discovery: override `discoveryControllerProvider` with a couple of `DiscoverableMeal`s → cards render (name/distance); women-only badge visible for a woman viewer, hidden for a man (override `currentUserDocProvider`); tapping a card navigates. meal-detail: override `userRepositoryProvider.watch` → a host `AppUser` → host name/age render; "Request to join" is disabled. Use `pumpAndSettle` where practical to catch rebuild loops.

- [ ] **Step 6: Verify + commit**
```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze --no-fatal-infos && fvm flutter test --concurrency=1
git add lib/features/meal/presentation lib/core/routing/router.dart test/features/meal/presentation
git rm lib/features/home/placeholder_home.dart test/features/home/placeholder_home_test.dart
git commit -m "feat(discovery): discovery feed + meal detail screens, / -> discovery"
```

---

### Task 6: Seed script (firebase-admin → stage)

**Files:**
- Create: `scripts/seed/seed_stage.mjs`, `scripts/seed/seed_data.mjs` (pure doc builders), `scripts/seed/package.json`, `scripts/seed/README.md`
- Modify: `.gitignore` (ignore `scripts/seed/service-account.json` + `scripts/seed/node_modules`)
- Test: `scripts/seed/seed_data.test.mjs` (node's built-in `node:test`) — a unit check on the pure doc builders.

**Interfaces:** Produces seed `users` + `meals` doc objects; a runner that writes them to the **stage** database.

- [ ] **Step 1: Pure builders** — `seed_data.mjs`: export `buildSeedUsers()` → ~12 user doc objects (`{ id: 'seed_user_01', uid, displayName, gender: 'woman'|'man'|'nonBinary', dob (Date ~25-40y ago), ageVerified: true, photoUrls: ['https://picsum.photos/seed/seed_user_01/400'], bio }`) and `buildSeedMeals(restaurants)` → ~18 meal doc objects (`{ id: 'seed_meal_01', hostId: <a seed uid>, restaurant: {placeId,name,address,lat,lng}, dateTime (future Date), note, womenOnly (some true), seats:1, status:'open', geohash: <encode(lat,lng,9)>, createdAt }`). Include a small base-32 `encodeGeohash(lat,lng,precision=9)` (port the Dart algorithm) + the ~20 Paris restaurants (duplicate from the Dart fake datasource). Keep builders PURE (no admin SDK) so they're unit-testable.
- [ ] **Step 2: Builder test** — `seed_data.test.mjs`: `buildSeedUsers()` returns ≥10 users all with `ageVerified:true`, `photoUrls.length>=1`, a valid gender; `buildSeedMeals(restaurants)` returns ≥15 meals all `status:'open'` with a 9-char `geohash` and a future `dateTime`. Run `node --test scripts/seed/seed_data.test.mjs` → pass.
- [ ] **Step 3: Runner** — `seed_stage.mjs`: `import { initializeApp, cert } from 'firebase-admin/app'; import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';` init with `cert('./service-account.json')`; **`const db = getFirestore(app, 'stage');`** (the named stage database — assert it's `'stage'`, refuse `(default)`/prod). Write users to `users/{id}` and meals to `meals/{id}` with `set(..., {merge:true})` (idempotent), converting `dob`/`dateTime`/`createdAt` to `Timestamp`. Support `--wipe` (delete docs whose id starts with `seed_`). Log a summary.
- [ ] **Step 4: package.json + README** — `scripts/seed/package.json` (`"type":"module"`, dep `firebase-admin`, scripts `seed`/`wipe`); `README.md`: download the service account (Project settings → Service accounts → Generate key) to `scripts/seed/service-account.json`, `npm install`, `npm run seed`. Note it targets the **stage** database only.
- [ ] **Step 5: .gitignore** — add `scripts/seed/service-account.json` and `scripts/seed/node_modules/`.
- [ ] **Step 6: Verify + commit** — `node --test scripts/seed/seed_data.test.mjs` passes (Flutter analyze/test unaffected — this is out-of-app Node; still run `fvm flutter test --concurrency=1` to confirm no app regression).
```bash
git add scripts/seed .gitignore
git commit -m "feat(discovery): firebase-admin stage seed script (users + meals)"
```
(The actual `npm install` + `npm run seed` against stage is a coordinator/user step — it needs the service-account key.)

---

### Task 7: Verify, build, PR

- [ ] **Step 1: Full suite** — `fvm dart run build_runner build --delete-conflicting-outputs`, `fvm flutter analyze --no-fatal-infos` (0), `fvm flutter test --concurrency=1` (all pass).
- [ ] **Step 2: Build both flavors** — stage + prod debug APKs build.
- [ ] **Step 3: Smoke (coordinator)** — build+launch stage on the iOS Simulator; confirm `/` shows the discovery screen (empty-state until seeded/signed-in). Optionally run the seed script against stage (if the key is available) and note results. Update `docs/TEST-PLAN.md` with a Discovery checklist.
- [ ] **Step 4: PR** — `git push -u origin plan-5-discovery`; `gh pr create --base main --head plan-5-discovery --title "Plan 5: discovery + seed" --body "<summary>"` (end body with a blank line then `🤖 Generated with [Claude Code](https://claude.com/claude-code)`).

---

## Self-review notes

- **Spec coverage:** location/geolocator+fallback (§2 → Task 2); distance (§2 → Task 1); geohash query + rules (§3/§5 → Task 3); controller/filter/sort/view-model/analytics (§3/§6/§8 → Task 4); screens + routing swap (§6/§9 → Task 5); seed script (§7 → Task 6); testing (§10 → per task); non-goals (§11 → respected: no Places/map, no join, no chat). ✔
- **Ordering (green):** distance (pure) → location service → repo read + rules (additive) → controller (additive) → screens + `/` swap (the one consumer change; removes PlaceholderHome) → seed (out-of-app) → verify/PR.
- **Type consistency:** `LatLng`, `distanceMeters`, `encodeGeohash` (precision 4 for query prefix, 9 for stored/seed), `watchDiscoverable({geohashPrefix})`, `DiscoverableMeal{meal,distanceMeters}`, `Gender.woman` filter — consistent across Tasks 1-6. The seed script's `encodeGeohash` is a JS port of the Dart one (same algorithm, precision 9).
- **Rebuild-loop guard:** screens use `ref.watch`/`ref.listen` correctly (Task 5 tests use `pumpAndSettle`); no unconditional post-frame notify (the ProfileForm regression pattern).
- **Placeholder scan:** none — distance/location/query/controller code + rules + seed builders are concrete. UI specified structurally + tested.
