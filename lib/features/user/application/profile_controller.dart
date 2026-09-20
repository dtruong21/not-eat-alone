/// Profile controller — Riverpod `AsyncNotifier` orchestrating profile
/// writes (display name, gender, bio, photos) across [UserRepository] and
/// [PhotoStorageDataSource].
///
/// No domain of its own here (pragmatic Clean Architecture, same shape as
/// `AgeGateController`): it reads [userRepositoryProvider],
/// [authRepositoryProvider] and [photoStorageDataSourceProvider] directly
/// rather than owning a repository interface.
///
/// Pattern (master spec idiom #1):
///   - `build()` returns the initial value — `AsyncData(null)`, nothing in
///     flight.
///   - Each mutating method sets `state = const AsyncValue.loading()` then
///     `state = await AsyncValue.guard(() => ...)`. Errors propagate into
///     `state.error` automatically instead of throwing — the screen renders
///     them rather than crashing.
///   - Inside methods after `build()`, use `ref.read` only.
library;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/user/application/photo_storage_provider.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

part 'profile_controller.g.dart';

/// Maximum number of profile photos a user may have.
const _maxPhotos = 6;

@riverpod
class ProfileController extends _$ProfileController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  /// Writes the required fields for forced onboarding setup (name, gender,
  /// optional bio) and fires `profile_completed`. The screen enforces the
  /// ≥1-photo precondition before calling this.
  Future<void> completeSetup({
    required String displayName,
    required Gender gender,
    String? bio,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authRepositoryProvider).currentUser!.uid;
      await ref.read(userRepositoryProvider).updateProfile(
            uid: uid,
            displayName: displayName,
            gender: gender,
            bio: bio,
          );
      await analytics.track(const ProfileCompleted());
    });
  }

  /// Saves an edit from the settings screen and fires `profile_edited`.
  Future<void> save({String? displayName, String? bio, Gender? gender}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authRepositoryProvider).currentUser!.uid;
      await ref.read(userRepositoryProvider).updateProfile(
            uid: uid,
            displayName: displayName,
            bio: bio,
            gender: gender,
          );
      await analytics.track(const ProfileEdited());
    });
  }

  /// Uploads [bytes] as the next photo slot and appends its URL to the
  /// user's `photoUrls`. No-ops once the cap of [_maxPhotos] is reached.
  Future<void> addPhoto(Uint8List bytes) async {
    final current = ref.read(currentUserDocProvider).value?.photoUrls ?? [];
    if (current.length >= _maxPhotos) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authRepositoryProvider).currentUser!.uid;
      final url = await ref.read(photoStorageDataSourceProvider).upload(
            uid: uid,
            index: current.length,
            bytes: bytes,
          );
      await ref.read(userRepositoryProvider).updateProfile(
            uid: uid,
            photoUrls: [...current, url],
          );
      await analytics.track(ProfilePhotoAdded(count: current.length + 1));
    });
  }

  /// Removes [url] from the user's `photoUrls` and deletes the underlying
  /// Storage object.
  Future<void> removePhoto(String url) async {
    final current = ref.read(currentUserDocProvider).value?.photoUrls ?? [];

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authRepositoryProvider).currentUser!.uid;
      final updated = current.where((u) => u != url).toList();
      await ref.read(userRepositoryProvider).updateProfile(
            uid: uid,
            photoUrls: updated,
          );
      await ref.read(photoStorageDataSourceProvider).deleteByUrl(url);
    });
  }
}
