import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/safety/data/dtos/block_dto.dart';
import 'package:not_eat_alone/features/safety/data/mappers/block_mapper.dart';

void main() {
  test('round-trips with pair + null createdAt', () {
    final dto = BlockDto(id: 'a_b', blockerUid: 'a', blockedUid: 'b', pair: const ['a', 'b']);
    final back = BlockDto.fromJson(dto.toJson());
    expect(back.toEntity().pair, ['a', 'b']);
    expect(back.toEntity().blockedUid, 'b');
  });
}
