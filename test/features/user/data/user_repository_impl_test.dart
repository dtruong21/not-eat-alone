import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/core/util/age.dart';
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

    test('upsertAgeVerified writes the private doc and a public age', () async {
      final dob = DateTime.utc(2000, 1, 1);

      await repository.upsertAgeVerified(uid: 'u1', dob: dob);

      final own = await repository.watchOwn('u1').first;
      expect(own, isNotNull);
      expect(own!.dob, dob);
      expect(own.ageVerified, isTrue);

      final privateDoc = await firestore.collection('users').doc('u1').get();
      expect(privateDoc.data()!.keys, containsAll(['uid', 'dob', 'ageVerified']));
      final publicDoc = await firestore.collection('profiles').doc('u1').get();
      expect(publicDoc.data(), {'uid': 'u1', 'age': ageFromDob(dob)});
    });

    test('the public profile never contains dob or gender', () async {
      await repository.upsertAgeVerified(
        uid: 'u1',
        dob: DateTime.utc(2000, 1, 1),
      );
      await repository.updateProfile(
        uid: 'u1',
        displayName: 'Ada',
        photoUrls: ['u'],
        bio: 'hi',
        gender: Gender.woman,
      );

      final publicData =
          (await firestore.collection('profiles').doc('u1').get()).data()!;
      expect(publicData.keys, isNot(contains('dob')));
      expect(publicData.keys, isNot(contains('gender')));
      expect(publicData['displayName'], 'Ada');

      final privateData =
          (await firestore.collection('users').doc('u1').get()).data()!;
      expect(privateData['gender'], 'woman');
      expect(privateData.keys, isNot(contains('displayName')));
    });

    test('watch (another person) exposes only the public profile', () async {
      await repository.upsertAgeVerified(
        uid: 'u1',
        dob: DateTime.utc(2000, 1, 1),
      );
      await repository.updateProfile(
        uid: 'u1',
        displayName: 'Ada',
        gender: Gender.woman,
      );

      final other = await repository.watch('u1').first;

      expect(other, isNotNull);
      expect(other!.displayName, 'Ada');
      expect(other.dob, isNull);
      expect(other.gender, isNull);
      expect(other.ageYears, ageFromDob(DateTime.utc(2000, 1, 1)));
    });

    test('watch of a missing uid emits null', () async {
      expect(await repository.watch('missing').first, isNull);
    });

    test('watchOwn emits null until the private doc exists', () async {
      expect(await repository.watchOwn('missing').first, isNull);
    });

    test('watchOwn merges private and public fields', () async {
      final dob = DateTime.utc(2000, 1, 1);
      await repository.upsertAgeVerified(uid: 'u1', dob: dob);
      await repository.updateProfile(
        uid: 'u1',
        displayName: 'Ada',
        photoUrls: ['u'],
        gender: Gender.woman,
      );

      final own = await repository.watchOwn('u1').first;

      expect(own!.displayName, 'Ada');
      expect(own.photoUrls, ['u']);
      expect(own.gender, Gender.woman);
      expect(own.dob, dob);
      expect(own.profileComplete, isTrue);
    });

    test('a malformed public doc throws RepositoryParseException', () async {
      // `photoUrls` has the wrong type; the converter surfaces a typed error
      // (fake_cloud_firestore resolves the initial snapshot synchronously).
      await firestore
          .collection('profiles')
          .doc('bad')
          .set({'uid': 'bad', 'photoUrls': 'nope'});

      expect(
        () => repository.watch('bad').first,
        throwsA(isA<RepositoryParseException>()),
      );
    });

    test('updateProfile merges without clobbering other fields', () async {
      final dob = DateTime.utc(2000, 1, 1);
      await repository.upsertAgeVerified(uid: 'u1', dob: dob);
      await repository.updateProfile(
        uid: 'u1',
        displayName: 'Ada',
        photoUrls: ['u'],
        gender: Gender.woman,
      );
      await repository.updateProfile(uid: 'u1', bio: 'hi');

      final own = await repository.watchOwn('u1').first;

      expect(own!.bio, 'hi');
      expect(own.displayName, 'Ada');
      expect(own.gender, Gender.woman);
      expect(own.ageVerified, isTrue);
      expect(own.dob, dob);
    });

    test('watchOwn refreshes a stale public age (birthday passed)', () async {
      final dob = DateTime.utc(2000, 1, 1);
      await repository.upsertAgeVerified(uid: 'u1', dob: dob);
      await firestore
          .collection('profiles')
          .doc('u1')
          .set({'uid': 'u1', 'age': 1}, SetOptions(merge: true));

      // Listening is enough to trigger the self-heal; wait for the rewrite.
      final sub = repository.watchOwn('u1').listen((_) {});
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final publicData =
          (await firestore.collection('profiles').doc('u1').get()).data()!;
      expect(publicData['age'], ageFromDob(dob));
    });
  });
}
