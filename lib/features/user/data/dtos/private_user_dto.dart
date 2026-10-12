import 'package:freezed_annotation/freezed_annotation.dart';

part 'private_user_dto.freezed.dart';
part 'private_user_dto.g.dart';

/// `users/{uid}` — PRIVATE. Readable and writable by the owner only (the
/// security rules may also read it, e.g. `gender` for women-only meals).
/// Holds nothing other people are shown.
@freezed
abstract class PrivateUserDto with _$PrivateUserDto {
  const factory PrivateUserDto({
    required String uid,
    required DateTime dob,
    @Default(false) bool ageVerified,
    DateTime? createdAt, // server-set; nullable on optimistic snapshots
    @JsonKey(includeIfNull: false) String? gender, // stores Gender.name
  }) = _PrivateUserDto;

  factory PrivateUserDto.fromJson(Map<String, Object?> json) =>
      _$PrivateUserDtoFromJson(json);
}
