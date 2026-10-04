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
    // Omitted from the write entirely when null, rather than written as an
    // explicit `comment: null`. Historical context: the `ratings` create rule
    // once only handled the key being absent, so a present `null` threw on
    // `.size()` and denied every no-comment rating. The rule now accepts
    // absent, null, or a string of at most 200 chars; omitting the key is
    // kept as defense in depth (and avoids storing a useless null field).
    @JsonKey(includeIfNull: false) String? comment,
    DateTime? createdAt,
  }) = _RatingDto;

  /// Deserializes a rating DTO from JSON.
  factory RatingDto.fromJson(Map<String, Object?> json) =>
      _$RatingDtoFromJson(json);
}
