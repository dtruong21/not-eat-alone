import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

abstract class UserRepository {
  Stream<AppUser?> watch(String uid);
  Future<void> upsertAgeVerified({required String uid, required DateTime dob});
}
