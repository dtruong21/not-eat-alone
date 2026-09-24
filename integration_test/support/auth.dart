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

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
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
  return user;
}

/// Signs the current Firebase Auth SDK session out.
Future<void> signOutTestUser() => FirebaseAuth.instance.signOut();

/// Truncates [body] for inclusion in an exception message so a large HTML/
/// JSON error page doesn't flood test output.
String _truncate(String body, {int maxLength = 500}) =>
    body.length <= maxLength ? body : '${body.substring(0, maxLength)}...';
