import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user_dto.freezed.dart';
part 'app_user_dto.g.dart';

@freezed
abstract class AppUserDto with _$AppUserDto {
  const factory AppUserDto({
    required String uid,
    required DateTime dob,
    @Default(false) bool ageVerified,
    DateTime? createdAt, // server-set; nullable on optimistic snapshots
    String? displayName,
    @Default(<String>[]) List<String> photoUrls,
    String? bio,
    String? gender, // stores Gender.name
  }) = _AppUserDto;

  factory AppUserDto.fromJson(Map<String, Object?> json) =>
      _$AppUserDtoFromJson(json);
}
