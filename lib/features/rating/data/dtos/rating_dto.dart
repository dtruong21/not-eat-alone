import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating_dto.freezed.dart';
part 'rating_dto.g.dart';

/// Data transfer object for ratings.
@freezed
abstract class RatingDto with _$RatingDto {
  /// Creates a new rating DTO.
  const factory RatingDto({
    required String id,
    required String matchId,
    required String raterUid,
    required String targetUid,
    required int stars,
    required bool showedUp,
    String? comment,
    DateTime? createdAt,
  }) = _RatingDto;

  /// Deserializes a rating DTO from JSON.
  factory RatingDto.fromJson(Map<String, Object?> json) =>
      _$RatingDtoFromJson(json);
}
