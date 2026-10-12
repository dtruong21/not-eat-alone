import 'package:not_eat_alone/features/user/data/dtos/private_user_dto.dart';
import 'package:not_eat_alone/features/user/data/dtos/public_profile_dto.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

extension PublicProfileDtoX on PublicProfileDto {
  /// Another person's record: no `dob`, no `gender`.
  AppUser toEntity() => AppUser(
        uid: uid,
        age: age,
        displayName: displayName,
        photoUrls: photoUrls,
        bio: bio,
        ratingCount: ratingCount,
        ratingAvg: ratingAvg,
      );
}

/// The signed-in user's own record: private fields plus (when it exists yet)
/// the public profile. A missing profile yields defaults, so a brand-new
/// account (age gate done, profile not set up) is still a valid [AppUser].
AppUser mergeOwn(PrivateUserDto private, PublicProfileDto? public) => AppUser(
      uid: private.uid,
      dob: private.dob,
      age: public?.age,
      ageVerified: private.ageVerified,
      createdAt: private.createdAt,
      displayName: public?.displayName,
      photoUrls: public?.photoUrls ?? const [],
      bio: public?.bio,
      gender: genderFromString(private.gender),
      ratingCount: public?.ratingCount ?? 0,
      ratingAvg: public?.ratingAvg ?? 0,
    );

Gender? genderFromString(String? value) {
  if (value == null) return null;
  try {
    return Gender.values.byName(value);
  } on ArgumentError {
    return null;
  }
}
