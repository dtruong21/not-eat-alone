# Requests & Match Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the 1:1 join handshake — a guest requests an open meal, the host approves one from an inbox, which locks the meal, creates a match, and auto-denies the other pending requests.

**Architecture:** New Pragmatic-Clean feature `lib/features/matching/` (domain/data/application/presentation) reusing the `meal` and `user` features. Requests live in top-level `requests/{mealId}_{guestId}`; matches in `matches/{mealId}`. The approve transition is a client-side Firestore transaction on the host's device (Firestore rules already gate meal writes to the host), followed by a batch that denies sibling requests.

**Tech Stack:** Flutter 3.47.4 (FVM), Dart 3.13.3, freezed 4 + json_serializable, Riverpod (manual providers + `@riverpod` AsyncNotifier), cloud_firestore, go_router, flutter_test + mocktail + fake_cloud_firestore.

**Design spec:** `docs/superpowers/specs/2026-09-21-requests-match-design.md`

## Global Constraints

- Always use `fvm flutter` / `fvm dart` (system Flutter differs). Ensure `$HOME/.pub-cache/bin` on PATH.
- Dependency rule: `presentation → application → domain ← data`. `cloud_firestore` imported ONLY in `matching/data/repositories/request_repository_impl.dart`. `domain/` has zero Firebase/Flutter imports.
- Entities are pure freezed (`abstract class X with _$X`, no json). DTOs are freezed + json_serializable. Mappers are extension methods.
- `Timestamp` ↔ `DateTime`: on read translate `Timestamp` → UTC ISO string before `Dto.fromJson` (same as `MealRepositoryImpl._mealFromDoc`); on write use `FieldValue.serverTimestamp()` / `Timestamp.fromDate`.
- Repositories throw `RepositoryParseException` / `RepositoryWriteException` from `core/firebase/repository_exception.dart` — never return null for failure.
- `ref.watch` only in `build()`; inside notifier methods use `ref.read`.
- Analytics fired via `import 'package:not_eat_alone/core/analytics/client.dart' as analytics;` → `analytics.track(Event(...))`. Every event also declared in `events.dart` (sealed `AppEvent`) + mirrored in `docs/TRACKING-PLAN.md`. No PII.
- Tokens (warm-playful) for all colors/spacing/type. No magic numbers. Tests mirror `lib/` under `test/`.
- Codegen after touching freezed/json/`@riverpod`: `fvm dart run build_runner build --delete-conflicting-outputs`.
- Run `fvm flutter analyze` (zero warnings) + `fvm flutter test` green before each commit. CI is billing-blocked — verify locally, ignore red CI.

---

## File Structure

- `lib/features/matching/domain/entities/{request_status,join_request,match}.dart`
- `lib/features/matching/domain/repositories/request_repository.dart`
- `lib/features/matching/data/dtos/{join_request_dto,match_dto}.dart` (+ `.freezed.dart`/`.g.dart`)
- `lib/features/matching/data/mappers/{join_request_mapper,match_mapper}.dart`
- `lib/features/matching/data/repositories/request_repository_impl.dart` (+ `meal_no_longer_open_exception.dart` in `data/`)
- `lib/features/matching/application/{request_providers,meal_request_state_provider,create_request_controller,host_inbox_provider,inbox_action_controller}.dart`
- `lib/features/matching/presentation/request_inbox_screen.dart` + `presentation/widgets/request_inbox_tile.dart`
- Modify: `lib/features/user/application/user_providers.dart` (add `userDocProvider` family), `lib/features/meal/presentation/meal_detail_screen.dart` (live button), `lib/features/meal/presentation/discovery_screen.dart` (inbox badge), `lib/core/routing/router.dart` (+ `/requests`), `lib/core/analytics/events.dart`, `docs/TRACKING-PLAN.md`, `firebase/firestore.rules`, `firebase/firestore.indexes.json`, `docs/TEST-PLAN.md`.

---

## Task 1: Domain — entities + repository interface

**Files:**
- Create: `lib/features/matching/domain/entities/request_status.dart`
- Create: `lib/features/matching/domain/entities/join_request.dart`
- Create: `lib/features/matching/domain/entities/match.dart`
- Create: `lib/features/matching/domain/repositories/request_repository.dart`
- Test: `test/features/matching/domain/join_request_test.dart`

**Interfaces:**
- Produces: `enum RequestStatus { pending, approved, denied }`; `JoinRequest({required String id, required String mealId, required String guestId, required String hostId, @Default(RequestStatus.pending) RequestStatus status, DateTime? createdAt})`; `Match({required String id, required String mealId, required String hostId, required String guestId, DateTime? createdAt})`; `abstract class RequestRepository` with `createRequest({required String mealId, required String guestId, required String hostId})→Future<void>`, `watchRequest({required String mealId, required String guestId})→Stream<JoinRequest?>`, `watchPendingForHost(String hostId)→Stream<List<JoinRequest>>`, `approve(JoinRequest)→Future<void>`, `deny(JoinRequest)→Future<void>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/matching/domain/join_request_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';

void main() {
  test('JoinRequest defaults status to pending', () {
    const r = JoinRequest(id: 'm1_g1', mealId: 'm1', guestId: 'g1', hostId: 'h1');
    expect(r.status, RequestStatus.pending);
    expect(r.createdAt, isNull);
  });

  test('copyWith flips status', () {
    const r = JoinRequest(id: 'm1_g1', mealId: 'm1', guestId: 'g1', hostId: 'h1');
    expect(r.copyWith(status: RequestStatus.approved).status, RequestStatus.approved);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/matching/domain/join_request_test.dart`
Expected: FAIL (target uri doesn't exist).

- [ ] **Step 3: Write the entities + interface**

```dart
// lib/features/matching/domain/entities/request_status.dart
enum RequestStatus { pending, approved, denied }
```

```dart
// lib/features/matching/domain/entities/join_request.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';

part 'join_request.freezed.dart';

@freezed
abstract class JoinRequest with _$JoinRequest {
  const factory JoinRequest({
    required String id,
    required String mealId,
    required String guestId,
    required String hostId,
    @Default(RequestStatus.pending) RequestStatus status,
    DateTime? createdAt,
  }) = _JoinRequest;
}
```

```dart
// lib/features/matching/domain/entities/match.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'match.freezed.dart';

@freezed
abstract class Match with _$Match {
  const factory Match({
    required String id,
    required String mealId,
    required String hostId,
    required String guestId,
    DateTime? createdAt,
  }) = _Match;
}
```

```dart
// lib/features/matching/domain/repositories/request_repository.dart
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';

abstract class RequestRepository {
  /// Guest ([guestId], the current auth uid supplied by the application layer)
  /// creates a pending request for [mealId] hosted by [hostId].
  /// Document id is `"${mealId}_${guestId}"`.
  Future<void> createRequest({
    required String mealId,
    required String guestId,
    required String hostId,
  });

  /// The guest's own request on [mealId] (drives the meal-detail button).
  Stream<JoinRequest?> watchRequest({required String mealId, required String guestId});

  /// All `pending` requests across the host's meals, newest first (the inbox).
  Stream<List<JoinRequest>> watchPendingForHost(String hostId);

  /// Host approves [request]: locks the meal, creates the match, denies siblings.
  /// Throws [MealNoLongerOpenException] when the meal is not `open`.
  Future<void> approve(JoinRequest request);

  /// Host denies a single [request].
  Future<void> deny(JoinRequest request);
}
```

- [ ] **Step 4: Generate + run**

Run: `fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter test test/features/matching/domain/join_request_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/domain test/features/matching/domain
git commit -m "feat(matching): JoinRequest/Match entities + RequestRepository interface"
```

---

## Task 2: DTOs + mappers

**Files:**
- Create: `lib/features/matching/data/dtos/join_request_dto.dart`
- Create: `lib/features/matching/data/dtos/match_dto.dart`
- Create: `lib/features/matching/data/mappers/join_request_mapper.dart`
- Create: `lib/features/matching/data/mappers/match_mapper.dart`
- Test: `test/features/matching/data/join_request_dto_test.dart`

**Interfaces:**
- Consumes: entities from Task 1.
- Produces: `JoinRequestDto`/`MatchDto` (freezed+json); extensions `JoinRequestDtoX.toEntity()`, `JoinRequestX.toDto()`, `MatchDtoX.toEntity()`, `MatchX.toDto()`. `status` serialized as `.name`; a `_statusFromString` guard falls back to `RequestStatus.pending`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/matching/data/join_request_dto_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/data/dtos/join_request_dto.dart';
import 'package:not_eat_alone/features/matching/data/mappers/join_request_mapper.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';

void main() {
  test('round-trips through json with null createdAt', () {
    final dto = JoinRequestDto(
      id: 'm1_g1', mealId: 'm1', guestId: 'g1', hostId: 'h1', status: 'pending',
    );
    final back = JoinRequestDto.fromJson(dto.toJson());
    expect(back.toEntity().status, RequestStatus.pending);
    expect(back.toEntity().createdAt, isNull);
  });

  test('unknown status falls back to pending', () {
    final dto = JoinRequestDto(
      id: 'x', mealId: 'm', guestId: 'g', hostId: 'h', status: 'bogus',
    );
    expect(dto.toEntity().status, RequestStatus.pending);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `fvm flutter test test/features/matching/data/join_request_dto_test.dart`
Expected: FAIL (uri doesn't exist).

- [ ] **Step 3: Write DTOs + mappers**

```dart
// lib/features/matching/data/dtos/join_request_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'join_request_dto.freezed.dart';
part 'join_request_dto.g.dart';

@freezed
abstract class JoinRequestDto with _$JoinRequestDto {
  const factory JoinRequestDto({
    required String id,
    required String mealId,
    required String guestId,
    required String hostId,
    required String status,
    DateTime? createdAt,
  }) = _JoinRequestDto;

  factory JoinRequestDto.fromJson(Map<String, Object?> json) =>
      _$JoinRequestDtoFromJson(json);
}
```

```dart
// lib/features/matching/data/dtos/match_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_dto.freezed.dart';
part 'match_dto.g.dart';

@freezed
abstract class MatchDto with _$MatchDto {
  const factory MatchDto({
    required String id,
    required String mealId,
    required String hostId,
    required String guestId,
    DateTime? createdAt,
  }) = _MatchDto;

  factory MatchDto.fromJson(Map<String, Object?> json) =>
      _$MatchDtoFromJson(json);
}
```

```dart
// lib/features/matching/data/mappers/join_request_mapper.dart
import 'package:not_eat_alone/features/matching/data/dtos/join_request_dto.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';

extension JoinRequestDtoX on JoinRequestDto {
  JoinRequest toEntity() => JoinRequest(
        id: id,
        mealId: mealId,
        guestId: guestId,
        hostId: hostId,
        status: _statusFromString(status),
        createdAt: createdAt,
      );
}

extension JoinRequestX on JoinRequest {
  JoinRequestDto toDto() => JoinRequestDto(
        id: id,
        mealId: mealId,
        guestId: guestId,
        hostId: hostId,
        status: status.name,
        createdAt: createdAt,
      );
}

RequestStatus _statusFromString(String value) {
  try {
    return RequestStatus.values.byName(value);
  } on ArgumentError {
    return RequestStatus.pending;
  }
}
```

```dart
// lib/features/matching/data/mappers/match_mapper.dart
import 'package:not_eat_alone/features/matching/data/dtos/match_dto.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';

extension MatchDtoX on MatchDto {
  Match toEntity() => Match(
        id: id,
        mealId: mealId,
        hostId: hostId,
        guestId: guestId,
        createdAt: createdAt,
      );
}

extension MatchX on Match {
  MatchDto toDto() => MatchDto(
        id: id,
        mealId: mealId,
        hostId: hostId,
        guestId: guestId,
        createdAt: createdAt,
      );
}
```

- [ ] **Step 4: Generate + run**

Run: `fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter test test/features/matching/data/join_request_dto_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/data test/features/matching/data
git commit -m "feat(matching): request/match DTOs + mappers"
```

---

## Task 3: Repository impl — create / watch / deny (no transaction yet)

**Files:**
- Create: `lib/features/matching/data/repositories/meal_no_longer_open_exception.dart`
- Create: `lib/features/matching/data/repositories/request_repository_impl.dart`
- Test: `test/features/matching/data/request_repository_impl_test.dart`

**Interfaces:**
- Consumes: `RequestRepository`, DTOs/mappers, `db`, `RepositoryWriteException`, `RepositoryParseException`.
- Produces: `RequestRepositoryImpl({FirebaseFirestore? firestore})` implementing all interface methods; `MealNoLongerOpenException`. Doc id helper `_requestId(mealId, guestId) => '${mealId}_$guestId'`. `approve` stubbed (`UnimplementedError`) until Task 4.

- [ ] **Step 1: Write the failing test** (create/watch/deny; approve covered in Task 4)

```dart
// test/features/matching/data/request_repository_impl_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/data/repositories/request_repository_impl.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';

void main() {
  late FakeFirebaseFirestore db;
  late RequestRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = RequestRepositoryImpl(firestore: db);
  });

  test('createRequest writes pending with denormalized hostId', () async {
    await repo.createRequest(mealId: 'm1', guestId: 'g1', hostId: 'h1');
    final snap = await db.collection('requests').doc('m1_g1').get();
    expect(snap.data()!['status'], 'pending');
    expect(snap.data()!['hostId'], 'h1');
    expect(snap.data()!['guestId'], 'g1');
  });

  test('watchRequest streams the guest doc then null when absent', () async {
    await repo.createRequestFor(mealId: 'm1', guestId: 'g1', hostId: 'h1');
    final r = await repo.watchRequest(mealId: 'm1', guestId: 'g1').first;
    expect(r!.status, RequestStatus.pending);
    final none = await repo.watchRequest(mealId: 'm1', guestId: 'gX').first;
    expect(none, isNull);
  });

  test('watchPendingForHost returns only this host pending', () async {
    await repo.createRequestFor(mealId: 'm1', guestId: 'g1', hostId: 'h1');
    await repo.createRequestFor(mealId: 'm2', guestId: 'g2', hostId: 'h2');
    final list = await repo.watchPendingForHost('h1').first;
    expect(list.map((r) => r.id), ['m1_g1']);
  });

  test('deny sets a single request to denied', () async {
    await repo.createRequestFor(mealId: 'm1', guestId: 'g1', hostId: 'h1');
    final r = (await repo.watchRequest(mealId: 'm1', guestId: 'g1').first)!;
    await repo.deny(r);
    final after = await db.collection('requests').doc('m1_g1').get();
    expect(after.data()!['status'], 'denied');
  });
}
```

Note: `createRequest` takes `guestId` explicitly (the current auth uid) so the repo stays auth-free and unit-testable; the application-layer controller supplies the uid. This is the signature already defined in Task 1.

- [ ] **Step 2: Run to verify it fails**

Run: `fvm flutter test test/features/matching/data/request_repository_impl_test.dart`
Expected: FAIL (uri doesn't exist).

- [ ] **Step 3: Write the impl**

```dart
// lib/features/matching/data/repositories/meal_no_longer_open_exception.dart
/// Thrown when a host tries to approve a request on a meal that is no longer
/// `open` (already matched, cancelled, or completed).
class MealNoLongerOpenException implements Exception {
  MealNoLongerOpenException(this.mealId);
  final String mealId;
  @override
  String toString() => 'MealNoLongerOpenException($mealId)';
}
```

```dart
// lib/features/matching/data/repositories/request_repository_impl.dart
/// Firestore BOUNDARY for the `matching` feature — the only file in
/// `lib/features/matching/**` allowed to import `cloud_firestore`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/matching/data/dtos/join_request_dto.dart';
import 'package:not_eat_alone/features/matching/data/mappers/join_request_mapper.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/request_repository.dart';
// Task 4 adds: meal_no_longer_open_exception.dart import.

class RequestRepositoryImpl implements RequestRepository {
  RequestRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? db;

  final FirebaseFirestore _firestore;

  String _requestId(String mealId, String guestId) => '${mealId}_$guestId';

  @override
  Future<void> createRequest({
    required String mealId,
    required String guestId,
    required String hostId,
  }) async {
    final id = _requestId(mealId, guestId);
    try {
      await _firestore.collection('requests').doc(id).set({
        'id': id,
        'mealId': mealId,
        'guestId': guestId,
        'hostId': hostId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      throw RepositoryWriteException('requests', e, st);
    }
  }

  @override
  Stream<JoinRequest?> watchRequest({
    required String mealId,
    required String guestId,
  }) {
    return _firestore
        .collection('requests')
        .doc(_requestId(mealId, guestId))
        .snapshots()
        .map((doc) => doc.exists ? _fromDoc(doc.id, doc.data()!) : null);
  }

  @override
  Stream<List<JoinRequest>> watchPendingForHost(String hostId) {
    return _firestore
        .collection('requests')
        .where('hostId', isEqualTo: hostId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => _fromDoc(d.id, d.data()))
            .toList(growable: false));
  }

  @override
  Future<void> deny(JoinRequest request) async {
    try {
      await _firestore
          .collection('requests')
          .doc(request.id)
          .update({'status': 'denied'});
    } catch (e, st) {
      throw RepositoryWriteException('requests', e, st);
    }
  }

  @override
  Future<void> approve(JoinRequest request) {
    throw UnimplementedError('approve lands in Task 4');
  }

  static JoinRequest _fromDoc(String id, Map<String, Object?> raw) {
    try {
      final data = Map<String, Object?>.from(raw)..['id'] = id;
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        data['createdAt'] = createdAt.toDate().toUtc().toIso8601String();
      }
      return JoinRequestDto.fromJson(data).toEntity();
    } catch (e, st) {
      throw RepositoryParseException('requests', id, e, st);
    }
  }
}
```

- [ ] **Step 4: Run**

Run: `fvm flutter test test/features/matching/data/request_repository_impl_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/data/repositories lib/features/matching/domain/repositories test/features/matching/data/request_repository_impl_test.dart
git commit -m "feat(matching): RequestRepositoryImpl create/watch/deny"
```

---

## Task 4: Approve transaction + sibling-deny

**Files:**
- Modify: `lib/features/matching/data/repositories/request_repository_impl.dart`
- Test: `test/features/matching/data/request_repository_approve_test.dart`

**Interfaces:**
- Consumes: `RequestRepositoryImpl`, `MealNoLongerOpenException`, a seeded `meals/{id}` doc with `status`.
- Produces: working `approve(JoinRequest)` — meal→`matched`+`guestId`, request→`approved`, `matches/{mealId}` created, sibling pending requests→`denied`; throws `MealNoLongerOpenException` when the meal is not open.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/matching/data/request_repository_approve_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/data/repositories/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/matching/data/repositories/request_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  late RequestRepositoryImpl repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = RequestRepositoryImpl(firestore: db);
    await db.collection('meals').doc('m1').set({
      'id': 'm1', 'hostId': 'h1', 'status': 'open', 'seats': 1,
    });
    await repo.createRequest(mealId: 'm1', guestId: 'g1', hostId: 'h1');
    await repo.createRequest(mealId: 'm1', guestId: 'g2', hostId: 'h1'); // sibling
    await repo.createRequest(mealId: 'm2', guestId: 'g3', hostId: 'h1'); // other meal
  });

  test('approve locks meal, creates match, denies sibling, spares other meal',
      () async {
    final r1 = (await repo.watchRequest(mealId: 'm1', guestId: 'g1').first)!;
    await repo.approve(r1);

    final meal = await db.collection('meals').doc('m1').get();
    expect(meal.data()!['status'], 'matched');
    expect(meal.data()!['guestId'], 'g1');

    final match = await db.collection('matches').doc('m1').get();
    expect(match.exists, isTrue);
    expect(match.data()!['guestId'], 'g1');
    expect(match.data()!['hostId'], 'h1');

    final approved = await db.collection('requests').doc('m1_g1').get();
    expect(approved.data()!['status'], 'approved');

    final sibling = await db.collection('requests').doc('m1_g2').get();
    expect(sibling.data()!['status'], 'denied');

    final other = await db.collection('requests').doc('m2_g3').get();
    expect(other.data()!['status'], 'pending'); // untouched
  });

  test('approve on a non-open meal throws and writes nothing', () async {
    await db.collection('meals').doc('m1').update({'status': 'matched'});
    final r1 = (await repo.watchRequest(mealId: 'm1', guestId: 'g1').first)!;
    expect(() => repo.approve(r1), throwsA(isA<MealNoLongerOpenException>()));
    final match = await db.collection('matches').doc('m1').get();
    expect(match.exists, isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `fvm flutter test test/features/matching/data/request_repository_approve_test.dart`
Expected: FAIL (`approve` throws UnimplementedError).

- [ ] **Step 3: Implement `approve`**

Add the import and replace the stub:

```dart
import 'package:not_eat_alone/features/matching/data/repositories/meal_no_longer_open_exception.dart';
```

```dart
  @override
  Future<void> approve(JoinRequest request) async {
    final mealRef = _firestore.collection('meals').doc(request.mealId);
    final reqRef = _firestore.collection('requests').doc(request.id);
    final matchRef = _firestore.collection('matches').doc(request.mealId);

    try {
      await _firestore.runTransaction((txn) async {
        final mealSnap = await txn.get(mealRef);
        if (!mealSnap.exists || mealSnap.data()!['status'] != 'open') {
          throw MealNoLongerOpenException(request.mealId);
        }
        txn.update(mealRef, {'status': 'matched', 'guestId': request.guestId});
        txn.update(reqRef, {'status': 'approved'});
        txn.set(matchRef, {
          'id': request.mealId,
          'mealId': request.mealId,
          'hostId': request.hostId,
          'guestId': request.guestId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on MealNoLongerOpenException {
      rethrow;
    } catch (e, st) {
      throw RepositoryWriteException('matches', e, st);
    }

    // Post-commit: deny the losing pending requests. Firestore transactions
    // cannot run queries, so this is a follow-up batch. The meal is already
    // `matched`, so rules block any new pending request from appearing.
    final siblings = await _firestore
        .collection('requests')
        .where('mealId', isEqualTo: request.mealId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (siblings.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in siblings.docs) {
      batch.update(doc.reference, {'status': 'denied'});
    }
    try {
      await batch.commit();
    } catch (e, st) {
      throw RepositoryWriteException('requests', e, st);
    }
  }
```

- [ ] **Step 4: Run**

Run: `fvm flutter test test/features/matching/data/request_repository_approve_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/matching/data/repositories test/features/matching/data/request_repository_approve_test.dart
git commit -m "feat(matching): approve transaction locks meal + creates match + denies siblings"
```

---

## Task 5: Firestore rules + index + deploy

**Files:**
- Modify: `firebase/firestore.rules`
- Modify: `firebase/firestore.indexes.json`
- Test: manual (Rules Playground / emulator) — documented in `docs/TEST-PLAN.md` (Task 8).

**Interfaces:**
- Produces: `requests` + `matches` rule blocks; a composite index on `requests` (`hostId` ASC, `status` ASC, `createdAt` DESC).

- [ ] **Step 1: Add the rule blocks** inside `match /databases/{database}/documents { ... }`, after the `meals` block:

```
    // Join requests: guest creates for an OPEN meal; host reviews.
    match /requests/{requestId} {
      allow read: if isSignedIn()
                  && (resource.data.guestId == request.auth.uid
                      || resource.data.hostId == request.auth.uid);
      allow create: if isSignedIn()
                    && request.resource.data.guestId == request.auth.uid
                    && request.resource.data.status == 'pending'
                    && request.resource.data.hostId != request.auth.uid
                    && exists(/databases/$(database)/documents/meals/$(request.resource.data.mealId))
                    && get(/databases/$(database)/documents/meals/$(request.resource.data.mealId)).data.status == 'open'
                    && get(/databases/$(database)/documents/meals/$(request.resource.data.mealId)).data.hostId == request.resource.data.hostId;
      allow update: if isSignedIn()
                    && resource.data.hostId == request.auth.uid
                    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status']);
      allow delete: if false;
    }

    // Matches: readable by the two parties; created by the host (in the
    // approve transaction); immutable in v1.
    match /matches/{matchId} {
      allow read: if isSignedIn()
                  && (resource.data.hostId == request.auth.uid
                      || resource.data.guestId == request.auth.uid);
      allow create: if isSignedIn()
                    && request.resource.data.hostId == request.auth.uid;
      allow update, delete: if false;
    }
```

- [ ] **Step 2: Add the composite index** to the `indexes` array in `firebase/firestore.indexes.json`:

```json
{
  "collectionGroup": "requests",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "hostId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

- [ ] **Step 3: Deploy to both databases**

Run (deploys rules + indexes to `(default)` and `stage` per the existing multi-db `firebase.json` config):
```bash
firebase deploy --only firestore:rules,firestore:indexes
```
Expected: deploy succeeds for both database targets. (If the environment lacks Firebase CLI auth, note it in the PR and leave the files staged for the user to deploy — same as prior plans.)

- [ ] **Step 4: Commit**

```bash
git add firebase/firestore.rules firebase/firestore.indexes.json
git commit -m "feat(matching): firestore rules + index for requests and matches"
```

---

## Task 6: Analytics events + providers + controllers

**Files:**
- Modify: `lib/core/analytics/events.dart`, `docs/TRACKING-PLAN.md`
- Modify: `lib/features/user/application/user_providers.dart` (add `userDocProvider` family)
- Create: `lib/features/matching/application/request_providers.dart`
- Create: `lib/features/matching/application/meal_request_state_provider.dart`
- Create: `lib/features/matching/application/create_request_controller.dart`
- Create: `lib/features/matching/application/host_inbox_provider.dart`
- Create: `lib/features/matching/application/inbox_action_controller.dart`
- Test: `test/features/matching/application/controllers_test.dart`

**Interfaces:**
- Consumes: `RequestRepository`, `authStateProvider`/`authRepositoryProvider`, `userRepositoryProvider`, `meal` entity.
- Produces: events `JoinRequested(womenOnly)`, `RequestApproved()`, `RequestDenied()`, `MatchCreated(womenOnly)`; `requestRepositoryProvider`; `mealRequestStateProvider` (`StreamProvider.family<JoinRequest?, String>`); `userDocProvider` (`StreamProvider.family<AppUser?, String>`); `CreateRequestController.request(Meal)`; `hostInboxProvider` (`StreamProvider<List<JoinRequest>>`) + `pendingRequestCountProvider` (`Provider<int>`); `InboxActionController.approve(JoinRequest)` / `deny(JoinRequest)`.

- [ ] **Step 1: Add the four events** to `lib/core/analytics/events.dart` (project-specific section):

```dart
final class JoinRequested extends AppEvent {
  const JoinRequested({required this.womenOnly});
  final bool womenOnly;
  @override
  String get name => 'join_requested';
  @override
  Map<String, Object?> get props => {'women_only': womenOnly};
}

final class RequestApproved extends AppEvent {
  const RequestApproved();
  @override
  String get name => 'request_approved';
  @override
  Map<String, Object?> get props => const {};
}

final class RequestDenied extends AppEvent {
  const RequestDenied();
  @override
  String get name => 'request_denied';
  @override
  Map<String, Object?> get props => const {};
}

final class MatchCreated extends AppEvent {
  const MatchCreated({required this.womenOnly});
  final bool womenOnly;
  @override
  String get name => 'match_created';
  @override
  Map<String, Object?> get props => {'women_only': womenOnly};
}
```

Add matching rows to `docs/TRACKING-PLAN.md` (`join_requested` — `women_only`; `request_approved`; `request_denied`; `match_created` — `women_only`; all "No PII").

- [ ] **Step 2: Add providers**

```dart
// lib/features/matching/application/request_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/matching/data/repositories/request_repository_impl.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/request_repository.dart';

final requestRepositoryProvider =
    Provider<RequestRepository>((ref) => RequestRepositoryImpl());
```

```dart
// lib/features/matching/application/meal_request_state_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';

/// The current user's request on [mealId], or null. Drives the meal-detail
/// button. Keyed by mealId; uid comes from auth.
final mealRequestStateProvider =
    StreamProvider.family<JoinRequest?, String>((ref, mealId) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(requestRepositoryProvider).watchRequest(
        mealId: mealId,
        guestId: uid,
      );
});
```

Add `userDocProvider` to `lib/features/user/application/user_providers.dart`:

```dart
/// Any user's `users/{uid}` document — for showing a host/guest profile.
final userDocProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watch(uid);
});
```

```dart
// lib/features/matching/application/host_inbox_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';

/// All pending requests across the signed-in host's meals, newest first.
final hostInboxProvider = StreamProvider<List<JoinRequest>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(requestRepositoryProvider).watchPendingForHost(uid);
});

/// Pending-request count for the discovery app-bar badge (0 when none/loading).
final pendingRequestCountProvider = Provider<int>((ref) {
  return ref.watch(hostInboxProvider).maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
});
```

- [ ] **Step 3: Add the two controllers**

```dart
// lib/features/matching/application/create_request_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';

part 'create_request_controller.g.dart';

@riverpod
class CreateRequestController extends _$CreateRequestController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> request(Meal meal) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authRepositoryProvider).currentUser!.uid;
      await ref.read(requestRepositoryProvider).createRequest(
            mealId: meal.id,
            guestId: uid,
            hostId: meal.hostId,
          );
      await analytics.track(JoinRequested(womenOnly: meal.womenOnly));
    });
  }
}
```

```dart
// lib/features/matching/application/inbox_action_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';

part 'inbox_action_controller.g.dart';

@riverpod
class InboxActionController extends _$InboxActionController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> approve(JoinRequest request) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(requestRepositoryProvider).approve(request);
      await analytics.track(const RequestApproved());
      // women_only not on the request; approve fires match_created without it.
      await analytics.track(const MatchCreated(womenOnly: false));
    });
  }

  Future<void> deny(JoinRequest request) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(requestRepositoryProvider).deny(request);
      await analytics.track(const RequestDenied());
    });
  }
}
```

- [ ] **Step 4: Write the controller test**

```dart
// test/features/matching/application/controllers_test.dart
// Override requestRepositoryProvider + authRepositoryProvider with mocktail
// fakes. Verify: CreateRequestController.request calls createRequest with the
// meal's id/hostId + the auth uid; InboxActionController.approve calls
// repo.approve and leaves state AsyncData; approve error (throw
// MealNoLongerOpenException) leaves state.hasError true; deny calls repo.deny.
// (Analytics track() is a top-level no-op in dev — assert on repo calls, not
// on analytics.)
```

Implement the test with `ProviderContainer(overrides: [...])`, `mocktail` mock repos, `registerFallbackValue` for `JoinRequest`. Assert `verify(() => repo.approve(any())).called(1)` and that an approve throwing `MealNoLongerOpenException` yields `container.read(inboxActionControllerProvider).hasError`.

- [ ] **Step 5: Generate + run + commit**

```bash
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter test test/features/matching/application/controllers_test.dart
git add lib/core/analytics/events.dart docs/TRACKING-PLAN.md lib/features/user/application/user_providers.dart lib/features/matching/application test/features/matching/application
git commit -m "feat(matching): analytics events, providers + request/inbox controllers"
```

---

## Task 7: Meal-detail live request button

**Files:**
- Modify: `lib/features/meal/presentation/meal_detail_screen.dart`
- Test: `test/features/meal/presentation/meal_detail_button_test.dart`

**Interfaces:**
- Consumes: `mealRequestStateProvider(mealId)`, `createRequestControllerProvider`, `authStateProvider` (to detect host-viewing-own-meal).
- Produces: a `_RequestAction` widget rendering four states + a host-owner disabled state.

- [ ] **Step 1: Write the failing widget test** — pump `MealDetailScreen` (or the extracted `_RequestAction`) inside a `ProviderScope` with overrides:
  - `mealRequestStateProvider(mealId)` → `AsyncData(null)` ⇒ finds a **Request to join** button (enabled).
  - → `AsyncData(JoinRequest(status: pending))` ⇒ finds **Requested** text, button disabled.
  - → `AsyncData(status: approved)` ⇒ finds **Matched!** banner text.
  - → `AsyncData(status: denied)` ⇒ finds **Not selected** text.
  - viewer uid == meal.hostId ⇒ no request button (host doesn't request own meal).

```dart
// test/features/meal/presentation/meal_detail_button_test.dart
// Use pumpWidget with ProviderScope(overrides: [
//   mealRequestStateProvider(testMeal.id).overrideWith((ref) => Stream.value(state)),
//   authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: 'guest'))),
// ]). Assert find.text('Request to join') etc. per the five cases above.
```

- [ ] **Step 2: Run to verify it fails**

Run: `fvm flutter test test/features/meal/presentation/meal_detail_button_test.dart`
Expected: FAIL (old stub renders a disabled placeholder, not the state-driven strings).

- [ ] **Step 3: Replace the disabled stub** in `meal_detail_screen.dart` with a `Consumer` that:
  - reads `authStateProvider.value?.uid`; if it equals `meal.hostId`, render nothing (or a subtle "Your meal" chip).
  - else watches `mealRequestStateProvider(meal.id)` and `switch`es on `AsyncValue` + `request?.status`:
    - `null` → `FilledButton('Request to join')` → `ref.read(createRequestControllerProvider.notifier).request(meal)`; show a spinner while `createRequestControllerProvider` is loading.
    - `pending` → disabled button labelled **Requested** + helper text "Waiting for the host".
    - `approved` → a **Matched!** banner ("You're in — chat coming soon").
    - `denied` → disabled **Not selected**.
  - render `loading` (spinner) and `error` (retry) states of `mealRequestStateProvider`.
  - Use warm-playful tokens for all spacing/colour/type.

- [ ] **Step 4: Run**

Run: `fvm flutter test test/features/meal/presentation/meal_detail_button_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/meal/presentation/meal_detail_screen.dart test/features/meal/presentation/meal_detail_button_test.dart
git commit -m "feat(matching): live request button on meal detail (4 states + host guard)"
```

---

## Task 8: Inbox screen + tile + discovery badge + routing + docs

**Files:**
- Create: `lib/features/matching/presentation/request_inbox_screen.dart`
- Create: `lib/features/matching/presentation/widgets/request_inbox_tile.dart`
- Modify: `lib/features/meal/presentation/discovery_screen.dart` (app-bar inbox action + badge)
- Modify: `lib/core/routing/router.dart` (+ `/requests`)
- Modify: `docs/TEST-PLAN.md` (Requests & match feature checklist), memory file
- Test: `test/features/matching/presentation/request_inbox_screen_test.dart`, `test/features/meal/presentation/discovery_inbox_badge_test.dart`

**Interfaces:**
- Consumes: `hostInboxProvider`, `pendingRequestCountProvider`, `inboxActionControllerProvider`, `userDocProvider(guestId)`.
- Produces: `RequestInboxScreen` at `/requests`; `RequestInboxTile`; a badged inbox `IconButton` on discovery.

- [ ] **Step 1: Write the inbox failing test** — pump `RequestInboxScreen` with `hostInboxProvider` overridden:
  - empty list ⇒ **No pending requests** empty state.
  - one request + `userDocProvider(guestId)` → `AsyncData(AppUser(displayName:'Amélie', ...))` ⇒ tile shows the name + **Approve** + **Deny** buttons.
  - error ⇒ error state visible.

- [ ] **Step 2: Run to verify it fails**

Run: `fvm flutter test test/features/matching/presentation/request_inbox_screen_test.dart`
Expected: FAIL (uri doesn't exist).

- [ ] **Step 3: Build the screen + tile**

- `RequestInboxScreen` (`ConsumerWidget`): `Scaffold(appBar: 'Requests')`, body switches on `hostInboxProvider` (`loading`/`error`/empty/list). Each item = `RequestInboxTile(request)`.
- `RequestInboxTile` (`ConsumerWidget`): watch `userDocProvider(request.guestId)` for the guest profile (photo/name/derived age via the existing age helper); its own loading/error tolerated (show a placeholder row). **Approve** → `inboxActionControllerProvider.notifier.approve(request)`; **Deny** → `.deny(request)`. Disable both while `inboxActionControllerProvider` is loading; on `MealNoLongerOpenException` error show a `SnackBar` "This meal is no longer open." Tokens for all styling.

- [ ] **Step 4: Add discovery badge + route**

- In `discovery_screen.dart` app bar `actions`, add an `IconButton(Icons.inbox)` → `context.push('/requests')`, wrapped in a `Badge` showing `ref.watch(pendingRequestCountProvider)` (hidden when 0).
- In `router.dart`, add `GoRoute(path: '/requests', builder: (_, __) => const RequestInboxScreen())`. Confirm `authRedirect` is unaffected (it only special-cases auth/onboarding literal paths).

- [ ] **Step 5: Write the badge test + run all**

`discovery_inbox_badge_test.dart`: override `pendingRequestCountProvider` (or `hostInboxProvider`) → 2 ⇒ badge shows "2"; → 0 ⇒ no badge label. Then:

Run: `fvm flutter test`
Expected: whole suite green.
Run: `fvm flutter analyze`
Expected: zero warnings.

- [ ] **Step 6: Docs + memory + commit**

- Add a **Feature: Requests & match** section to `docs/TEST-PLAN.md` (golden path: request → inbox → approve → meal locks + match + sibling denied → second guest rejected; edge cases: can't request own/non-open meal, denied terminal, badge count; rules manual note).
- Update the memory build-state file: Plan 6 done, branch `plan-6-requests`, matches doc feeds Plan 7.

```bash
git add lib/features/matching/presentation lib/features/meal/presentation/discovery_screen.dart lib/core/routing/router.dart docs/TEST-PLAN.md test/features/matching/presentation test/features/meal/presentation/discovery_inbox_badge_test.dart
git commit -m "feat(matching): request inbox screen + discovery badge + /requests route"
```

---

## Final: verify, build, PR

- [ ] `fvm flutter analyze` clean + `fvm flutter test` green (full suite).
- [ ] Build both flavors: `fvm flutter build apk --flavor stage -t lib/main_stage.dart --debug` (or the project's flavor entrypoints) — confirm compile.
- [ ] Opus whole-branch review; fix any findings; re-review.
- [ ] Push `plan-6-requests`; open PR to `main`.

```bash
git push -u origin plan-6-requests
gh pr create --base main --title "Plan 6: requests & match (1:1 handshake)" --body "..."
```

---

## Self-Review (done at authoring)

- **Spec coverage:** §3 entities→T1; §4 interface→T1/T3; §5 data+transaction→T3/T4; §6 rules+index→T5; §7 application→T6; §8 presentation→T7/T8; §9 analytics→T6; §10 routing→T8; §11 testing spread across T1–T8. All covered.
- **Signature note:** `RequestRepository.createRequest` is finalized to `({required String mealId, required String guestId, required String hostId})` (guestId explicit so the repo stays auth-free; the controller supplies the uid). Task 1's interface stub and Task 3 both use this signature — no drift.
- **`Match` naming:** the entity is `Match` (Dart core has no conflicting `Match`; `RegExpMatch` is separate) — fine.
- **No placeholders:** every code step carries real code; the two most test-heavy steps (T6 controllers, T8 screens) describe exact overrides + assertions rather than dumping full widget trees, which is deliberate, not a gap.
