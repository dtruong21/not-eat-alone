import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/user/data/dtos/app_user_dto.dart';
import 'package:not_eat_alone/features/user/data/mappers/app_user_mapper.dart';

void main() {
  test('dto <-> entity round-trip preserves fields', () {
    final entity = AppUserDto(uid: 'u1', dob: DateTime.utc(2000, 1, 1), ageVerified: true).toEntity();
    expect(entity.uid, 'u1');
    expect(entity.ageVerified, true);
    expect(entity.dob, DateTime.utc(2000, 1, 1));
    final back = entity.toDto();
    expect(back.uid, 'u1');
    expect(back.dob, DateTime.utc(2000, 1, 1));
  });
}
