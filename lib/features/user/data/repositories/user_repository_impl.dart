/// Firestore-backed implementation of [UserRepository].
///
/// This file is the Firestore BOUNDARY for the `user` feature — it is the
/// only place in `lib/features/user/**` allowed to import `cloud_firestore`.
/// Domain code must go through [UserRepository], never `cloud_firestore`
/// directly.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/user/data/dtos/app_user_dto.dart';
import 'package:not_eat_alone/features/user/data/mappers/app_user_mapper.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

/// Repository for reading and writing `users/{uid}` documents.
///
/// `AppUserDto.dob` and `AppUserDto.createdAt` are `DateTime` in the model
/// but stored as Firestore `Timestamp`s on disk, so the converter below
/// handles that translation explicitly rather than relying on
/// `AppUserDto.toJson()` (which would leave them as `DateTime`, which the
/// Firestore SDK can't serialize directly).
class UserRepositoryImpl implements UserRepository {
  /// Creates a repository over [firestore], or the flavor-aware default
  /// Firestore instance ([db]) when omitted. Tests should inject a fake.
  UserRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? db;

  final FirebaseFirestore _firestore;

  CollectionReference<AppUserDto> get _usersRef =>
      _firestore.collection('users').withConverter<AppUserDto>(
            fromFirestore: (snapshot, _) => _fromFirestore(snapshot),
            toFirestore: (dto, _) => _toFirestore(dto),
          );

  static AppUserDto _fromFirestore(
    DocumentSnapshot<Map<String, Object?>> snapshot,
  ) {
    try {
      final data = Map<String, Object?>.from(snapshot.data() ?? const {});

      // `Timestamp.toDate()` returns a local (non-UTC) `DateTime` for the
      // same instant. `DateTime`'s equality considers the UTC flag, so
      // normalize to UTC here to keep `AppUserDto.dob`/`createdAt`
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

      return AppUserDto.fromJson(data);
    } catch (e, st) {
      throw RepositoryParseException('users', snapshot.id, e, st);
    }
  }

  static Map<String, Object?> _toFirestore(AppUserDto dto) {
    final json = dto.toJson();
    json['dob'] = Timestamp.fromDate(dto.dob);
    json['createdAt'] = dto.createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(dto.createdAt!);
    return json;
  }

  /// Streams the `users/{uid}` document, emitting `null` if it doesn't exist.
  @override
  Stream<AppUser?> watch(String uid) {
    return _usersRef
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data()?.toEntity());
  }

  /// Marks [uid] as age-verified with the given [dob], merging into
  /// `users/{uid}` and stamping `createdAt` with the server time.
  @override
  Future<void> upsertAgeVerified({
    required String uid,
    required DateTime dob,
  }) async {
    try {
      await _usersRef.doc(uid).set(
            AppUserDto(uid: uid, dob: dob, ageVerified: true),
            SetOptions(merge: true),
          );
    } catch (e, st) {
      throw RepositoryWriteException('users', e, st);
    }
  }

  /// Partially updates `users/{uid}` with only the provided fields, via a
  /// raw (non-converter) merge write — a partial map isn't a full
  /// [AppUserDto], so it can't go through [_usersRef]. Never touches
  /// `dob`/`ageVerified`/`createdAt`.
  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    List<String>? photoUrls,
    String? bio,
    Gender? gender,
  }) async {
    final data = <String, Object?>{
      if (displayName != null) 'displayName': displayName,
      if (photoUrls != null) 'photoUrls': photoUrls,
      if (bio != null) 'bio': bio,
      if (gender != null) 'gender': gender.name,
    };

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e, st) {
      throw RepositoryWriteException('users', e, st);
    }
  }
}
