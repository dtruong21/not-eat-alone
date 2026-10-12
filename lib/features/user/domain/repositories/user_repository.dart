import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

abstract class UserRepository {
  /// Another person's PUBLIC profile (`profiles/{uid}`): name, photos, bio,
  /// age, rating. Emits `null` when they have none. Never contains `dob` or
  /// `gender`.
  Stream<AppUser?> watch(String uid);

  /// The signed-in user's OWN record: the private `users/{uid}` document
  /// merged with their public profile. Emits `null` until the age gate has
  /// created the private document. Owner-only — other uids are denied by the
  /// security rules.
  Stream<AppUser?> watchOwn(String uid);

  Future<void> upsertAgeVerified({required String uid, required DateTime dob});

  /// Partially updates the profile. Only non-null arguments are written;
  /// omitted fields are left untouched. Name, photos and bio go to the public
  /// profile, `gender` to the private user document.
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    List<String>? photoUrls,
    String? bio,
    Gender? gender,
  });
}
