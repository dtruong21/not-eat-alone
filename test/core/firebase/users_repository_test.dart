import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/firebase/users_repository.dart';

void main() {
  group('UsersRepository', () {
    late FakeFirebaseFirestore firestore;
    late UsersRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = UsersRepository(firestore: firestore);
    });

    test('upsertAgeVerified then watch emits the age-verified user', () async {
      final dob = DateTime.utc(2000, 1, 1);

      await repository.upsertAgeVerified(uid: 'u1', dob: dob);

      final user = await repository.watch('u1').first;

      expect(user, isNotNull);
      expect(user!.uid, 'u1');
      expect(user.dob, dob);
      expect(user.ageVerified, isTrue);
      // NOTE: fake_cloud_firestore does not resolve
      // FieldValue.serverTimestamp(), so createdAt is not asserted here —
      // see brief.
    });

    test('watch of a missing uid emits null', () async {
      final user = await repository.watch('missing').first;

      expect(user, isNull);
    });
  });
}
