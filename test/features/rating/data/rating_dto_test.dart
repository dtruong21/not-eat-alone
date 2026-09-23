import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/rating/data/dtos/rating_dto.dart';
import 'package:not_eat_alone/features/rating/data/mappers/rating_mapper.dart';

void main() {
  test('round-trips incl. optional comment + null createdAt', () {
    const dto = RatingDto(
      id: 'm1_u1', matchId: 'm1', raterUid: 'u1', targetUid: 'u2',
      stars: 5, showedUp: true, comment: 'great',
    );
    final back = RatingDto.fromJson(dto.toJson());
    expect(back.toEntity().stars, 5);
    expect(back.toEntity().showedUp, isTrue);
    expect(back.toEntity().comment, 'great');
    expect(back.toEntity().createdAt, isNull);
  });
}
