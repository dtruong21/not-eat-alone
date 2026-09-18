import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/auth/domain/app_user.dart';

void main() {
  test('AppUser round-trips through fromJson/toJson', () {
    final user = AppUser(
      uid: 'u1',
      dob: DateTime.utc(2000, 1, 1),
      ageVerified: true,
      createdAt: null,
    );

    final roundTripped = AppUser.fromJson(user.toJson());

    expect(roundTripped.uid, user.uid);
    expect(roundTripped.dob, user.dob);
    expect(roundTripped.ageVerified, user.ageVerified);
    expect(roundTripped.createdAt, user.createdAt);
  });
}
