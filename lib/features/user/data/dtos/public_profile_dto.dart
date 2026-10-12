import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_profile_dto.freezed.dart';
part 'public_profile_dto.g.dart';

/// `profiles/{uid}` — PUBLIC. What other signed-in users may `get` (never
/// list): name, photos, bio, age in years and the rating aggregate. No date
/// of birth and no gender ever live here.
@freezed
abstract class PublicProfileDto with _$PublicProfileDto {
  const factory PublicProfileDto({
    required String uid,
    @JsonKey(includeIfNull: false) String? displayName,
    @Default(<String>[]) List<String> photoUrls,
    @JsonKey(includeIfNull: false) String? bio,
    @JsonKey(includeIfNull: false) int? age,
    @Default(0) int ratingCount,
    @Default(0) double ratingAvg,
  }) = _PublicProfileDto;

  factory PublicProfileDto.fromJson(Map<String, Object?> json) =>
      _$PublicProfileDtoFromJson(json);
}
