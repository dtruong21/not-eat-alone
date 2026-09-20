import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';

/// Auth boundary — sign-in flows (Google, Apple, phone) and session state.
///
/// Pure domain interface: zero `firebase_auth`/`google_sign_in`/
/// `sign_in_with_apple` imports. [AuthRepositoryImpl] is the only
/// implementation, and the only place allowed to import those packages.
abstract class AuthRepository {
  /// Emits whenever the signed-in user changes (sign-in, sign-out).
  Stream<AuthUser?> authStateChanges();

  /// The currently signed-in user, or `null` if signed out.
  AuthUser? get currentUser;

  /// Signs in with Google. The session stream is the source of truth for
  /// the result — this future completes once the sign-in attempt finishes.
  Future<void> signInWithGoogle();

  /// Signs in with Apple. The session stream is the source of truth for
  /// the result — this future completes once the sign-in attempt finishes.
  Future<void> signInWithApple();

  /// Starts phone-number verification for [phoneE164]. [codeSent] receives
  /// the `verificationId` to pass to [confirmSmsCode]; [onError] receives a
  /// human-readable error message. Auto-verification (e.g. Android
  /// instant/auto-retrieval) is handled internally and surfaces through the
  /// session stream like any other sign-in.
  Future<void> verifyPhone({
    required String phoneE164,
    required void Function(String verificationId) codeSent,
    required void Function(String message) onError,
  });

  /// Confirms the SMS code the user received for [verificationId], signing
  /// them in.
  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  });

  /// Signs out of both FirebaseAuth and google_sign_in.
  Future<void> signOut();
}
