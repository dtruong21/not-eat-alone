# `lib/core/firebase`

The Firestore boundary. Widgets and providers never import `cloud_firestore` directly — they call methods on a repository from this folder.

## Layout

```
lib/core/firebase/
  firebase_client.dart           initialization + top-level getters (db, auth)
  repository_exception.dart      typed errors thrown by repositories
  <name>_repository.dart         one file per Firestore collection
  README.md                      this file
```

## The contract

1. **One collection = one repository file.** `users/{uid}/feedback/{id}` lives in `feedback_repository.dart`. No multi-collection grab-bags.
2. **`cloud_firestore` may only be imported inside this folder.** Enforced by convention (and a custom lint rule if you add one). Features depend on repository interfaces, never on the SDK.
3. **`.withConverter` + freezed `fromJson` is the only deserialization path.** Every `CollectionReference<Model>` is built with `.withConverter`. `fromFirestore` calls the model's `fromJson` wrapped in try/catch that throws `RepositoryParseException` on failure — never silently return `null`.
4. **Server-set fields are nullable on the model.** `FieldValue.serverTimestamp()` produces `null` in the local optimistic snapshot before the server roundtrip. If `createdAt` is non-nullable, `fromJson` throws on every write. See gotcha #3 in the master spec.
5. **`Timestamp` is not JSON-serializable.** Register a `JsonConverter<DateTime, Timestamp>` and annotate every `DateTime` field with `@TimestampConverter()`. Without it, queries silently break.

## Canonical pattern

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_client.dart';
import 'repository_exception.dart';
import '../../features/feedback/domain/feedback.dart';

class FeedbackRepository {
  FeedbackRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Feedback> _col(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('feedback')
      .withConverter<Feedback>(
        fromFirestore: (snap, _) {
          try {
            return Feedback.fromJson({'id': snap.id, ...snap.data()!});
          } catch (e, st) {
            throw RepositoryParseException('feedback', snap.id, e, st);
          }
        },
        toFirestore: (model, _) => model.toJson()..remove('id'),
      );

  Stream<List<Feedback>> watch(String uid) =>
      _col(uid).orderBy('createdAt', descending: true).snapshots().map(
            (q) => q.docs.map((d) => d.data()).toList(),
          );

  Future<void> create(String uid, Feedback feedback) async {
    try {
      await _col(uid).add(feedback);
    } catch (e, st) {
      throw RepositoryWriteException('feedback', e, st);
    }
  }
}
```

## Adding a collection

Use `/firestore <collection> <field:type> ...` — it scaffolds:

- The freezed model in `lib/features/<feature>/domain/<name>.dart`
- The repository in `lib/core/firebase/<name>_repository.dart`
- A `@riverpod` provider exposing the repository instance

Don't hand-write repositories — the command keeps the converter + error handling consistent across collections.

## Error handling

Repositories throw `RepositoryParseException` (read failed) or `RepositoryWriteException` (write failed). They never return `null` to signal failure. Providers let these propagate into `AsyncValue.error`. UI consumers render an error state — no silent swallowing.

`null` is reserved for valid domain absence ("this user has no feedback yet" — that's `[]`, not `null`; "this doc doesn't exist" — that's `null` from a `Future<T?>` getter).

## Why one file per collection

- **Easy to grep.** `grep -r "collection('feedback')" lib/core/firebase/` finds every touch point in one shot.
- **Single source of `.withConverter`.** Schema drift between read sites is impossible if there's only one read site.
- **Rules + code stay aligned.** When you change `firestore.rules` for a collection, you change exactly one Dart file too.
