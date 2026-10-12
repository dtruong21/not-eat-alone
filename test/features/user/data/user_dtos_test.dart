import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/user/data/dtos/private_user_dto.dart';
import 'package:not_eat_alone/features/user/data/dtos/public_profile_dto.dart';

void main() {
  group('PublicProfileDto', () {
    test('rating fields default to 0 and photoUrls to empty', () {
      final dto = PublicProfileDto.fromJson({'uid': 'u1'});

      expect(dto.ratingCount, 0);
      expect(dto.ratingAvg, 0);
      expect(dto.photoUrls, isEmpty);
      expect(dto.age, isNull);
    });

    test('round-trips through json and never carries dob or gender', () {
      const dto = PublicProfileDto(
        uid: 'u1',
        displayName: 'Ada',
        age: 30,
        ratingCount: 4,
        ratingAvg: 4.5,
      );

      final json = dto.toJson();

      expect(PublicProfileDto.fromJson(json), dto);
      expect(json.keys, isNot(contains('dob')));
      expect(json.keys, isNot(contains('gender')));
      // Null optionals are omitted, so a merge write can't null them out.
      expect(json.keys, isNot(contains('bio')));
    });
  });

  group('PrivateUserDto', () {
    test('holds only the private fields', () {
      final dto = PrivateUserDto(
        uid: 'u1',
        dob: DateTime.utc(2000, 1, 1),
        ageVerified: true,
        gender: 'woman',
      );

      expect(dto.toJson().keys.toSet(), {
        'uid',
        'dob',
        'ageVerified',
        'createdAt',
        'gender',
      });
    });

    test('null gender is omitted from json (a merge cannot erase it)', () {
      final json = PrivateUserDto(uid: 'u1', dob: DateTime.utc(2000, 1, 1))
          .toJson();

      expect(json.keys, isNot(contains('gender')));
    });
  });
}
