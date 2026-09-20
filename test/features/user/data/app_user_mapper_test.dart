import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/user/data/dtos/app_user_dto.dart';
import 'package:not_eat_alone/features/user/data/mappers/app_user_mapper.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

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

  test('dto <-> entity round-trip preserves profile fields incl. gender', () {
    final dto = AppUserDto(
      uid: 'u1',
      dob: DateTime.utc(2000, 1, 1),
      displayName: 'Ada',
      photoUrls: ['a', 'b'],
      bio: 'hello',
      gender: 'woman',
    );

    final entity = dto.toEntity();
    expect(entity.displayName, 'Ada');
    expect(entity.photoUrls, ['a', 'b']);
    expect(entity.bio, 'hello');
    expect(entity.gender, Gender.woman);

    final back = entity.toDto();
    expect(back.displayName, 'Ada');
    expect(back.photoUrls, ['a', 'b']);
    expect(back.bio, 'hello');
    expect(back.gender, 'woman');
  });

  test('dto with null gender maps to null entity gender', () {
    final entity = AppUserDto(uid: 'u1', dob: DateTime.utc(2000, 1, 1)).toEntity();
    expect(entity.gender, isNull);
  });

  test('dto with invalid gender string maps to null entity gender', () {
    final entity = AppUserDto(
      uid: 'u1',
      dob: DateTime.utc(2000, 1, 1),
      gender: 'not-a-real-gender',
    ).toEntity();
    expect(entity.gender, isNull);
  });
}
