import 'package:not_eat_alone/features/rating/data/dtos/rating_dto.dart';
import 'package:not_eat_alone/features/rating/domain/entities/rating.dart';

/// Extension methods for converting [RatingDto] to [Rating].
extension RatingDtoX on RatingDto {
  /// Converts this DTO to a domain entity.
  Rating toEntity() => Rating(
        id: id,
        matchId: matchId,
        raterUid: raterUid,
        targetUid: targetUid,
        stars: stars,
        showedUp: showedUp,
        comment: comment,
        createdAt: createdAt,
      );
}

/// Extension methods for converting [Rating] to [RatingDto].
extension RatingX on Rating {
  /// Converts this entity to a DTO.
  RatingDto toDto() => RatingDto(
        id: id,
        matchId: matchId,
        raterUid: raterUid,
        targetUid: targetUid,
        stars: stars,
        showedUp: showedUp,
        comment: comment,
        createdAt: createdAt,
      );
}
