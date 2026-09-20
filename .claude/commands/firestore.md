---
description: Scaffold a typed Firestore collection wrapper (Dart + freezed, Clean Architecture layers)
argument-hint: <collection name> [field1:type field2:type ...]
---

Scaffold a Clean-Architecture Firestore feature for collection: $ARGUMENTS

Layer boundary (non-negotiable, see `docs/MASTER-SPEC.md` §2a): `presentation → application → domain ← data`. `domain/` has zero Flutter/Firebase imports. `cloud_firestore` may ONLY be imported in this feature's `data/repositories/<collection>_repository_impl.dart`. Reference implementation: `lib/features/user/`.

Create SIX files under `lib/features/<collection>/` (`<Name>` = PascalCase of `<collection>`):

### 1. `domain/entities/<collection>.dart`
Pure freezed entity — NO json, NO `part '*.g.dart'`.

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '<collection>.freezed.dart';

@freezed
abstract class <Name> with _$<Name> {
  const factory <Name>({
    required String id,
    // ...fields from args, mapped Dart-side: string→String, int→int, bool→bool, ts→DateTime, list<T>→List<T>
    DateTime? createdAt,   // server-set, nullable on optimistic snapshot
  }) = _<Name>;
}
```

### 2. `domain/repositories/<collection>_repository.dart`
Abstract interface — no implementation, no Firestore types.

```dart
import 'package:not_eat_alone/features/<collection>/domain/entities/<collection>.dart';

abstract class <Name>Repository {
  Stream<<Name>?> watch(String id);
  // ...additional methods per the feature's needs, e.g.:
  Future<void> upsert(<Name> data);
}
```

### 3. `data/dtos/<collection>_dto.dart`
Freezed + json. Carries `Timestamp`↔`DateTime` (UTC-normalized) handling.

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '<collection>_dto.freezed.dart';
part '<collection>_dto.g.dart';

@freezed
abstract class <Name>Dto with _$<Name>Dto {
  const factory <Name>Dto({
    required String id,
    // ...same fields as the entity
    DateTime? createdAt, // server-set; nullable on optimistic snapshots
  }) = _<Name>Dto;

  factory <Name>Dto.fromJson(Map<String, Object?> json) => _$<Name>DtoFromJson(json);
}
```

### 4. `data/mappers/<collection>_mapper.dart`
Extension methods bridging DTO ↔ entity — no other logic.

```dart
import 'package:not_eat_alone/features/<collection>/data/dtos/<collection>_dto.dart';
import 'package:not_eat_alone/features/<collection>/domain/entities/<collection>.dart';

extension <Name>DtoX on <Name>Dto {
  <Name> toEntity() => <Name>(
        id: id,
        // ...map remaining fields 1:1
        createdAt: createdAt,
      );
}

extension <Name>X on <Name> {
  <Name>Dto toDto() => <Name>Dto(
        id: id,
        // ...map remaining fields 1:1
        createdAt: createdAt,
      );
}
```

### 5. `data/repositories/<collection>_repository_impl.dart`
Implements the domain interface via `.withConverter`. This is the ONLY file in the feature allowed to import `cloud_firestore`.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/<collection>/data/dtos/<collection>_dto.dart';
import 'package:not_eat_alone/features/<collection>/data/mappers/<collection>_mapper.dart';
import 'package:not_eat_alone/features/<collection>/domain/entities/<collection>.dart';
import 'package:not_eat_alone/features/<collection>/domain/repositories/<collection>_repository.dart';

class <Name>RepositoryImpl implements <Name>Repository {
  <Name>RepositoryImpl({FirebaseFirestore? firestore}) : _firestore = firestore ?? db;

  final FirebaseFirestore _firestore;

  CollectionReference<<Name>Dto> get _col =>
      _firestore.collection('<collection>').withConverter<<Name>Dto>(
            fromFirestore: (snap, _) {
              try {
                return <Name>Dto.fromJson({...snap.data()!, 'id': snap.id});
              } catch (e, st) {
                throw RepositoryParseException('<collection>', snap.id, e, st);
              }
            },
            toFirestore: (dto, _) => dto.toJson()..remove('id'),
          );

  @override
  Stream<<Name>?> watch(String id) =>
      _col.doc(id).snapshots().map((snap) => snap.data()?.toEntity());

  @override
  Future<void> upsert(<Name> data) async {
    try {
      await _col.doc(data.id).set(data.toDto(), SetOptions(merge: true));
    } catch (e, st) {
      throw RepositoryWriteException('<collection>', e, st);
    }
  }
}
```

### 6. `application/<collection>_providers.dart`
Binds the impl to the interface. This is the single point allowed to reference the `data` impl type outside `data/`.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/<collection>/data/repositories/<collection>_repository_impl.dart';
import 'package:not_eat_alone/features/<collection>/domain/repositories/<collection>_repository.dart';

final <collection>RepositoryProvider =
    Provider<<Name>Repository>((ref) => <Name>RepositoryImpl());
```

Constraints:
- `cloud_firestore` may ONLY be imported in `data/repositories/<collection>_repository_impl.dart`. No SDK imports in `domain/`, `application/`, `presentation/`, or `core/`.
- Do NOT scaffold anything under `lib/core/firebase/` — that folder holds only `firebase_client.dart`, `repository_exception.dart`, and `options/` (cross-cutting infra), never per-collection repositories.
- Throw `RepositoryParseException`/`RepositoryWriteException` (from `lib/core/firebase/repository_exception.dart`) — NOT a silent `null` return or bare `StateError` — on parse/write failure, with the doc id in the message.
- Server-set timestamp fields must be nullable on both the entity and the DTO — `.withConverter` runs on optimistic snapshots before the server roundtrip.
- `<Name>RepositoryImpl`'s constructor defaults its Firestore instance to `db` from `core/firebase/firebase_client.dart`, with an optional override for tests.
- Run `dart run build_runner build --delete-conflicting-outputs` after.

Output: the six file diffs only. No explanation.
