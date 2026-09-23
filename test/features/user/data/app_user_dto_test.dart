import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/user/data/dtos/app_user_dto.dart';

void main() {
  test('rating fields default to 0 when absent from json', () {
    final json = <String, Object?>{
      'uid': 'u1',
      'dob': DateTime.utc(2000, 1, 1).toIso8601String(),
    };
    final dto = AppUserDto.fromJson(json);
    expect(dto.ratingCount, 0);
    expect(dto.ratingAvg, 0);
  });

  test('round-trips a set ratingCount/ratingAvg through json', () {
    final dto = AppUserDto(
      uid: 'u1',
      dob: DateTime.utc(2000, 1, 1),
      ratingCount: 4,
      ratingAvg: 4.5,
    );

    final back = AppUserDto.fromJson(dto.toJson());

    expect(back.ratingCount, 4);
    expect(back.ratingAvg, 4.5);
  });
}
