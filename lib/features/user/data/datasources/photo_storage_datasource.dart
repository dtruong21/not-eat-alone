/// Firebase Storage-backed datasource for profile photos.
///
/// This file is the Storage BOUNDARY for the `user` feature — it is the
/// only place in `lib/features/user/**` allowed to import `firebase_storage`.
/// Domain/application code must go through [PhotoStorageDataSource].
library;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';

/// Uploads and deletes profile photos in the shared Storage bucket, under
/// an env-prefixed path (`{stage|prod}/users/{uid}/...`) so stage and prod
/// objects never collide — see [FlavorConfig.storagePathPrefix].
class PhotoStorageDataSource {
  /// Creates a datasource over [storage], or the default
  /// [FirebaseStorage.instance] when omitted. Tests should inject a fake.
  PhotoStorageDataSource({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Uploads [bytes] as a JPEG for [uid] at slot [index] and returns its
  /// download URL.
  Future<String> upload({
    required String uid,
    required int index,
    required Uint8List bytes,
  }) async {
    final path = buildPhotoPath(
      FlavorConfig.current.storagePathPrefix,
      uid,
      index,
      DateTime.now().millisecondsSinceEpoch,
    );

    try {
      final ref = _storage.ref().child(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e, st) {
      throw RepositoryWriteException('users/$uid/photos', e, st);
    }
  }

  /// Deletes the object at [url].
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e, st) {
      throw RepositoryWriteException('users/photos', e, st);
    }
  }
}

/// Builds the env-prefixed object path for a profile photo: pure and
/// side-effect free so it's unit-testable without mocking Storage.
@visibleForTesting
String buildPhotoPath(String prefix, String uid, int index, int millis) {
  return '$prefix/users/$uid/photo_${index}_$millis.jpg';
}
