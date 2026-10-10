/// Firestore-backed implementation of [UserRepository].
///
/// This file is the Firestore BOUNDARY for the `user` feature — it is the
/// only place in `lib/features/user/**` allowed to import `cloud_firestore`.
/// Domain code must go through [UserRepository], never `cloud_firestore`
/// directly.
///
/// Two documents per person:
///   - `profiles/{uid}` — PUBLIC (name, photos, bio, age, rating); any
///     signed-in user may `get` it.
///   - `users/{uid}` — PRIVATE (dob, age-verified, gender); owner only.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/core/util/age.dart';
import 'package:not_eat_alone/features/user/data/dtos/private_user_dto.dart';
import 'package:not_eat_alone/features/user/data/dtos/public_profile_dto.dart';
import 'package:not_eat_alone/features/user/data/mappers/app_user_mapper.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

/// `dob` and `createdAt` are `DateTime` in the model but stored as Firestore
/// `Timestamp`s on disk, so the converters below translate explicitly rather
/// than relying on `toJson()`.
class UserRepositoryImpl implements UserRepository {
  /// Creates a repository over [firestore], or the flavor-aware default
  /// Firestore instance ([db]) when omitted. Tests should inject a fake.
  UserRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? db;

  final FirebaseFirestore _firestore;

  CollectionReference<PrivateUserDto> get _usersRef =>
      _firestore.collection('users').withConverter<PrivateUserDto>(
            fromFirestore: (snapshot, _) => _privateFromFirestore(snapshot),
            toFirestore: (dto, _) => _privateToFirestore(dto),
          );

  CollectionReference<PublicProfileDto> get _profilesRef =>
      _firestore.collection('profiles').withConverter<PublicProfileDto>(
            fromFirestore: (snapshot, _) => _publicFromFirestore(snapshot),
            toFirestore: (dto, _) => dto.toJson(),
          );

  static PrivateUserDto _privateFromFirestore(
    DocumentSnapshot<Map<String, Object?>> snapshot,
  ) {
    try {
      final data = Map<String, Object?>.from(snapshot.data() ?? const {});

      // `Timestamp.toDate()` returns a local (non-UTC) `DateTime` for the
      // same instant. `DateTime`'s equality considers the UTC flag, so
      // normalize to UTC to keep `dob`/`createdAt` consistently UTC.
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

      return PrivateUserDto.fromJson(data);
    } catch (e, st) {
      throw RepositoryParseException('users', snapshot.id, e, st);
    }
  }

  static Map<String, Object?> _privateToFirestore(PrivateUserDto dto) {
    final json = dto.toJson();
    json['dob'] = Timestamp.fromDate(dto.dob);
    json['createdAt'] = dto.createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(dto.createdAt!);
    return json;
  }

  static PublicProfileDto _publicFromFirestore(
    DocumentSnapshot<Map<String, Object?>> snapshot,
  ) {
    try {
      return PublicProfileDto.fromJson(
        Map<String, Object?>.from(snapshot.data() ?? const {}),
      );
    } catch (e, st) {
      throw RepositoryParseException('profiles', snapshot.id, e, st);
    }
  }

  /// Streams `profiles/{uid}` (another person's public profile), emitting
  /// `null` if it doesn't exist.
  @override
  Stream<AppUser?> watch(String uid) {
    return _profilesRef
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data()?.toEntity());
  }

  /// Streams the signed-in user's own record: `users/{uid}` merged with
  /// `profiles/{uid}`. Emits once both have reported at least once; `null`
  /// while the private document doesn't exist.
  ///
  /// Self-healing side effect: the public age is derived from the private
  /// date of birth, which only the owner can read, so when the stored public
  /// age is stale (birthday passed) this owner-side stream rewrites it. It is
  /// idempotent, runs at most once per distinct age, and its failure is
  /// swallowed (the next emission retries only if the age changes again).
  @override
  Stream<AppUser?> watchOwn(String uid) {
    final controller = StreamController<AppUser?>();
    StreamSubscription<DocumentSnapshot<PrivateUserDto>>? privateSub;
    StreamSubscription<DocumentSnapshot<PublicProfileDto>>? publicSub;
    PrivateUserDto? private;
    PublicProfileDto? public;
    var havePrivate = false;
    var havePublic = false;
    int? lastSyncedAge;

    void emit() {
      if (!havePrivate || !havePublic || controller.isClosed) return;
      if (private == null) {
        controller.add(null);
        return;
      }
      controller.add(mergeOwn(private!, public));

      final age = ageFromDob(private!.dob);
      if (private!.ageVerified && public?.age != age && lastSyncedAge != age) {
        lastSyncedAge = age;
        unawaited(
          _firestore
              .collection('profiles')
              .doc(uid)
              .set({'uid': uid, 'age': age}, SetOptions(merge: true))
              .catchError((Object e) {
            debugPrint('[user] public age sync failed: $e');
          }),
        );
      }
    }

    controller
      ..onListen = () {
        try {
          privateSub = _usersRef.doc(uid).snapshots().listen(
            (snapshot) {
              private = snapshot.data();
              havePrivate = true;
              emit();
            },
            onError: controller.addError,
          );
          publicSub = _profilesRef.doc(uid).snapshots().listen(
            (snapshot) {
              public = snapshot.data();
              havePublic = true;
              emit();
            },
            onError: controller.addError,
          );
        } on Object catch (e, st) {
          controller.addError(e, st);
        }
      }
      ..onCancel = () async {
        await privateSub?.cancel();
        await publicSub?.cancel();
      };
    return controller.stream;
  }

  /// Marks [uid] as age-verified with the given [dob] (private document) and
  /// seeds the public profile with the derived age, in one batch.
  @override
  Future<void> upsertAgeVerified({
    required String uid,
    required DateTime dob,
  }) async {
    try {
      final batch = _firestore.batch()
        ..set(
          _usersRef.doc(uid),
          PrivateUserDto(uid: uid, dob: dob, ageVerified: true),
          SetOptions(merge: true),
        )
        ..set(
          _firestore.collection('profiles').doc(uid),
          {'uid': uid, 'age': ageFromDob(dob)},
          SetOptions(merge: true),
        );
      await batch.commit();
    } catch (e, st) {
      throw RepositoryWriteException('users', e, st);
    }
  }

  /// Partially updates the profile with only the provided fields, via raw
  /// (non-converter) merge writes — a partial map isn't a full DTO. Name,
  /// photos and bio go to `profiles/{uid}`; `gender` to `users/{uid}`. Never
  /// touches `dob`/`ageVerified`/`createdAt`/rating fields.
  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    List<String>? photoUrls,
    String? bio,
    Gender? gender,
  }) async {
    final publicData = <String, Object?>{
      if (displayName != null) 'displayName': displayName,
      if (photoUrls != null) 'photoUrls': photoUrls,
      if (bio != null) 'bio': bio,
    };

    try {
      final batch = _firestore.batch();
      if (publicData.isNotEmpty) {
        batch.set(
          _firestore.collection('profiles').doc(uid),
          {'uid': uid, ...publicData},
          SetOptions(merge: true),
        );
      }
      if (gender != null) {
        batch.set(
          _firestore.collection('users').doc(uid),
          {'gender': gender.name},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (e, st) {
      throw RepositoryWriteException('profiles', e, st);
    }
  }
}
