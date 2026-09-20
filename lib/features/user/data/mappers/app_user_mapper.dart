import 'package:not_eat_alone/features/user/data/dtos/app_user_dto.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

extension AppUserDtoX on AppUserDto {
  AppUser toEntity() => AppUser(
        uid: uid,
        dob: dob,
        ageVerified: ageVerified,
        createdAt: createdAt,
        displayName: displayName,
        photoUrls: photoUrls,
        bio: bio,
        gender: _genderFromString(gender),
      );
}

extension AppUserX on AppUser {
  AppUserDto toDto() => AppUserDto(
        uid: uid,
        dob: dob,
        ageVerified: ageVerified,
        createdAt: createdAt,
        displayName: displayName,
        photoUrls: photoUrls,
        bio: bio,
        gender: gender?.name,
      );
}

Gender? _genderFromString(String? value) {
  if (value == null) return null;
  try {
    return Gender.values.byName(value);
  } on ArgumentError {
    return null;
  }
}
