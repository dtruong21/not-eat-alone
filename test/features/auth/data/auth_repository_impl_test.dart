import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';

class MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockUser extends Mock implements firebase_auth.User {}

class MockUserCredential extends Mock implements firebase_auth.UserCredential {}

void main() {
  group('AuthRepositoryImpl', () {
    late MockFirebaseAuth firebaseAuth;
    late MockGoogleSignIn googleSignIn;
    late AuthRepositoryImpl repository;

    setUpAll(() {
      // mocktail needs a fallback instance for `any()`/`captureAny()` on a
      // custom, non-nullable argument type — register a concrete
      // AuthCredential subtype since AuthCredential's own constructor is
      // @protected.
      registerFallbackValue(
        firebase_auth.PhoneAuthProvider.credential(
          verificationId: 'fallback',
          smsCode: '000000',
        ),
      );
    });

    setUp(() {
      firebaseAuth = MockFirebaseAuth();
      googleSignIn = MockGoogleSignIn();
      repository = AuthRepositoryImpl(
        firebaseAuth: firebaseAuth,
        googleSignIn: googleSignIn,
      );
    });

    test('authStateChanges maps a User stream to AuthUser, null to null', () {
      final user = MockUser();
      when(() => user.uid).thenReturn('x');
      final controller = Stream<firebase_auth.User?>.fromIterable(
        [null, user],
      );
      when(() => firebaseAuth.authStateChanges()).thenAnswer(
        (_) => controller,
      );

      expect(
        repository.authStateChanges(),
        emitsInOrder([null, const AuthUser(uid: 'x')]),
      );
    });

    test("currentUser maps the FirebaseAuth mock's user", () {
      final user = MockUser();
      when(() => user.uid).thenReturn('x');
      when(() => firebaseAuth.currentUser).thenReturn(user);

      expect(repository.currentUser, const AuthUser(uid: 'x'));
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

      await repository.confirmSmsCode(
        verificationId: 'verification-id',
        smsCode: '123456',
      );

      final captured = verify(
        () => firebaseAuth.signInWithCredential(captureAny()),
      ).captured;
      expect(captured.single, isA<firebase_auth.PhoneAuthCredential>());
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

    test('verifyPhone surfaces verificationFailed as a String message',
        () async {
      when(
        () => firebaseAuth.verifyPhoneNumber(
          phoneNumber: any(named: 'phoneNumber'),
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        ),
      ).thenAnswer((invocation) async {
        final verificationFailed = invocation
            .namedArguments[#verificationFailed] as void Function(
          firebase_auth.FirebaseAuthException,
        );
        verificationFailed(
          firebase_auth.FirebaseAuthException(
            code: 'invalid-phone-number',
            message: 'The phone number is invalid.',
          ),
        );
      });

      String? receivedMessage;
      await repository.verifyPhone(
        phoneE164: '+1invalid',
        codeSent: (_) {},
        onError: (message) => receivedMessage = message,
      );

      expect(receivedMessage, 'The phone number is invalid.');
    });

    test(
        'verifyPhone auto-verification signs in with the credential '
        'internally', () async {
      final credential = MockUserCredential();
      when(() => firebaseAuth.signInWithCredential(any())).thenAnswer(
        (_) async => credential,
      );
      when(
        () => firebaseAuth.verifyPhoneNumber(
          phoneNumber: any(named: 'phoneNumber'),
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        ),
      ).thenAnswer((invocation) async {
        final verificationCompleted = invocation
            .namedArguments[#verificationCompleted] as void Function(
          firebase_auth.PhoneAuthCredential,
        );
        verificationCompleted(
          firebase_auth.PhoneAuthProvider.credential(
            verificationId: 'auto-verification-id',
            smsCode: '123456',
          ),
        );
      });

      await repository.verifyPhone(
        phoneE164: '+15555550123',
        codeSent: (_) {},
        onError: (_) {},
      );

      verify(() => firebaseAuth.signInWithCredential(any())).called(1);
    });
  });
}
