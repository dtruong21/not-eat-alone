import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

void main() {
  group('AppUser', () {
    test('constructs with required fields and defaults', () {
      final user = AppUser(uid: 'u1', dob: DateTime.utc(2000, 1, 1));

      expect(user.uid, 'u1');
      expect(user.dob, DateTime.utc(2000, 1, 1));
      expect(user.ageVerified, isFalse);
      expect(user.createdAt, isNull);
    });

    test('constructs with all fields set', () {
      final createdAt = DateTime.utc(2024, 5, 1);
      final user = AppUser(
        uid: 'u2',
        dob: DateTime.utc(1999, 12, 31),
        ageVerified: true,
        createdAt: createdAt,
      );

      expect(user.uid, 'u2');
      expect(user.dob, DateTime.utc(1999, 12, 31));
      expect(user.ageVerified, isTrue);
      expect(user.createdAt, createdAt);
    });

    test('copyWith updates individual fields', () {
      final user = AppUser(uid: 'u1', dob: DateTime.utc(2000, 1, 1));

      final updated = user.copyWith(ageVerified: true);

      expect(updated.uid, 'u1');
      expect(updated.dob, DateTime.utc(2000, 1, 1));
      expect(updated.ageVerified, isTrue);
    });

    test('equality is value-based', () {
      final a = AppUser(uid: 'u1', dob: DateTime.utc(2000, 1, 1));
      final b = AppUser(uid: 'u1', dob: DateTime.utc(2000, 1, 1));

      expect(a, equals(b));
    });
  });
}
