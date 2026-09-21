import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/data/dtos/join_request_dto.dart';
import 'package:not_eat_alone/features/matching/data/mappers/join_request_mapper.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';

void main() {
  test('round-trips through json with null createdAt', () {
    final dto = JoinRequestDto(
      id: 'm1_g1', mealId: 'm1', guestId: 'g1', hostId: 'h1', status: 'pending',
    );
    final back = JoinRequestDto.fromJson(dto.toJson());
    expect(back.toEntity().status, RequestStatus.pending);
    expect(back.toEntity().createdAt, isNull);
  });

  test('unknown status falls back to pending', () {
    final dto = JoinRequestDto(
      id: 'x', mealId: 'm', guestId: 'g', hostId: 'h', status: 'bogus',
    );
    expect(dto.toEntity().status, RequestStatus.pending);
  });
}
