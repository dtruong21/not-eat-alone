import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

part 'app_user.freezed.dart';

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    required DateTime dob,
    @Default(false) bool ageVerified,
    DateTime? createdAt,
    String? displayName,
    @Default(<String>[]) List<String> photoUrls,
    String? bio,
    Gender? gender,
  }) = _AppUser;

  const AppUser._();

  /// True once the mandatory profile fields are filled.
  bool get profileComplete =>
      (displayName?.trim().isNotEmpty ?? false) &&
      photoUrls.isNotEmpty &&
      gender != null;
}
