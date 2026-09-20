/// `AuthRepository` implementation over `firebase_auth`, `google_sign_in`,
/// and `sign_in_with_apple`.
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
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';

/// Repository for all sign-in flows (Google, Apple, phone) and session state.
///
/// google_sign_in v7 is a singleton with a separate `initialize()` step and
/// an `authenticate()` call (the v6 `signIn()` was removed). Callers must
/// have already awaited `GoogleSignIn.instance.initialize(...)` (typically
/// once at app startup) before [signInWithGoogle] is called.
class AuthRepositoryImpl implements AuthRepository {
  /// Creates a repository over [firebaseAuth] and [googleSignIn], or the
  /// default Auth instance / google_sign_in singleton when omitted. Tests
  /// should inject mocks.
  AuthRepositoryImpl({
    firebase_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final firebase_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthUser? _mapUser(firebase_auth.User? u) =>
      u == null ? null : AuthUser(uid: u.uid);

  /// Forwards `FirebaseAuth.authStateChanges()`, mapped to [AuthUser] —
  /// emits whenever the signed in user changes (sign-in, sign-out).
  @override
  Stream<AuthUser?> authStateChanges() =>
      _firebaseAuth.authStateChanges().map(_mapUser);

  /// The currently signed-in user, or `null` if signed out.
  @override
  AuthUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  /// Signs in with Google via the google_sign_in v7 `authenticate()` flow,
  /// then exchanges the resulting ID token for a Firebase credential.
  ///
  /// Throws a [GoogleSignInException] if the platform doesn't support
  /// `authenticate()`, the user cancels, or authentication otherwise fails.
  @override
  Future<void> signInWithGoogle() async {
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description:
            'GoogleSignIn.authenticate() is not supported on this platform.',
      );
    }

    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;

    final credential =
        firebase_auth.GoogleAuthProvider.credential(idToken: idToken);
    await _firebaseAuth.signInWithCredential(credential);
  }

  /// Signs in with Apple via `sign_in_with_apple`, using a random nonce
  /// (hashed with SHA-256 for the request, raw for the Firebase credential)
  /// to prevent replay.
  @override
  Future<void> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final credential = firebase_auth.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    await _firebaseAuth.signInWithCredential(credential);
  }

  /// Starts phone-number verification. Wraps
  /// `FirebaseAuth.verifyPhoneNumber`, exposing only [codeSent] (to capture
  /// the `verificationId` for [confirmSmsCode]) and [onError] (a plain
  /// message, not the exception). Auto-verification (Android
  /// auto-retrieval/instant verification) is handled internally by signing
  /// straight in with the resulting credential — the session stream
  /// surfaces the result.
  @override
  Future<void> verifyPhone({
    required String phoneE164,
    required void Function(String verificationId) codeSent,
    required void Function(String message) onError,
  }) {
    return _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      verificationCompleted: (credential) {
        _firebaseAuth.signInWithCredential(credential);
      },
      verificationFailed: (e) => onError(e.message ?? e.code),
      codeSent: (verificationId, forceResendingToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Confirms the SMS code the user received for [verificationId], signing
  /// them in.
  @override
  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = firebase_auth.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _firebaseAuth.signInWithCredential(credential);
  }

  /// Signs out of both FirebaseAuth and google_sign_in.
  @override
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
