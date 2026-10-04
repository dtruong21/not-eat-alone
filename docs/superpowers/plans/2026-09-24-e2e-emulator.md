# Emulator E2E Test Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A one-command, CI-runnable end-to-end suite that boots the real Flutter app against the Firebase Emulator Suite, exercising the real `firestore.rules` and Cloud Functions across the app's core flows.

**Architecture:** `firebase emulators:exec "fvm flutter test integration_test"` boots Auth/Firestore/Functions/Storage emulators, then Flutter integration tests boot the real app widget tree through a bootstrap emulator seam (App Check + Crashlytics off), sign test users in via the Auth emulator's fake-credential path, seed preconditions through the emulator-pointed SDK, and drive UI flows while asserting UI + Firestore + Function-trigger effects.

**Tech Stack:** Flutter (FVM, `fvm flutter`), `integration_test` (SDK), `flutter_test`, cloud_firestore / firebase_auth / firebase_functions / firebase_storage, firebase-tools 15.x emulator suite, TypeScript Cloud Functions (`firebase/functions`), GitHub Actions.

## Global Constraints

- **Flutter via FVM always:** `fvm flutter ...`, never bare `flutter`.
- **Dependency rule:** `presentation → application → domain ← data`. `cloud_firestore`/`firebase_auth`/`firebase_functions`/`firebase_storage` imports allowed ONLY in a feature's `data/` layer, in `lib/core/firebase/`, in `lib/main_common.dart` (bootstrap), and in `integration_test/` (test code, exempt from the app dependency rule).
- **Strict lints:** `very_good_analysis`; no `dynamic` at boundaries.
- **Region:** all `FirebaseFunctions` use `instanceFor(region: 'europe-west1')` — the emulator seam must match whatever region the app repos use.
- **Emulator db id:** the harness runs against the Firestore emulator's `(default)` database. The harness `FlavorConfig` must yield `firestoreDatabaseId == '(default)'`.
- **Shipped builds unchanged:** `main_stage.dart` / `main_prod.dart` pass no emulator config; the seam is default-off.
- **Emulator ports:** auth 9099, firestore 8080, functions 5001, storage 9199, ui 4000. Project id for emulator: `not-eat-alone`.
- **No fixed sleeps:** readiness and async-trigger waits use bounded polling helpers.

---

### Task 1: Emulator config + bootstrap emulator seam

**Files:**
- Modify: `firebase.json` (add `emulators` block)
- Create: `lib/core/config/emulator_config.dart`
- Modify: `lib/main_common.dart` (optional `emulator` param + wiring)
- Test: `test/core/config/emulator_config_test.dart`

**Interfaces:**
- Consumes: existing `bootstrap({required FlavorConfig config, required FirebaseOptions options})`, `FlavorConfig`.
- Produces:
  - `class EmulatorConfig { final String host; final int authPort, firestorePort, functionsPort, storagePort; const EmulatorConfig({this.host = '127.0.0.1', this.authPort = 9099, this.firestorePort = 8080, this.functionsPort = 5001, this.storagePort = 9199}); factory EmulatorConfig.local() = ...; }`
  - `Future<void> bootstrap({required FlavorConfig config, required FirebaseOptions options, EmulatorConfig? emulator})` — when `emulator != null`: wire all four emulators after `initializeApp`, skip App Check + Crashlytics.

- [ ] **Step 1: Write the failing test** — `test/core/config/emulator_config_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/config/emulator_config.dart';

void main() {
  test('EmulatorConfig.local has expected defaults', () {
    const c = EmulatorConfig.local();
    expect(c.host, '127.0.0.1');
    expect(c.authPort, 9099);
    expect(c.firestorePort, 8080);
    expect(c.functionsPort, 5001);
    expect(c.storagePort, 9199);
  });

  test('host override is honoured (Android loopback)', () {
    const c = EmulatorConfig(host: '10.0.2.2');
    expect(c.host, '10.0.2.2');
    expect(c.firestorePort, 8080);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/core/config/emulator_config_test.dart`
Expected: FAIL — `emulator_config.dart` / `EmulatorConfig` not found.

- [ ] **Step 3: Create `lib/core/config/emulator_config.dart`**

```dart
/// Localhost Firebase Emulator Suite coordinates for E2E test boots.
///
/// Only ever passed to [bootstrap] from `integration_test/` — shipped
/// entrypoints (`main_stage.dart`/`main_prod.dart`) pass no emulator config,
/// so production builds never touch this.
library;

class EmulatorConfig {
  const EmulatorConfig({
    this.host = '127.0.0.1',
    this.authPort = 9099,
    this.firestorePort = 8080,
    this.functionsPort = 5001,
    this.storagePort = 9199,
  });

  /// Default localhost config (desktop / CI). Android emulators reach the
  /// host loopback via `10.0.2.2` — pass that as [host] there.
  const factory EmulatorConfig.local() = EmulatorConfig._local;

  const EmulatorConfig._local() : this();

  final String host;
  final int authPort;
  final int firestorePort;
  final int functionsPort;
  final int storagePort;
}
```

- [ ] **Step 4: Run the config test to verify it passes**

Run: `fvm flutter test test/core/config/emulator_config_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the `emulators` block to `firebase.json`**

Add this top-level key (sibling of `firestore`/`functions`):

```json
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "functions": { "port": 5001 },
    "storage": { "port": 9199 },
    "ui": { "enabled": true, "port": 4000 },
    "singleProjectMode": true
  }
```

- [ ] **Step 6: Wire the emulator seam in `lib/main_common.dart`**

Add imports (`cloud_firestore`, `firebase_auth`, `cloud_functions`, `firebase_storage`) and the `emulator_config` import. Change the signature and guard the App Check/Crashlytics blocks. Reference the region the app actually uses — grep `instanceFor(region:` under `lib/` first; use that exact region string (expected `'europe-west1'`).

```dart
Future<void> bootstrap({
  required FlavorConfig config,
  required FirebaseOptions options,
  EmulatorConfig? emulator,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.current = config;
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await Firebase.initializeApp(options: options);

  if (emulator != null) {
    final e = emulator;
    FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: config.firestoreDatabaseId,
    ).useFirestoreEmulator(e.host, e.firestorePort);
    await FirebaseAuth.instance.useAuthEmulator(e.host, e.authPort);
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .useFunctionsEmulator(e.host, e.functionsPort);
    await FirebaseStorage.instance.useStorageEmulator(e.host, e.storagePort);
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  try {
    await GoogleSignIn.instance.initialize();
  } catch (_) {}
  runApp(const ProviderScope(child: NotEatAloneApp()));
}
```

Note: if `cloud_functions` / `firebase_storage` are not yet direct dependencies in `pubspec.yaml`, add them (`fvm flutter pub add cloud_functions firebase_storage`) — they are transitive today via other Firebase deps but must be direct to import here.

- [ ] **Step 7: Static-verify the app still analyzes and unit tests pass**

Run: `fvm flutter analyze && fvm flutter test test/core/config/emulator_config_test.dart`
Expected: analyze clean (no new issues from the seam); config test PASS. (Full `bootstrap` is only exercised end-to-end in later tasks under the emulator.)

- [ ] **Step 8: Commit**

```bash
git add firebase.json lib/core/config/emulator_config.dart lib/main_common.dart test/core/config/emulator_config_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(e2e): add emulator config + default-off bootstrap emulator seam"
```

---

### Task 2: Test harness support — app boot, auth, seed

**Files:**
- Create: `integration_test/support/app_harness.dart`
- Create: `integration_test/support/auth.dart`
- Create: `integration_test/support/seed.dart`
- Create: `integration_test/support/emulator_admin.dart` (clear endpoints + polling helpers)

**Interfaces:**
- Consumes: `bootstrap(...)` with `emulator`, `EmulatorConfig`, `FlavorConfig`, `DefaultFirebaseOptions` (prod options file — the emulator ignores the real project's keys but needs a valid `FirebaseOptions`).
- Produces:
  - `Future<void> pumpApp(WidgetTester tester)` — calls `bootstrap` with the test flavor + `EmulatorConfig.local()`, then `await tester.pumpAndSettle()`.
  - `const String kProjectId = 'not-eat-alone';`
  - `FlavorConfig testFlavor()` → a `FlavorConfig` whose `firestoreDatabaseId == '(default)'` (i.e. `Flavor.prod`).
  - `Future<User> signInTestUser({required String uid, String email})` (auth.dart)
  - `Future<void> signOutTestUser()` (auth.dart)
  - `Future<void> seedUserProfile({required String uid, String gender = 'woman', ...})` , `Future<String> seedOpenMeal({required String hostId, bool womenOnly = false, ...})` (seed.dart) — return created ids.
  - `Future<void> clearEmulators()` (emulator_admin.dart) — Firestore + Auth clear via REST.
  - `Future<T> pollUntil<T>(Future<T?> Function() probe, {Duration timeout, Duration interval})` (emulator_admin.dart) — bounded poll, throws on timeout.

- [ ] **Step 1: Write `emulator_admin.dart` (clear + poll helpers)**

```dart
import 'dart:async';
import 'package:http/http.dart' as http;

const String kProjectId = 'not-eat-alone';
const String kEmulatorHost = '127.0.0.1';

Future<void> clearEmulators() async {
  await http.delete(Uri.parse(
    'http://$kEmulatorHost:8080/emulator/v1/projects/$kProjectId/'
    'databases/(default)/documents',
  ));
  await http.delete(Uri.parse(
    'http://$kEmulatorHost:9099/emulator/v1/projects/$kProjectId/accounts',
  ));
}

Future<T> pollUntil<T>(
  Future<T?> Function() probe, {
  Duration timeout = const Duration(seconds: 10),
  Duration interval = const Duration(milliseconds: 200),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final v = await probe();
    if (v != null) return v;
    await Future<void>.delayed(interval);
  }
  throw TimeoutException('pollUntil exceeded $timeout');
}
```

If `http` is not a dependency, add it: `fvm flutter pub add http` (or reuse `package:firebase_*` REST; `http` is simplest).

- [ ] **Step 2: Write `auth.dart` (fake-credential sign-in)**

The Auth emulator's `signInWithIdp` accepts an unsigned claim blob. Simplest client path: use the emulator REST `signInWithIdp` to mint a Google-provider user, then sign the Dart SDK in with the returned credential — or, more directly, `signInWithCredential` with a `GoogleAuthProvider.credential` whose `idToken` is a JSON claim the emulator accepts. Implement via REST to be deterministic:

```dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'emulator_admin.dart';

Future<User> signInTestUser({
  required String uid,
  String? email,
}) async {
  final mail = email ?? '$uid@example.com';
  final claims = jsonEncode({
    'sub': uid,
    'email': mail,
    'email_verified': true,
  });
  final res = await http.post(
    Uri.parse(
      'http://$kEmulatorHost:9099/identitytoolkit.googleapis.com/v1/'
      'accounts:signInWithIdp?key=fake-api-key',
    ),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'postBody': 'id_token=$claims&providerId=google.com',
      'requestUri': 'http://localhost',
      'returnSecureToken': true,
      'returnIdpCredential': true,
    }),
  );
  final idToken = (jsonDecode(res.body) as Map)['idToken'] as String;
  final cred = GoogleAuthProvider.credential(idToken: idToken);
  final userCred =
      await FirebaseAuth.instance.signInWithCredential(cred);
  return userCred.user!;
}

Future<void> signOutTestUser() => FirebaseAuth.instance.signOut();
```

Note for the implementer: if `signInWithCredential` rejects the emulator idToken shape, fall back to signing in with the `localId`/token the REST call returns via `FirebaseAuth.instance.signInWithCustomToken` is NOT available in emulator without admin; instead use the emulator's returned `idToken` directly by calling `signInWithCredential` — validate against the running emulator during this task and adjust the exact field names to what the emulator returns (`idToken`). Keep the **public** signature (`signInTestUser`/`signOutTestUser`) stable regardless of the internal mechanism.

- [ ] **Step 3: Write `seed.dart` (SDK preconditions)**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;

Future<void> seedUserProfile({
  required String uid,
  String gender = 'woman',
  DateTime? dob,
}) async {
  await _db.collection('users').doc(uid).set({
    'uid': uid,
    'dob': Timestamp.fromDate(
      dob ?? DateTime(1995, 1, 1),
    ),
    'ageVerified': true,
    'gender': gender,
    'ratingSum': 0,
    'ratingCount': 0,
    'ratingAvg': 0,
  });
}

Future<String> seedOpenMeal({
  required String hostId,
  bool womenOnly = false,
  DateTime? dateTime,
}) async {
  final ref = _db.collection('meals').doc();
  await ref.set({
    'hostId': hostId,
    'status': 'open',
    'geohash': 'u09',
    'dateTime': Timestamp.fromDate(
      dateTime ?? DateTime.now().add(const Duration(hours: 3)),
    ),
    'womenOnly': womenOnly,
  });
  return ref.id;
}
```

Implementer: confirm required fields against `firestore.rules` (users create + meals create) and against the freezed DTOs (`lib/features/*/data/dtos/`) so seeded docs deserialize; add any non-nullable fields the mappers require. Seeding runs while signed in as the relevant owner (rules require `hostId == auth.uid` for meals, `uid == auth.uid` for the profile) — seed each doc under the right signed-in user.

- [ ] **Step 4: Write `app_harness.dart` (boot the real app on emulators)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/config/emulator_config.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/firebase/options/firebase_options_prod.dart';
import 'package:not_eat_alone/main_common.dart';

FlavorConfig testFlavor() => FlavorConfig(flavor: Flavor.prod);

Future<void> pumpApp(WidgetTester tester) async {
  await bootstrap(
    config: testFlavor(),
    options: DefaultFirebaseOptions.currentPlatform,
    emulator: const EmulatorConfig.local(),
  );
  await tester.pumpAndSettle();
}
```

- [ ] **Step 5: Analyze the support files**

Run: `fvm flutter analyze integration_test`
Expected: clean (no undefined symbols; imports resolve). Full runtime exercise happens in Task 3 under the emulator.

- [ ] **Step 6: Commit**

```bash
git add integration_test/support pubspec.yaml pubspec.lock
git commit -m "test(e2e): harness support — emulator boot, fake-credential auth, seed, admin helpers"
```

---

### Task 3: Scenario 1 — smoke (boot + auth + discover renders)

**Files:**
- Create: `integration_test/smoke_test.dart`
- Create: `Makefile` (or `scripts/e2e.sh`) with the one-command run target
- Test: this task's deliverable IS the test; it runs under the emulator.

**Interfaces:**
- Consumes: `pumpApp`, `signInTestUser`, `seedUserProfile`, `clearEmulators` from Task 2.
- Produces: a green `integration_test/smoke_test.dart` and a `make e2e` target.

- [ ] **Step 1: Write the smoke test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'support/app_harness.dart';
import 'support/auth.dart';
import 'support/emulator_admin.dart';
import 'support/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(clearEmulators);

  testWidgets('signed-in user boots to the Discover feed', (tester) async {
    // Arrange: a signed-in user with a valid profile.
    final user = await signInTestUser(uid: 'host-1');
    await seedUserProfile(uid: user.uid);

    // Act: boot the real app against the emulators.
    await pumpApp(tester);

    // Assert: the app reached its authed home (Discover) without error —
    // adjust the finder to a stable Discover marker (key/label) confirmed
    // from lib/core/routing/app_shell.dart + the discovery screen.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

Implementer: read `lib/core/routing/app_shell.dart` + the discovery screen to find a **stable** widget/key that only appears on the authed Discover feed (e.g. a bottom-nav Discover tab, or the Paris soft-notice banner) and assert on that rather than just `MaterialApp`, so the test proves the auth-gated route actually rendered. If the router needs a pump/settle after auth state resolves, `await tester.pumpAndSettle()` (already in `pumpApp`; add an extra bounded pump loop if the auth redirect is async).

- [ ] **Step 2: Add the one-command run target**

`Makefile`:

```makefile
e2e:
	cd firebase/functions && npm ci && npm run build
	firebase emulators:exec --only auth,firestore,functions,storage \
		--project not-eat-alone \
		"fvm flutter test integration_test"
```

- [ ] **Step 3: Run the smoke test under the emulator**

Run: `make e2e` (or the raw `firebase emulators:exec ... "fvm flutter test integration_test/smoke_test.dart"`)
Expected: emulators boot, functions load, the smoke test PASSES. If auth/seed field shapes are wrong, fix them here (this is where the harness is first exercised for real).

- [ ] **Step 4: Commit**

```bash
git add integration_test/smoke_test.dart Makefile
git commit -m "test(e2e): scenario 1 — smoke boot + auth + discover renders; add make e2e"
```

---

### Task 4: Scenario 2 — request → approve → match

**Files:**
- Create: `integration_test/request_match_test.dart`

**Interfaces:**
- Consumes: harness support + Task 3 patterns. Reads real screens/controllers for the request + approve flows (`lib/features/matching/`).
- Produces: green `request_match_test.dart`.

- [ ] **Step 1: Write the test (drive UI where practical, assert Firestore + Function effects)**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'support/app_harness.dart';
import 'support/auth.dart';
import 'support/emulator_admin.dart';
import 'support/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(clearEmulators);

  testWidgets('guest requests, host approves, match is created', (tester) async {
    // Seed host + open meal (as host).
    final host = await signInTestUser(uid: 'host-1');
    await seedUserProfile(uid: host.uid);
    final mealId = await seedOpenMeal(hostId: host.uid);
    await signOutTestUser();

    // Guest signs in, boots app, requests the meal via UI.
    final guest = await signInTestUser(uid: 'guest-1');
    await seedUserProfile(uid: guest.uid, gender: 'woman');
    await pumpApp(tester);
    // Navigate discovery → meal detail → tap "Request".
    // Implementer: use finders confirmed from the discovery + meal-detail
    // screens; fall back to driving the RequestRepository via a ProviderScope
    // override only if a UI path is impractical, but prefer the real UI.

    // Assert the request doc exists and is pending.
    final reqs = await FirebaseFirestore.instance
        .collection('requests')
        .where('mealId', isEqualTo: mealId)
        .get();
    expect(reqs.docs, hasLength(1));
    expect(reqs.docs.first['status'], 'pending');
    final requestId = reqs.docs.first.id;
    await signOutTestUser();

    // Host signs in, approves via UI (inbox → approve).
    await signInTestUser(uid: host.uid);
    await pumpApp(tester);
    // Implementer: drive the inbox approve action for `requestId`.

    // Assert approve transaction effects + Function trigger.
    final match = await pollUntil(() async {
      final m = await FirebaseFirestore.instance
          .collection('matches').doc(mealId).get();
      return m.exists ? m : null;
    });
    expect(match['participants'], containsAll([host.uid, guest.uid]));
    final meal = await FirebaseFirestore.instance
        .collection('meals').doc(mealId).get();
    expect(meal['status'], 'matched');
    expect(meal['guestId'], guest.uid);
  });
}
```

- [ ] **Step 2: Run under emulator**

Run: `firebase emulators:exec --only auth,firestore,functions,storage --project not-eat-alone "fvm flutter test integration_test/request_match_test.dart"`
Expected: PASS. If the client approve is a Firestore transaction (not a Function), the match assertion holds without polling; keep `pollUntil` if a `request_updated`/match Function does any of the writes (async).

- [ ] **Step 3: Commit**

```bash
git add integration_test/request_match_test.dart
git commit -m "test(e2e): scenario 2 — request, approve, match creation"
```

---

### Task 5: Scenario 3 — chat (message rule + read receipt)

**Files:**
- Create: `integration_test/chat_test.dart`

**Interfaces:**
- Consumes: harness + a match precondition. May seed a match directly (as host) to avoid re-driving Task 4's whole flow — seed `matches/{id}` with `hostId`/`guestId`/`participants`, meal `matched`.
- Produces: green `chat_test.dart`.

- [ ] **Step 1: Add a `seedMatch` helper to `support/seed.dart`**

```dart
Future<void> seedMatch({
  required String matchId,
  required String hostId,
  required String guestId,
}) async {
  await FirebaseFirestore.instance.collection('matches').doc(matchId).set({
    'hostId': hostId,
    'guestId': guestId,
    'participants': [hostId, guestId],
  });
}
```

Implementer: confirm the match doc's required fields against `firestore.rules` matches-create + the Match DTO; the create rule requires `hostId == auth.uid`, so seed while signed in as host.

- [ ] **Step 2: Write the chat test**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'support/app_harness.dart';
import 'support/auth.dart';
import 'support/emulator_admin.dart';
import 'support/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(clearEmulators);

  testWidgets('host sends a message the guest can read', (tester) async {
    final host = await signInTestUser(uid: 'host-1');
    await seedUserProfile(uid: host.uid);
    final guest = await signInTestUser(uid: 'guest-1'); // creates guest acct
    await seedUserProfile(uid: guest.uid);
    // Sign back in as host to seed the match under host ownership.
    await signInTestUser(uid: host.uid);
    const matchId = 'match-1';
    await seedMatch(matchId: matchId, hostId: host.uid, guestId: guest.uid);

    await pumpApp(tester);
    // Drive: open the chat for matchId, type + send a message.
    // Implementer: finders from lib/features/chat/presentation.

    final msgs = await pollUntil(() async {
      final s = await FirebaseFirestore.instance
          .collection('matches').doc(matchId)
          .collection('messages').get();
      return s.docs.isNotEmpty ? s : null;
    });
    expect(msgs.docs.first['senderId'], host.uid);
    expect((msgs.docs.first['text'] as String).isNotEmpty, isTrue);
  });
}
```

- [ ] **Step 3: (Optional, if cheap) negative case** — with a block between host and guest (`seed` a `blocks/{host}_{guest}` doc), assert message-create is rejected (`matchMessageCreateOk` false). Wrap the send in expect-throws / assert no message doc appears. Skip if it balloons the task; note it as a follow-up in the test file.

- [ ] **Step 4: Run under emulator**

Run: `firebase emulators:exec --only auth,firestore,functions,storage --project not-eat-alone "fvm flutter test integration_test/chat_test.dart"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add integration_test/chat_test.dart integration_test/support/seed.dart
git commit -m "test(e2e): scenario 3 — chat message rule + read path"
```

---

### Task 6: Scenario 4 — rating aggregate (Functions under test)

**Files:**
- Create: `integration_test/rating_test.dart`

**Interfaces:**
- Consumes: harness + `seedMatch`. Asserts the `onRatingCreated` Function updates the target user's aggregate.
- Produces: green `rating_test.dart`.

- [ ] **Step 1: Write the rating test**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'support/app_harness.dart';
import 'support/auth.dart';
import 'support/emulator_admin.dart';
import 'support/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(clearEmulators);

  testWidgets('rating a match updates the target aggregate via Function',
      (tester) async {
    final host = await signInTestUser(uid: 'host-1');
    await seedUserProfile(uid: host.uid);
    final guest = await signInTestUser(uid: 'guest-1');
    await seedUserProfile(uid: guest.uid);
    await signInTestUser(uid: host.uid);
    const matchId = 'match-1';
    await seedMatch(matchId: matchId, hostId: host.uid, guestId: guest.uid);

    await pumpApp(tester);
    // Drive: submit a rating from host about guest (stars=5, showedUp=true)
    // via the rating card UI. Implementer: finders from lib/features/rating.

    // Assert the rating doc exists AND the Function updated guest's aggregate.
    final updated = await pollUntil(() async {
      final u = await FirebaseFirestore.instance
          .collection('users').doc(guest.uid).get();
      final count = (u.data()?['ratingCount'] as num?)?.toInt() ?? 0;
      return count == 1 ? u : null;
    }, timeout: const Duration(seconds: 15));
    expect((updated['ratingAvg'] as num).toDouble(), 5.0);
    expect(updated['ratingCount'], 1);
  });
}
```

- [ ] **Step 2: Run under emulator**

Run: `firebase emulators:exec --only auth,firestore,functions,storage --project not-eat-alone "fvm flutter test integration_test/rating_test.dart"`
Expected: PASS. The 15s poll covers the emulator's async trigger dispatch. If it flakes, raise the timeout, not a fixed sleep.

- [ ] **Step 3: Commit**

```bash
git add integration_test/rating_test.dart
git commit -m "test(e2e): scenario 4 — rating aggregate via onRatingCreated Function"
```

---

### Task 7: CI job + docs

**Files:**
- Modify: `.github/workflows/ci.yml` (add an `e2e` job) — or create `.github/workflows/e2e.yml`
- Modify: `docs/TEST-PLAN.md` (E2E section + manual `stage` smoke checklist)
- Modify: `README.md` (or a `docs/` note) — `make e2e` usage

**Interfaces:**
- Consumes: `make e2e` / the `emulators:exec` command from Task 3.
- Produces: a CI job that runs the E2E suite headless; docs.

- [ ] **Step 1: Read the existing CI workflow** to mirror its Flutter/FVM + Node setup steps and caching.

Run: `sed -n '1,200p' .github/workflows/ci.yml`

- [ ] **Step 2: Add the E2E job** (non-blocking initially — do NOT add to required checks yet)

Job outline (adapt versions/actions to match the existing workflow exactly):

```yaml
  e2e:
    name: E2E (emulator)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - name: Build functions
        working-directory: firebase/functions
        run: npm ci && npm run build
      - name: Install firebase-tools
        run: npm i -g firebase-tools
      - name: Setup Flutter (FVM)
        run: |   # mirror the existing CI's FVM setup + flutter pub get + codegen + cp .env.example .env
      - name: Run E2E on emulators
        run: |
          firebase emulators:exec --only auth,firestore,functions,storage \
            --project not-eat-alone \
            "fvm flutter test integration_test"
```

Implementer: `flutter test integration_test` runs on the headless `flutter-tester` device — no Android emulator/desktop toolchain needed. Reuse the exact `.env` seeding (`cp .env.example .env`) and FVM/codegen steps the existing `Analyze & test` job uses, so this job doesn't fail on the known CI `.env`/codegen gaps.

- [ ] **Step 3: Verify the workflow parses**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('yaml ok')"`
Expected: `yaml ok`.

- [ ] **Step 4: Update `docs/TEST-PLAN.md`**

Add an **E2E (emulator)** subsection (what it covers: rules + Functions + core flows; how to run: `make e2e`) and a **Manual `stage` smoke checklist** (the non-automatable paths): real Google/Apple sign-in button, push (FCM) delivery on a real device, App Check enforcement behaviour, the named `stage` database split. Mark each as user-run pre-release.

- [ ] **Step 5: Update README/run docs**

Add a short "End-to-end tests" section: prerequisites (Node, `firebase-tools`, FVM), `make e2e`, and that it needs no real Firebase project.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows docs/TEST-PLAN.md README.md
git commit -m "ci(e2e): headless emulator E2E job (non-blocking) + test-plan/readme docs"
```

---

### Task 8: Verify whole branch + open PR

- [ ] **Step 1: Full local gate**

Run: `fvm flutter analyze && fvm flutter test` (unit/widget suite stays green) then `make e2e` (all four scenarios green under the emulator).
Expected: analyze clean (info-only pre-existing lints ok), unit/widget PASS, E2E PASS.

- [ ] **Step 2: Push + open PR to develop**

```bash
git push -u origin feature/e2e-emulator
gh pr create --base develop --head feature/e2e-emulator \
  --title "test(e2e): Firebase emulator end-to-end suite (rules + functions + core flows)" \
  --body "<summary of scenarios, one-command run, non-blocking CI job; note the E2E job stays non-required until proven stable>"
```

- [ ] **Step 3: Watch CI, merge when green** (per session convention — confirm with the user before merging).
