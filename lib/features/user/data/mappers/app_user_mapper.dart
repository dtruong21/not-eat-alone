import 'package:not_eat_alone/features/user/data/dtos/app_user_dto.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

extension AppUserDtoX on AppUserDto {
  AppUser toEntity() => AppUser(
        uid: uid,
        dob: dob,
        ageVerified: ageVerified,
        createdAt: createdAt,
      );
}

extension AppUserX on AppUser {
  AppUserDto toDto() => AppUserDto(
        uid: uid,
        dob: dob,
        ageVerified: ageVerified,
        createdAt: createdAt,
      );
}
