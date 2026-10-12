import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:not_eat_alone/core/util/age.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

part 'app_user.freezed.dart';

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,

    /// Private: only present on the signed-in user's own record. Other
    /// people's records are built from the public profile and have no `dob`.
    DateTime? dob,

    /// Public age in years (from the public profile). Prefer [ageYears].
    int? age,
    @Default(false) bool ageVerified,
    DateTime? createdAt,
    String? displayName,
    @Default(<String>[]) List<String> photoUrls,
    String? bio,
    Gender? gender,
    @Default(0) int ratingCount,
    @Default(0) double ratingAvg,
  }) = _AppUser;

  const AppUser._();

  /// Age in years to show: the public [age] when known, else derived from the
  /// private [dob] (own record only), else null.
  int? get ageYears => age ?? (dob == null ? null : ageFromDob(dob!));

  /// True once the mandatory profile fields are filled.
  bool get profileComplete =>
      (displayName?.trim().isNotEmpty ?? false) &&
      photoUrls.isNotEmpty &&
      gender != null;
}
