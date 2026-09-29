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
    // Omitted from the write entirely when null — NOT written as an
    // explicit `comment: null` field. `firestore.rules`' `ratings` create
    // rule only special-cases the key being ABSENT; a present `null` value
    // used to throw a rule-evaluation error on `.size()` and deny every
    // no-comment rating (see the fix commit for the reproduction).
    @JsonKey(includeIfNull: false) String? comment,
    DateTime? createdAt,
  }) = _RatingDto;

  /// Deserializes a rating DTO from JSON.
  factory RatingDto.fromJson(Map<String, Object?> json) =>
      _$RatingDtoFromJson(json);
}
