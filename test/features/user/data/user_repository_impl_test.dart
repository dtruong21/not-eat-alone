import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/user/data/repositories/user_repository_impl.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

void main() {
  group('UserRepositoryImpl', () {
    late FakeFirebaseFirestore firestore;
    late UserRepositoryImpl repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = UserRepositoryImpl(firestore: firestore);
    });

    test('upsertAgeVerified then watch emits the age-verified user',
        () async {
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

    test('watch of a malformed doc throws RepositoryParseException',
        () async {
      // Write directly through the raw (non-converter) collection so the
      // doc is missing the required `dob` field — this should fail
      // AppUserDto.fromJson and surface as a typed parse exception, never a
      // raw one. fake_cloud_firestore resolves the initial snapshot
      // synchronously, so the exception surfaces from `watch()` itself
      // rather than through the returned stream/future.
      await firestore.collection('users').doc('bad').set({'uid': 'bad'});

      expect(
        () => repository.watch('bad'),
        throwsA(isA<RepositoryParseException>()),
      );
    });

    test(
        'updateProfile merges profile fields without clobbering '
        'age-verification fields', () async {
      final dob = DateTime.utc(2000, 1, 1);
      await repository.upsertAgeVerified(uid: 'u1', dob: dob);

      await repository.updateProfile(
        uid: 'u1',
        displayName: 'Ada',
        photoUrls: ['u'],
        gender: Gender.woman,
      );

      final user = await repository.watch('u1').first;

      expect(user, isNotNull);
      expect(user!.displayName, 'Ada');
      expect(user.photoUrls, ['u']);
      expect(user.gender, Gender.woman);
      expect(user.ageVerified, isTrue);
      expect(user.dob, dob);

      await repository.updateProfile(uid: 'u1', bio: 'hi');

      final updatedUser = await repository.watch('u1').first;

      expect(updatedUser, isNotNull);
      expect(updatedUser!.bio, 'hi');
      expect(updatedUser.displayName, 'Ada');
    });
  });
}
