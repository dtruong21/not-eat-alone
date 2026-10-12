import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/user/data/dtos/private_user_dto.dart';
import 'package:not_eat_alone/features/user/data/dtos/public_profile_dto.dart';
import 'package:not_eat_alone/features/user/data/mappers/app_user_mapper.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

void main() {
  final dob = DateTime.utc(2000, 1, 1);

  test('public profile -> entity has no dob or gender', () {
    const dto = PublicProfileDto(
      uid: 'u1',
      displayName: 'Ada',
      photoUrls: ['a', 'b'],
      bio: 'hello',
      age: 30,
      ratingCount: 3,
      ratingAvg: 4.5,
    );

    final entity = dto.toEntity();

    expect(entity.displayName, 'Ada');
    expect(entity.photoUrls, ['a', 'b']);
    expect(entity.bio, 'hello');
    expect(entity.ageYears, 30);
    expect(entity.ratingCount, 3);
    expect(entity.ratingAvg, 4.5);
    expect(entity.dob, isNull);
    expect(entity.gender, isNull);
  });

  test('mergeOwn combines private and public fields', () {
    final entity = mergeOwn(
      PrivateUserDto(
        uid: 'u1',
        dob: dob,
        ageVerified: true,
        gender: 'woman',
      ),
      const PublicProfileDto(
        uid: 'u1',
        displayName: 'Ada',
        photoUrls: ['a'],
        ratingCount: 2,
        ratingAvg: 5,
      ),
    );

    expect(entity.dob, dob);
    expect(entity.ageVerified, isTrue);
    expect(entity.gender, Gender.woman);
    expect(entity.displayName, 'Ada');
    expect(entity.photoUrls, ['a']);
    expect(entity.ratingCount, 2);
    expect(entity.profileComplete, isTrue);
  });

  test('mergeOwn without a public profile yields a valid incomplete user', () {
    final entity = mergeOwn(
      PrivateUserDto(uid: 'u1', dob: dob, ageVerified: true),
      null,
    );

    expect(entity.ageVerified, isTrue);
    expect(entity.displayName, isNull);
    expect(entity.photoUrls, isEmpty);
    expect(entity.profileComplete, isFalse);
    expect(entity.ageYears, isNotNull, reason: 'falls back to dob');
  });

  test('invalid gender string maps to null', () {
    expect(genderFromString('not-a-real-gender'), isNull);
    expect(genderFromString(null), isNull);
    expect(genderFromString('man'), Gender.man);
  });
}
