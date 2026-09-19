/// Typed repository for the `users` collection.
///
/// This file is the Firestore BOUNDARY for `users` — it is the only place
/// allowed to import `cloud_firestore` for this collection. Feature code
/// must go through [UsersRepository], never `cloud_firestore` directly.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/auth/domain/app_user.dart';

/// Repository for reading and writing `users/{uid}` documents.
///
/// `AppUser.dob` and `AppUser.createdAt` are `DateTime` in the model but
/// stored as Firestore `Timestamp`s on disk, so the converter below handles
/// that translation explicitly rather than relying on `AppUser.toJson()`
/// (which would leave them as `DateTime`, which the Firestore SDK can't
/// serialize directly).
class UsersRepository {
  /// Creates a repository over [firestore], or the flavor-aware default
  /// Firestore instance ([db]) when omitted. Tests should inject a fake.
  UsersRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? db;

  final FirebaseFirestore _firestore;

  CollectionReference<AppUser> get _usersRef =>
      _firestore.collection('users').withConverter<AppUser>(
            fromFirestore: (snapshot, _) => _fromFirestore(snapshot),
            toFirestore: (user, _) => _toFirestore(user),
          );

  static AppUser _fromFirestore(
    DocumentSnapshot<Map<String, Object?>> snapshot,
  ) {
    try {
      final data = Map<String, Object?>.from(snapshot.data() ?? const {});

      // `Timestamp.toDate()` returns a local (non-UTC) `DateTime` for the
      // same instant. `DateTime`'s equality considers the UTC flag, so
      // normalize to UTC here to keep `AppUser.dob`/`createdAt`
      // consistently UTC.
      final dob = data['dob'];
      if (dob is Timestamp) {
        data['dob'] = dob.toDate().toUtc().toIso8601String();
      }

      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        data['createdAt'] = createdAt.toDate().toUtc().toIso8601String();
      } else {
        // Nullable on optimistic snapshots — serverTimestamp() hasn't
        // resolved yet, or the field was never set.
        data['createdAt'] = null;
      }

      return AppUser.fromJson(data);
    } catch (e, st) {
      throw RepositoryParseException('users', snapshot.id, e, st);
    }
  }

  static Map<String, Object?> _toFirestore(AppUser user) {
    final json = user.toJson();
    json['dob'] = Timestamp.fromDate(user.dob);
    json['createdAt'] = user.createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(user.createdAt!);
    return json;
  }

  /// Streams the `users/{uid}` document, emitting `null` if it doesn't exist.
  Stream<AppUser?> watch(String uid) {
    return _usersRef.doc(uid).snapshots().map((snapshot) => snapshot.data());
  }

  /// Marks [uid] as age-verified with the given [dob], merging into
  /// `users/{uid}` and stamping `createdAt` with the server time.
  Future<void> upsertAgeVerified({
    required String uid,
    required DateTime dob,
  }) async {
    try {
      await _usersRef.doc(uid).set(
            AppUser(uid: uid, dob: dob, ageVerified: true),
            SetOptions(merge: true),
          );
    } catch (e, st) {
      throw RepositoryWriteException('users', e, st);
    }
  }
}
