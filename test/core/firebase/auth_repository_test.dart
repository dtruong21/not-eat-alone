import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/firebase/auth_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockUser extends Mock implements User {}

void main() {
  group('AuthRepository', () {
    late MockFirebaseAuth firebaseAuth;
    late MockGoogleSignIn googleSignIn;
    late AuthRepository repository;

    setUpAll(() {
      // mocktail needs a fallback instance for `any()`/`captureAny()` on a
      // custom, non-nullable argument type — register a concrete
      // AuthCredential subtype since AuthCredential's own constructor is
      // @protected.
      registerFallbackValue(
        PhoneAuthProvider.credential(
          verificationId: 'fallback',
          smsCode: '000000',
        ),
      );
    });

    setUp(() {
      firebaseAuth = MockFirebaseAuth();
      googleSignIn = MockGoogleSignIn();
      repository = AuthRepository(
        firebaseAuth: firebaseAuth,
        googleSignIn: googleSignIn,
      );
    });

    test('authStateChanges forwards the FirebaseAuth stream', () {
      final user = MockUser();
      final controller = Stream<User?>.fromIterable([null, user]);
      when(() => firebaseAuth.authStateChanges()).thenAnswer(
        (_) => controller,
      );

      expect(repository.authStateChanges(), emitsInOrder([null, user]));
    });

    test("currentUser returns the FirebaseAuth mock's user", () {
      final user = MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(user);

      expect(repository.currentUser, same(user));
    });

    test('currentUser returns null when signed out', () {
      when(() => firebaseAuth.currentUser).thenReturn(null);

      expect(repository.currentUser, isNull);
    });

    test('signOut signs out of both FirebaseAuth and GoogleSignIn', () async {
      when(() => firebaseAuth.signOut()).thenAnswer((_) async {});
      when(() => googleSignIn.signOut()).thenAnswer((_) async {});

      await repository.signOut();

      verify(() => firebaseAuth.signOut()).called(1);
      verify(() => googleSignIn.signOut()).called(1);
    });

    test('confirmSmsCode signs in with a PhoneAuthProvider credential',
        () async {
      final credential = MockUserCredential();
      when(() => firebaseAuth.signInWithCredential(any())).thenAnswer(
        (_) async => credential,
      );

      final result = await repository.confirmSmsCode(
        verificationId: 'verification-id',
        smsCode: '123456',
      );

      expect(result, same(credential));
      final captured = verify(
        () => firebaseAuth.signInWithCredential(captureAny()),
      ).captured;
      expect(captured.single, isA<PhoneAuthCredential>());
    });

    test('verifyPhone forwards to FirebaseAuth.verifyPhoneNumber', () async {
      when(
        () => firebaseAuth.verifyPhoneNumber(
          phoneNumber: any(named: 'phoneNumber'),
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        ),
      ).thenAnswer((invocation) async {
        final codeSent = invocation.namedArguments[#codeSent]
            as void Function(String, int?);
        codeSent('verification-id', null);
      });

      String? receivedVerificationId;
      await repository.verifyPhone(
        phoneE164: '+15555550123',
        codeSent: (verificationId) => receivedVerificationId = verificationId,
        onError: (_) {},
      );

      expect(receivedVerificationId, 'verification-id');
      verify(
        () => firebaseAuth.verifyPhoneNumber(
          phoneNumber: '+15555550123',
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        ),
      ).called(1);
    });
  });
}

class MockUserCredential extends Mock implements UserCredential {}
