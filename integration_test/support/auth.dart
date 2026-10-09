/// Fake-credential sign-in against the Auth emulator.
///
/// The Auth emulator's `accounts:signInWithIdp` endpoint accepts an
/// unsigned claim blob for `google.com` and mints a real (emulator-scoped)
/// user + ID token for it — no real Google OAuth round trip needed. We
/// exchange that ID token for a Firebase Auth SDK session via
/// [FirebaseAuth.signInWithCredential] so the rest of the app (which reads
/// `FirebaseAuth.instance.currentUser`/`authStateChanges()`) behaves exactly
/// as it would after a real sign-in.
///
/// TEST CODE ONLY — must never be imported from `lib/`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'emulator_admin.dart';

/// Signs in a Firebase Auth SDK session for a deterministic test user [uid]
/// via the Auth emulator's fake-credential path (no real Google OAuth).
/// Defaults [email] to `'$uid@example.com'` when omitted. Returns the signed
/// in [User], whose `uid` matches the emulator-assigned Firebase uid for
/// this identity (stable per [uid]/[email] pair within a given emulator
/// run — see `Concerns` in the task report for how this is validated).
Future<User> signInTestUser({
  required String uid,
  String? email,
}) async {
  final mail = email ?? '$uid@example.com';
  final claims = jsonEncode({
    'sub': uid,
    'email': mail,
    'email_verified': true,
  });
  final res = await http.post(
    Uri.parse(
      'http://$kEmulatorHost:9099/identitytoolkit.googleapis.com/v1/'
      'accounts:signInWithIdp?key=fake-api-key',
    ),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'postBody': 'id_token=$claims&providerId=google.com',
      'requestUri': 'http://localhost',
      'returnSecureToken': true,
      'returnIdpCredential': true,
    }),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw StateError(
      'signInWithIdp failed: HTTP ${res.statusCode} '
      '${_truncate(res.body)}',
    );
  }
  final decoded = jsonDecode(res.body) as Map<String, Object?>;
  final idToken = decoded['idToken'];
  if (idToken is! String) {
    throw StateError(
      'signInWithIdp did not return an idToken: ${res.statusCode} '
      '${res.body}',
    );
  }
  final cred = GoogleAuthProvider.credential(idToken: idToken);
  final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
  final user = userCred.user;
  if (user == null) {
    throw StateError('signInWithCredential returned a null user for $uid');
  }
  await _awaitTokenFor(user);
  return user;
}

/// Blocks until the SDK's `idTokenChanges()` has emitted [user] AND a fresh
/// ID token is in hand, so a Firestore write issued right after sign-in can't
/// go out with the PREVIOUS session's token (seen as a flaky
/// `permission-denied` on `blockerUid == auth.uid` after a user switch).
/// `idTokenChanges()` replays the current user on subscribe, so signing in the
/// uid that is already current returns promptly. Bounded to 10s with a clear
/// error on timeout.
Future<void> _awaitTokenFor(User user) async {
  try {
    await FirebaseAuth.instance
        .idTokenChanges()
        .firstWhere((u) => u?.uid == user.uid)
        .timeout(const Duration(seconds: 10));
    await user.getIdToken();
  } on TimeoutException {
    throw StateError(
      'signInTestUser: idTokenChanges() did not emit uid ${user.uid} '
      'within 10s',
    );
  }
}

/// Signs the current Firebase Auth SDK session out.
Future<void> signOutTestUser() => FirebaseAuth.instance.signOut();

/// Signs out and pumps until the running app has shown the sign-in screen.
///
/// The router (built once, plan 16b) redirects on a flip of `signedIn`; a
/// sign-out followed at once by a sign-in as someone else never lets it see
/// the signed-out state, so the previous user's route (a chat, a sheet) would
/// stay on screen. A real user always passes through the sign-in screen, so
/// scenarios that switch users on a mounted app use this instead of
/// [signOutTestUser]. Bounded (10 s); a missing sign-in screen is reported by
/// the next step's own assertion.
Future<void> signOutAndAwaitSignIn(WidgetTester tester) async {
  await signOutTestUser();
  final signIn = find.byKey(const Key('signin_phone_field'));
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (signIn.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Truncates [body] for inclusion in an exception message so a large HTML/
/// JSON error page doesn't flood test output.
String _truncate(String body, {int maxLength = 500}) =>
    body.length <= maxLength ? body : '${body.substring(0, maxLength)}...';
