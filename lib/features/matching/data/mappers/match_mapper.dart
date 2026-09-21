import 'package:not_eat_alone/features/matching/data/dtos/match_dto.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';

extension MatchDtoX on MatchDto {
  Match toEntity() => Match(
        id: id,
        mealId: mealId,
        hostId: hostId,
        guestId: guestId,
        createdAt: createdAt,
      );
}

extension MatchX on Match {
  MatchDto toDto() => MatchDto(
        id: id,
        mealId: mealId,
        hostId: hostId,
        guestId: guestId,
        createdAt: createdAt,
      );
}
