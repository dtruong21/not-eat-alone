---
description: Scaffold a typed Firestore collection wrapper (Dart + freezed)
argument-hint: <collection name> [field1:type field2:type ...]
---

Scaffold a Firestore repository for: $ARGUMENTS

Create TWO files:

### 1. `lib/core/firebase/<collection>_model.dart`
A freezed model named `<Name>` (PascalCase) with the field:type pairs from args.

```dart
@freezed
class <Name> with _$<Name> {
  const factory <Name>({
    required String id,
    // ...fields from args, mapped Dart-side: string→String, int→int, bool→bool, ts→DateTime, list<T>→List<T>
    @TimestampConverter() DateTime? createdAt,   // server-set, nullable on optimistic snapshot
    @TimestampConverter() DateTime? updatedAt,
  }) = _<Name>;

  factory <Name>.fromJson(Map<String, dynamic> json) => _$<Name>FromJson(json);
}
```
Add `part '<collection>_model.freezed.dart';` and `part '<collection>_model.g.dart';`. Reuse the project-wide `TimestampConverter` from `lib/core/firebase/converters.dart` — create it there if missing.

### 2. `lib/core/firebase/<collection>_repository.dart`
A `<Name>Repository` class plus a Riverpod provider.

```dart
class <Name>Repository {
  <Name>Repository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<<Name>> get _col => _db.collection('<collection>').withConverter<<Name>>(
        fromFirestore: (snap, _) {
          try {
            return <Name>.fromJson({...snap.data()!, 'id': snap.id});
          } catch (e, st) {
            throw StateError('Failed to parse <Name> doc ${snap.id}: $e\n$st');
          }
        },
        toFirestore: (m, _) => m.toJson()..remove('id'),
      );

  Future<<Name>?> get<Name>(String id) async => (await _col.doc(id).get()).data();
  Stream<List<<Name>>> list<Name>s() => _col.snapshots().map((s) => s.docs.map((d) => d.data()).toList());
  Future<String> create<Name>(<Name> data) async {
    final ref = await _col.add(data);
    return ref.id;
  }
  Future<void> update<Name>(String id, Map<String, Object?> patch) => _col.doc(id).update({...patch, 'updatedAt': FieldValue.serverTimestamp()});
  Future<void> delete<Name>(String id) => _col.doc(id).delete();
}

@riverpod
<Name>Repository <name>Repository(<Name>RepositoryRef ref) => <Name>Repository(FirebaseFirestore.instance);
```

Add `part '<collection>_repository.g.dart';` for the `@riverpod` generator.

Constraints:
- `cloud_firestore` may ONLY be imported here and in other files under `lib/core/firebase/`. No SDK imports in features or widgets.
- Throw `StateError` (NOT silently return null) on parse failure with the doc id in the message.
- Server-set timestamp fields must be nullable on the model — `.withConverter` runs on optimistic snapshots before the server roundtrip.
- Run `dart run build_runner build --delete-conflicting-outputs` after.

Output: the two file diffs only. No explanation.
