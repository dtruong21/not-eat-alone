# Push Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Event-driven push notifications — new request → host, approve/deny → guest, new message → the other party — via FCM token management on the client and the project's first Cloud Functions codebase.

**Architecture:** A Flutter `notifications` feature registers/refreshes FCM tokens into `users/{uid}/fcmTokens/{token}` and routes taps via a pure payload→route mapper. A TypeScript Cloud Functions codebase (firebase-functions v2, region `europe-west1`) reacts to Firestore writes and sends multicasts, pruning invalid tokens. Because of the split databases, every trigger is registered for both `(default)` and `stage`.

**Tech Stack:** Flutter 3.47.4 (FVM), `firebase_messaging ^16.7.0` (already a dependency), Riverpod, cloud_firestore, go_router; Cloud Functions: TypeScript, firebase-functions v2 (`^6`), firebase-admin (`^12`), jest (or vitest) + firebase-functions-test.

**Design spec:** `docs/superpowers/specs/2026-09-22-push-notifications-design.md`

## Global Constraints

- Always use `fvm flutter` / `fvm dart`. `$HOME/.pub-cache/bin` on PATH. Node 20 for Functions.
- Dependency rule: `presentation → application → domain ← data`. `firebase_messaging`/`cloud_firestore` only in `notifications/data/`. `domain/` pure.
- DTO/mapper + `Timestamp`↔`DateTime` conventions as elsewhere; repositories throw `RepositoryWriteException`. `ref.watch` only in build/provider bodies.
- Analytics via the typed registry; no PII. Tokens are private device ids — never logged, never analytics props.
- Tokens (warm-playful) for any UI. Tests mirror `lib/` under `test/`. Firestore single project; rules deploy to both DBs.
- Cloud Functions: TypeScript strict; no secrets in code; handlers never throw on a single bad token (prune + continue); every trigger is registered for BOTH databases.
- Codegen after freezed/`@riverpod`: `fvm dart run build_runner build --delete-conflicting-outputs`.
- `firebase_messaging` is already in pubspec — do NOT re-add it. Live delivery is gated on Blaze + APNs/SHA (user homework) — build + unit-test only.

---

## File Structure

- Native: `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml` (+ a notification-channel/icon resource).
- Flutter: `lib/features/notifications/{domain,data,application}/...`; a foreground/tap listener wired in `lib/core/routing/app_shell.dart` (or a small `lib/core/notifications/push_listener.dart`).
- Functions: `firebase/functions/**` (new).
- Rules: `firebase/firestore.rules`. CI/CD: `.github/workflows/ci.yml`, `deploy.yml`. Docs: `docs/CICD.md`, `docs/TEST-PLAN.md`, memory.

---

## Task 1: Native config + `fcmTokens` rule

**Files:**
- Modify: `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`, `firebase/firestore.rules`
- Create: `android/app/src/main/res/drawable/ic_notification.xml` (a simple monochrome vector icon) — optional if a default exists; otherwise reference the app icon.

**Interfaces:** Produces the native entitlements + the owner-only `fcmTokens` rule. No Dart.

- [ ] **Step 1: iOS Info.plist** — add the background mode (merge with any existing `UIBackgroundModes`):

```xml
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
</array>
```

- [ ] **Step 2: Android manifest** — add inside `<manifest>` (before `<application>`):

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

and inside `<application>` a default FCM notification channel + icon metadata:

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="convyve_default"/>
```

(Create `convyve_default` channel from Dart at startup in Task 5; the meta-data just names it.)

- [ ] **Step 3: `fcmTokens` rule** — in `firebase/firestore.rules`, inside `match /users/{uid} { ... }`, add:

```
      match /fcmTokens/{token} {
        allow read, write: if isOwner(uid);
      }
```

- [ ] **Step 4: Deploy the rule + verify builds.**

Run: `firebase deploy --only firestore:rules` (or note pending-user). Then confirm both flavors still compile:
`fvm flutter build apk --flavor stage -t lib/main_stage.dart --debug`
Expected: rule deploys; build succeeds.

- [ ] **Step 5: Commit.**

```bash
git add ios/Runner/Info.plist android/app/src/main firebase/firestore.rules
git commit -m "feat(push): native notification config + fcmTokens owner-only rule"
```

---

## Task 2: Push domain + pure route mapper

**Files:**
- Create: `lib/features/notifications/domain/entities/push_route.dart`, `lib/features/notifications/domain/repositories/push_repository.dart`, `lib/features/notifications/data/push_route_mapper.dart`
- Test: `test/features/notifications/data/push_route_mapper_test.dart`

**Interfaces:**
- Produces: `PushRoute` (a small value type: `location` String + optional `param`); `mapPushData(Map<String, String?> data) → PushRoute?`; `abstract class PushRepository { Future<bool> requestPermission(); Future<void> registerToken(String uid); Future<void> unregisterCurrentToken(String uid); }`.

- [ ] **Step 1: Failing test.**

```dart
// test/features/notifications/data/push_route_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/notifications/data/push_route_mapper.dart';

void main() {
  test('message payload -> /chats/:matchId', () {
    final r = mapPushData({'type': 'message', 'matchId': 'm1'});
    expect(r!.location, '/chats/m1');
  });
  test('request payload -> /requests', () {
    expect(mapPushData({'type': 'request'})!.location, '/requests');
  });
  test('approved request -> /chats/:mealId', () {
    final r = mapPushData({'type': 'request_update', 'status': 'approved', 'mealId': 'm9'});
    expect(r!.location, '/chats/m9');
  });
  test('denied request -> /discover', () {
    final r = mapPushData({'type': 'request_update', 'status': 'denied', 'mealId': 'm9'});
    expect(r!.location, '/discover');
  });
  test('unknown/missing type -> null', () {
    expect(mapPushData({}), isNull);
    expect(mapPushData({'type': 'nope'}), isNull);
  });
}
```

Run: `fvm flutter test test/features/notifications/data/push_route_mapper_test.dart` — Expected: FAIL.

- [ ] **Step 2: Implement.**

```dart
// lib/features/notifications/domain/entities/push_route.dart
/// A resolved navigation target from a tapped push payload.
class PushRoute {
  const PushRoute(this.location);
  final String location; // a go_router location, e.g. '/chats/m1'
}
```

```dart
// lib/features/notifications/domain/repositories/push_repository.dart
abstract class PushRepository {
  /// Ask the OS for notification permission. Returns whether granted.
  Future<bool> requestPermission();

  /// Register the current device's FCM token under users/{uid}/fcmTokens and
  /// keep it fresh on refresh.
  Future<void> registerToken(String uid);

  /// Delete the current device's token (on sign-out).
  Future<void> unregisterCurrentToken(String uid);
}
```

```dart
// lib/features/notifications/data/push_route_mapper.dart
import 'package:not_eat_alone/features/notifications/domain/entities/push_route.dart';

/// Pure mapping from an FCM data payload to a navigation target. Returns null
/// for unknown/missing types (caller ignores). No side effects.
PushRoute? mapPushData(Map<String, String?> data) {
  switch (data['type']) {
    case 'message':
      final matchId = data['matchId'];
      return matchId == null ? null : PushRoute('/chats/$matchId');
    case 'request':
      return const PushRoute('/requests');
    case 'request_update':
      if (data['status'] == 'approved' && data['mealId'] != null) {
        return PushRoute('/chats/${data['mealId']}');
      }
      return const PushRoute('/discover');
    default:
      return null;
  }
}
```

- [ ] **Step 3: Run + commit.**

```bash
fvm flutter test test/features/notifications/data/push_route_mapper_test.dart
git add lib/features/notifications/domain lib/features/notifications/data/push_route_mapper.dart test/features/notifications/data/push_route_mapper_test.dart
git commit -m "feat(push): PushRepository interface + pure push route mapper"
```

---

## Task 3: Push repository impl (token I/O)

**Files:**
- Create: `lib/features/notifications/data/repositories/push_repository_impl.dart`
- Test: `test/features/notifications/data/push_repository_impl_test.dart`

**Interfaces:**
- Consumes: `PushRepository`, `db`, `RepositoryWriteException`.
- Produces: `PushRepositoryImpl` with an injectable messaging seam so token I/O is testable without the real plugin:

```dart
typedef TokenReader = Future<String?> Function();
typedef PermissionRequester = Future<bool> Function();
```

- [ ] **Step 1: Failing test** (inject a fake token reader + fake firestore; assert the token doc is written/deleted).

```dart
// test/features/notifications/data/push_repository_impl_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/notifications/data/repositories/push_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test('registerToken writes users/{uid}/fcmTokens/{token}', () async {
    final repo = PushRepositoryImpl(
      firestore: db,
      readToken: () async => 'tok123',
      requestPermissionFn: () async => true,
      platformName: 'ios',
    );
    await repo.registerToken('u1');
    final snap = await db.collection('users').doc('u1').collection('fcmTokens').doc('tok123').get();
    expect(snap.exists, isTrue);
    expect(snap.data()!['platform'], 'ios');
  });

  test('unregisterCurrentToken deletes the token doc', () async {
    final repo = PushRepositoryImpl(
      firestore: db, readToken: () async => 'tok123',
      requestPermissionFn: () async => true, platformName: 'ios',
    );
    await repo.registerToken('u1');
    await repo.unregisterCurrentToken('u1');
    final snap = await db.collection('users').doc('u1').collection('fcmTokens').doc('tok123').get();
    expect(snap.exists, isFalse);
  });

  test('registerToken no-ops when token is null', () async {
    final repo = PushRepositoryImpl(
      firestore: db, readToken: () async => null,
      requestPermissionFn: () async => true, platformName: 'android',
    );
    await repo.registerToken('u1');
    final all = await db.collection('users').doc('u1').collection('fcmTokens').get();
    expect(all.docs, isEmpty);
  });
}
```

Run: `fvm flutter test test/features/notifications/data/push_repository_impl_test.dart` — Expected: FAIL.

- [ ] **Step 2: Implement.** Default constructor wires the real `firebase_messaging` seam; tests inject fakes.

```dart
// lib/features/notifications/data/repositories/push_repository_impl.dart
/// Firestore + FCM BOUNDARY for notifications. The messaging calls are behind
/// injectable function seams so token I/O is unit-testable without the plugin.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';

typedef TokenReader = Future<String?> Function();
typedef PermissionRequester = Future<bool> Function();

class PushRepositoryImpl implements PushRepository {
  PushRepositoryImpl({
    FirebaseFirestore? firestore,
    TokenReader? readToken,
    PermissionRequester? requestPermissionFn,
    String? platformName,
  })  : _firestore = firestore ?? db,
        _readToken = readToken ?? _defaultReadToken,
        _requestPermission = requestPermissionFn ?? _defaultRequestPermission,
        _platform = platformName ?? _defaultPlatform();

  final FirebaseFirestore _firestore;
  final TokenReader _readToken;
  final PermissionRequester _requestPermission;
  final String _platform;

  static Future<String?> _defaultReadToken() =>
      FirebaseMessaging.instance.getToken();

  static Future<bool> _defaultRequestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static String _defaultPlatform() =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  @override
  Future<bool> requestPermission() => _requestPermission();

  @override
  Future<void> registerToken(String uid) async {
    final token = await _readToken();
    if (token == null || token.isEmpty) return;
    try {
      await _tokenDoc(uid, token).set({
        'token': token,
        'platform': _platform,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      throw RepositoryWriteException('fcmTokens', e, st);
    }
  }

  @override
  Future<void> unregisterCurrentToken(String uid) async {
    final token = await _readToken();
    if (token == null || token.isEmpty) return;
    try {
      await _tokenDoc(uid, token).delete();
    } catch (e, st) {
      throw RepositoryWriteException('fcmTokens', e, st);
    }
  }

  DocumentReference<Map<String, Object?>> _tokenDoc(String uid, String token) =>
      _firestore.collection('users').doc(uid).collection('fcmTokens').doc(token);
}
```

- [ ] **Step 3: Run + commit.**

```bash
fvm flutter test test/features/notifications/data/push_repository_impl_test.dart
git add lib/features/notifications/data/repositories test/features/notifications/data/push_repository_impl_test.dart
git commit -m "feat(push): PushRepositoryImpl token registration I/O"
```

---

## Task 4: Registration controller + providers + analytics

**Files:**
- Modify: `lib/core/analytics/events.dart`, `docs/TRACKING-PLAN.md`
- Create: `lib/features/notifications/application/push_providers.dart`, `lib/features/notifications/application/push_registration_controller.dart`
- Test: `test/features/notifications/application/push_registration_controller_test.dart`

**Interfaces:**
- Produces: events `PushPermissionGranted(granted)`, `PushOpened(type)`; `pushRepositoryProvider`; `PushRegistrationController.register(uid)` / `unregister(uid)`.

- [ ] **Step 1: Events** in `events.dart` (project section) + `docs/TRACKING-PLAN.md` rows (no PII):

```dart
final class PushPermissionGranted extends AppEvent {
  const PushPermissionGranted({required this.granted});
  final bool granted;
  @override
  String get name => 'push_permission_granted';
  @override
  Map<String, Object?> get props => {'granted': granted};
}

final class PushOpened extends AppEvent {
  const PushOpened({required this.type});
  final String type;
  @override
  String get name => 'push_opened';
  @override
  Map<String, Object?> get props => {'type': type};
}
```

- [ ] **Step 2: Providers + controller.**

```dart
// lib/features/notifications/application/push_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/notifications/data/repositories/push_repository_impl.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';

final pushRepositoryProvider =
    Provider<PushRepository>((ref) => PushRepositoryImpl());
```

```dart
// lib/features/notifications/application/push_registration_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/notifications/application/push_providers.dart';

part 'push_registration_controller.g.dart';

@riverpod
class PushRegistrationController extends _$PushRegistrationController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Request permission then register the device token for [uid]. Safe to call
  /// on every app start for a signed-in, onboarded user.
  Future<void> register(String uid) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(pushRepositoryProvider);
      final granted = await repo.requestPermission();
      await analytics.track(PushPermissionGranted(granted: granted));
      if (granted) {
        await repo.registerToken(uid);
      }
    });
  }

  Future<void> unregister(String uid) async {
    await ref.read(pushRepositoryProvider).unregisterCurrentToken(uid);
  }
}
```

- [ ] **Step 3: Controller test** — override `pushRepositoryProvider` (mocktail): `register` with permission→true registers the token + fires `push_permission_granted`; permission→false does NOT call `registerToken`; `unregister` calls `unregisterCurrentToken`. (Don't assert analytics values; assert repo calls.)

- [ ] **Step 4: Generate + run + commit.**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter test test/features/notifications/application/push_registration_controller_test.dart
git add lib/core/analytics/events.dart docs/TRACKING-PLAN.md lib/features/notifications/application test/features/notifications/application
git commit -m "feat(push): registration controller + providers + analytics"
```

---

## Task 5: Foreground + tap wiring in the shell

**Files:**
- Create: `lib/core/notifications/push_listener.dart`
- Modify: `lib/core/routing/app_shell.dart` (mount the listener), and the app init / sign-in flow to call `PushRegistrationController.register(uid)` and sign-out to `unregister`.
- Test: `test/core/notifications/push_listener_test.dart` (widget test of the foreground banner + that a tapped payload navigates via the mapper)

**Interfaces:**
- Consumes: `mapPushData`, `pushRegistrationControllerProvider`, `routerProvider`, `authStateProvider`.
- Produces: a `PushListener` widget (a `ConsumerStatefulWidget` wrapping the shell body) that: on first build for a signed-in uid, calls `register(uid)`; subscribes to `FirebaseMessaging.onMessage` (foreground → show a `SnackBar`/banner via the messenger) and `onMessageOpenedApp` + `getInitialMessage()` (→ `mapPushData` → `router.go(route.location)` + fire `PushOpened`).

- [ ] **Step 1: Write the listener** (guarded so it registers once; navigation uses the `routerProvider`'s router). Keep the `FirebaseMessaging` stream calls behind a small seam or accept them directly but guard tests by overriding providers. For the widget test, expose the tap handler as a testable method `handleMessageData(Map<String,String?>)` that maps + navigates, and assert navigation with a fake router / a spy.

- [ ] **Step 2: Mount** `PushListener` around the shell in `app_shell.dart` (wrap `navigationShell`), and wire `register`/`unregister`:
  - After sign-in / on shell mount for a signed-in+onboarded uid → `ref.read(pushRegistrationControllerProvider.notifier).register(uid)`.
  - In the existing sign-out action (discovery/profile) → `await ref.read(pushRegistrationControllerProvider.notifier).unregister(uid)` before signing out.
  - Create the Android notification channel `convyve_default` at startup (in `main_common.dart` or the listener init) via `firebase_messaging` / a `flutter_local_notifications`-free approach: the meta-data channel id suffices for system-tray display; a foreground banner is our own SnackBar, so no `flutter_local_notifications` dependency is added in v1.

- [ ] **Step 3: Test** the pure tap→navigate path (`handleMessageData` maps 'message'→/chats/:id and calls the router; unknown→no-op) with an overridden router spy. Foreground SnackBar: pump the listener, push a fake foreground message through the injected stream, assert the banner text appears. (Keep the `FirebaseMessaging` streams injectable so the test drives them.)

- [ ] **Step 4: Run + commit.**

```bash
fvm flutter test test/core/notifications/
git add lib/core/notifications lib/core/routing/app_shell.dart lib/main_common.dart lib/features/meal/presentation/discovery_screen.dart
git commit -m "feat(push): foreground banner + tap deep-link wiring + register/unregister lifecycle"
```

(Adjust the exact sign-out file in the `git add` to wherever sign-out lives.)

---

## Task 6: Cloud Functions scaffold

**Files:**
- Create: `firebase/functions/package.json`, `tsconfig.json`, `.eslintrc.cjs`, `.gitignore`, `src/index.ts` (empty exports), `firebase/functions/README.md`
- Modify: root `.gitignore` (ensure `firebase/functions/node_modules` + `firebase/functions/lib` ignored)

**Interfaces:** Produces a compiling TypeScript Functions project (`npm ci && npm run build` succeeds; `npm test` runs zero/placeholder tests).

- [ ] **Step 1: package.json.**

```json
{
  "name": "convyve-functions",
  "private": true,
  "engines": { "node": "20" },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "lint": "eslint --ext .ts src",
    "test": "jest"
  },
  "dependencies": {
    "firebase-admin": "^12.7.0",
    "firebase-functions": "^6.1.0"
  },
  "devDependencies": {
    "@types/jest": "^29.5.14",
    "@typescript-eslint/eslint-plugin": "^8.0.0",
    "@typescript-eslint/parser": "^8.0.0",
    "eslint": "^8.57.0",
    "firebase-functions-test": "^3.4.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.5",
    "typescript": "^5.6.0"
  }
}
```

- [ ] **Step 2: tsconfig.json.**

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2021",
    "lib": ["es2021"],
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "noImplicitReturns": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "sourceMap": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "test"]
}
```

- [ ] **Step 3: jest config + eslint + gitignore + placeholder index.**

`jest.config.js`:
```js
module.exports = { preset: 'ts-jest', testEnvironment: 'node', testMatch: ['**/test/**/*.test.ts'] };
```

`.eslintrc.cjs`:
```js
module.exports = {
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended'],
  parserOptions: { ecmaVersion: 2021, sourceType: 'module' },
  ignorePatterns: ['lib/', 'node_modules/'],
  env: { node: true, es2021: true },
};
```

`firebase/functions/.gitignore`:
```
node_modules/
lib/
```

`src/index.ts`:
```ts
// Cloud Functions entrypoint. Triggers are added in Task 8.
export {};
```

- [ ] **Step 4: Verify + commit.**

Run (in `firebase/functions`): `npm install && npm run build && npm test`
Expected: build succeeds; jest reports no tests (or a trivial pass) without error.

```bash
git add firebase/functions .gitignore
git commit -m "feat(push): Cloud Functions TypeScript scaffold"
```

---

## Task 7: Functions pure helpers (payloads + prune) + tests

**Files:**
- Create: `firebase/functions/src/lib/payloads.ts`, `firebase/functions/src/lib/prune.ts`, `firebase/functions/test/payloads.test.ts`, `firebase/functions/test/prune.test.ts`

**Interfaces:**
- Produces: `buildRequestCreated()`, `buildRequestUpdated(status)`, `buildMessageCreated(senderName, text)` → `{notification:{title,body}, data:{type,...}}`; `tokensToPrune(tokens: string[], responses: {success:boolean, error?:{code:string}}[]) → string[]`.

- [ ] **Step 1: Failing tests.**

```ts
// firebase/functions/test/payloads.test.ts
import { buildMessageCreated, buildRequestUpdated } from '../src/lib/payloads';

test('message payload truncates long text and carries matchId via caller', () => {
  const p = buildMessageCreated('Amélie', 'x'.repeat(500));
  expect(p.notification.title).toBe('Amélie');
  expect(p.notification.body.length).toBeLessThanOrEqual(120);
  expect(p.data.type).toBe('message');
});

test('request_update approved vs denied body differs', () => {
  expect(buildRequestUpdated('approved').data.status).toBe('approved');
  expect(buildRequestUpdated('denied').data.status).toBe('denied');
});
```

```ts
// firebase/functions/test/prune.test.ts
import { tokensToPrune } from '../src/lib/prune';

test('prunes only not-registered / invalid tokens', () => {
  const tokens = ['a', 'b', 'c'];
  const responses = [
    { success: true },
    { success: false, error: { code: 'messaging/registration-token-not-registered' } },
    { success: false, error: { code: 'messaging/internal-error' } },
  ];
  expect(tokensToPrune(tokens, responses)).toEqual(['b']);
});
```

Run (in `firebase/functions`): `npm test` — Expected: FAIL (modules missing).

- [ ] **Step 2: Implement.**

```ts
// firebase/functions/src/lib/payloads.ts
export interface PushPayload {
  notification: { title: string; body: string };
  data: Record<string, string>;
}

const truncate = (s: string, n = 120): string =>
  s.length <= n ? s : `${s.slice(0, n - 1)}…`;

export function buildRequestCreated(): PushPayload {
  return {
    notification: { title: 'New request', body: 'Someone wants to join your meal.' },
    data: { type: 'request' },
  };
}

export function buildRequestUpdated(status: 'approved' | 'denied', mealId = ''): PushPayload {
  const approved = status === 'approved';
  return {
    notification: {
      title: approved ? "You're in!" : 'Request update',
      body: approved ? 'Your request was approved — say hi.' : 'Your request was declined.',
    },
    data: { type: 'request_update', status, mealId },
  };
}

export function buildMessageCreated(senderName: string, text: string, matchId = ''): PushPayload {
  return {
    notification: { title: senderName, body: truncate(text) },
    data: { type: 'message', matchId },
  };
}
```

```ts
// firebase/functions/src/lib/prune.ts
export interface SendResponse { success: boolean; error?: { code: string } }

const PRUNE_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

export function tokensToPrune(tokens: string[], responses: SendResponse[]): string[] {
  const out: string[] = [];
  responses.forEach((r, i) => {
    if (!r.success && r.error && PRUNE_CODES.has(r.error.code)) out.push(tokens[i]);
  });
  return out;
}
```

- [ ] **Step 3: Run + commit.**

Run (in `firebase/functions`): `npm run build && npm test` — Expected: PASS.

```bash
git add firebase/functions/src/lib firebase/functions/test
git commit -m "feat(push): functions payload builders + token-prune helper + tests"
```

---

## Task 8: Functions triggers (both databases) + sendToUser

**Files:**
- Create: `firebase/functions/src/lib/messaging.ts`, `firebase/functions/src/triggers/request_created.ts`, `request_updated.ts`, `message_created.ts`
- Modify: `firebase/functions/src/index.ts`

**Interfaces:**
- Produces six exported functions (3 events × 2 databases), each calling a shared handler; `sendToUser(databaseId, uid, payload)` reads tokens, multicasts, prunes.

- [ ] **Step 1: `messaging.ts`.**

```ts
// firebase/functions/src/lib/messaging.ts
import { getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { PushPayload } from './payloads';
import { tokensToPrune, SendResponse } from './prune';

export async function sendToUser(
  databaseId: string,
  uid: string,
  payload: PushPayload,
): Promise<void> {
  const db = getFirestore(getApp(), databaseId);
  const snap = await db.collection('users').doc(uid).collection('fcmTokens').get();
  const tokens = snap.docs.map((d) => d.id);
  if (tokens.length === 0) return;

  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: payload.notification,
    data: payload.data,
  });

  const responses: SendResponse[] = res.responses.map((r) => ({
    success: r.success,
    error: r.error ? { code: r.error.code } : undefined,
  }));
  const prune = tokensToPrune(tokens, responses);
  await Promise.all(
    prune.map((t) => db.collection('users').doc(uid).collection('fcmTokens').doc(t).delete()),
  );
}
```

- [ ] **Step 2: Triggers.** Each file exports a factory taking `database` and returning a v2 trigger.

```ts
// firebase/functions/src/triggers/request_created.ts
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { sendToUser } from '../lib/messaging';
import { buildRequestCreated } from '../lib/payloads';

export const makeRequestCreated = (database: string) =>
  onDocumentCreated(
    { document: 'requests/{requestId}', database, region: 'europe-west1' },
    async (event) => {
      const data = event.data?.data();
      const hostId = data?.hostId as string | undefined;
      if (!hostId) return;
      await sendToUser(database, hostId, buildRequestCreated());
    },
  );
```

```ts
// firebase/functions/src/triggers/request_updated.ts
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { sendToUser } from '../lib/messaging';
import { buildRequestUpdated } from '../lib/payloads';

export const makeRequestUpdated = (database: string) =>
  onDocumentUpdated(
    { document: 'requests/{requestId}', database, region: 'europe-west1' },
    async (event) => {
      const before = event.data?.before.data();
      const after = event.data?.after.data();
      if (!before || !after) return;
      const status = after.status as string;
      if (before.status === status) return;
      if (status !== 'approved' && status !== 'denied') return;
      const guestId = after.guestId as string | undefined;
      if (!guestId) return;
      await sendToUser(
        database,
        guestId,
        buildRequestUpdated(status, (after.mealId as string) ?? ''),
      );
    },
  );
```

```ts
// firebase/functions/src/triggers/message_created.ts
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { sendToUser } from '../lib/messaging';
import { buildMessageCreated } from '../lib/payloads';

export const makeMessageCreated = (database: string) =>
  onDocumentCreated(
    { document: 'matches/{matchId}/messages/{messageId}', database, region: 'europe-west1' },
    async (event) => {
      const msg = event.data?.data();
      const matchId = event.params.matchId;
      const senderId = msg?.senderId as string | undefined;
      const text = (msg?.text as string) ?? '';
      if (!senderId) return;

      const db = getFirestore(getApp(), database);
      const matchSnap = await db.collection('matches').doc(matchId).get();
      const participants = (matchSnap.data()?.participants as string[]) ?? [];
      const recipient = participants.find((p) => p !== senderId);
      if (!recipient) return;

      const senderSnap = await db.collection('users').doc(senderId).get();
      const senderName = (senderSnap.data()?.displayName as string) ?? 'New message';

      await sendToUser(database, recipient, buildMessageCreated(senderName, text, matchId));
    },
  );
```

- [ ] **Step 3: `index.ts` — init admin once, export both DBs.**

```ts
// firebase/functions/src/index.ts
import { initializeApp } from 'firebase-admin/app';
import { makeRequestCreated } from './triggers/request_created';
import { makeRequestUpdated } from './triggers/request_updated';
import { makeMessageCreated } from './triggers/message_created';

initializeApp();

export const requestCreatedDefault = makeRequestCreated('(default)');
export const requestCreatedStage = makeRequestCreated('stage');
export const requestUpdatedDefault = makeRequestUpdated('(default)');
export const requestUpdatedStage = makeRequestUpdated('stage');
export const messageCreatedDefault = makeMessageCreated('(default)');
export const messageCreatedStage = makeMessageCreated('stage');
```

- [ ] **Step 4: Verify compile + commit.**

Run (in `firebase/functions`): `npm run build && npm test`
Expected: tsc compiles; tests pass. (Trigger handlers aren't unit-tested here — the pure helpers they call are; live behavior is emulator/device, documented in Task 9.)

```bash
git add firebase/functions/src
git commit -m "feat(push): request/message Cloud Functions triggers (both databases)"
```

---

## Task 9: CI/CD wiring + docs

**Files:**
- Modify: `.github/workflows/ci.yml`, `.github/workflows/deploy.yml`, `docs/CICD.md`, `docs/TEST-PLAN.md`, memory build-state

**Interfaces:** Produces a `functions-build` CI job + `functions` in the CD deploy, plus docs.

- [ ] **Step 1: CI `functions-build` job** — add to `ci.yml`:

```yaml
  functions-build:
    name: Functions build & test
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: firebase/functions
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm run build
      - run: npm test
```

(Requires a committed `firebase/functions/package-lock.json` — generate it in Task 6/here via `npm install` and commit it.)

- [ ] **Step 2: CD `functions`** — in `deploy.yml`'s deploy step, add a functions install before deploy and extend `--only`:

```yaml
      - name: Install functions deps
        if: steps.guard.outputs.present == 'true'
        run: npm --prefix firebase/functions ci
      - name: Deploy Firestore + Storage + Functions
        if: steps.guard.outputs.present == 'true'
        run: |
          npx --yes firebase-tools@13 deploy \
            --only firestore,storage,functions \
            --project not-eat-alone \
            --non-interactive
```

(Replace the prior firestore,storage-only deploy step. Functions deploy needs the Blaze plan + the service account's Cloud Functions Admin role — documented.)

- [ ] **Step 3: Docs.**
- `docs/CICD.md`: add that Functions require **Blaze**, deploy region `europe-west1`, the `functions-build` gate, and the service-account role needed.
- `docs/TEST-PLAN.md`: add a **Feature: Push notifications** section (golden path via emulator/device: create a request → host device gets a push → tap opens `/requests`; send a message → other device push → opens the chat; edge: no-token user = no-op; token pruned on invalid; owner-only `fcmTokens` rule; **live delivery pending Blaze + APNs + SHA**).
- Memory build-state: Plan 8 built on `feature/plan-8-push` — FCM tokens, first Functions codebase (TS, europe-west1, both DBs), CD now includes functions (gated on Blaze + secret), reminders deferred.

- [ ] **Step 4: Commit.**

```bash
git add .github/workflows/ci.yml .github/workflows/deploy.yml docs/CICD.md docs/TEST-PLAN.md firebase/functions/package-lock.json
git commit -m "ci(push): functions build gate + functions in CD deploy + docs"
```

---

## Final: verify, build, PR

- [ ] `fvm flutter analyze` clean + `fvm flutter test` green; `npm --prefix firebase/functions run build && npm --prefix firebase/functions test` green.
- [ ] Build both flavors (compile-verify) — confirm the native config didn't break the build.
- [ ] Opus whole-branch review; fix findings; re-review.
- [ ] Push `feature/plan-8-push`; open PR to **`develop`**. CI (incl. the new functions-build job) gates it.

```bash
git push -u origin feature/plan-8-push
gh pr create --base develop --title "Plan 8: push notifications (FCM + Cloud Functions)" --body "..."
```

---

## Self-Review (done at authoring)

- **Spec coverage:** client feature §2 → T2–T5; native §2 → T1; Functions §3 → T6–T8; rules §4 → T1; CI/CD §5 → T9; analytics §6 → T4; testing §7 across T2/T3/T4/T5/T7; non-goals §8 respected (no scheduled reminders/post-meal). Covered.
- **Type consistency:** `PushRepository` signatures identical in T2 (interface), T3 (impl), T4 (provider/controller). `mapPushData` (T2) consumed by the shell listener (T5). `buildMessageCreated`/`buildRequestUpdated`/`tokensToPrune` (T7) consumed by triggers/messaging (T8). `data.type` values (`message`/`request`/`request_update`) match between the Functions payloads (T7) and the client mapper (T2) — verified: message→matchId, request_update→status+mealId.
- **Both-databases:** every trigger exported twice in `index.ts` (T8); `sendToUser` reads from the triggering `databaseId`.
- **Ordering:** Functions scaffold (T6) compiles before helpers (T7) and triggers (T8); CI functions-build (T9) added after the project + lockfile exist. Client tasks (T2–T5) are independent of Functions and can interleave.
- **No placeholders:** pure/testable code is given in full; the shell-wiring test (T5) and trigger handlers (T8, live behavior) are described with the injectable seams that make them testable, deliberately.
