import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

abstract class UserRepository {
  Stream<AppUser?> watch(String uid);
  Future<void> upsertAgeVerified({required String uid, required DateTime dob});

  /// Partially updates the `users/{uid}` profile fields. Only non-null
  /// arguments are written; omitted fields are left untouched.
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    List<String>? photoUrls,
    String? bio,
    Gender? gender,
  });
}
