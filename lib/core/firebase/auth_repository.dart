/// Typed wrapper around `firebase_auth`, `google_sign_in`, and
/// `sign_in_with_apple`.
///
/// This file is the Auth BOUNDARY — it is the only place allowed to import
/// `firebase_auth`, `google_sign_in`, and `sign_in_with_apple`. Feature code
/// must go through [AuthRepository], never those packages directly.
///
/// `FirebaseAuthException` and `GoogleSignInException` /
/// `SignInWithAppleException` are already typed and carry provider-specific
/// codes, so unlike the Firestore repositories in this folder this one lets
/// them propagate as-is rather than re-wrapping into
/// `RepositoryParseException`/`RepositoryWriteException` — those two exist
/// for Firestore document parsing/writes and don't fit an auth boundary.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Repository for all sign-in flows (Google, Apple, phone) and session state.
///
/// google_sign_in v7 is a singleton with a separate `initialize()` step and
/// an `authenticate()` call (the v6 `signIn()` was removed). Callers must
/// have already awaited `GoogleSignIn.instance.initialize(...)` (typically
/// once at app startup) before [signInWithGoogle] is called.
class AuthRepository {
  /// Creates a repository over [firebaseAuth] and [googleSignIn], or the
  /// default Auth instance / google_sign_in singleton when omitted. Tests
  /// should inject mocks.
  AuthRepository({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  /// Forwards `FirebaseAuth.authStateChanges()` — emits whenever the signed
  /// in user changes (sign-in, sign-out).
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  /// The currently signed-in user, or `null` if signed out.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Signs in with Google via the google_sign_in v7 `authenticate()` flow,
  /// then exchanges the resulting ID token for a Firebase credential.
  ///
  /// Throws a [GoogleSignInException] if the platform doesn't support
  /// `authenticate()`, the user cancels, or authentication otherwise fails.
  Future<UserCredential> signInWithGoogle() async {
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description:
            'GoogleSignIn.authenticate() is not supported on this platform.',
      );
    }

    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return await _firebaseAuth.signInWithCredential(credential);
  }

  /// Signs in with Apple via `sign_in_with_apple`, using a random nonce
  /// (hashed with SHA-256 for the request, raw for the Firebase credential)
  /// to prevent replay.
  Future<UserCredential> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    return await _firebaseAuth.signInWithCredential(credential);
  }

  /// Starts phone-number verification. Wraps
  /// `FirebaseAuth.verifyPhoneNumber`, exposing only the callbacks callers
  /// need: [codeSent] to capture the `verificationId` for
  /// [confirmSmsCode], [onError] for verification failures, and the
  /// optional [onAutoVerified] for Android's auto-retrieval/instant
  /// verification.
  Future<void> verifyPhone({
    required String phoneE164,
    required void Function(String verificationId) codeSent,
    required void Function(FirebaseAuthException e) onError,
    void Function(PhoneAuthCredential)? onAutoVerified,
  }) {
    return _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      verificationCompleted: (credential) {
        onAutoVerified?.call(credential);
      },
      verificationFailed: onError,
      codeSent: (verificationId, forceResendingToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Confirms the SMS code the user received for [verificationId], signing
  /// them in.
  Future<UserCredential> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _firebaseAuth.signInWithCredential(credential);
  }

  /// Signs out of both FirebaseAuth and google_sign_in.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }

  /// Generates a cryptographically random string to use as the Apple
  /// sign-in nonce (raw side of the SHA-256 pair sent to Apple).
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
