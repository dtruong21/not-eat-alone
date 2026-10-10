import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

/// How the signed-in user authenticated.
enum AuthMethod { google, apple, phone }

/// Pure domain auth entity — the signed-in user's identity, with none of
/// `firebase_auth`'s `User` fields beyond what the app needs. Feature/domain
/// code depends on this, never on `firebase_auth.User` directly.
///
/// [method], [createdAt] and [lastSignInAt] are optional metadata used by
/// analytics to tell a fresh sign-up / sign-in from a restored session; they
/// are null when unknown.
@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String uid,
    AuthMethod? method,
    DateTime? createdAt,
    DateTime? lastSignInAt,
  }) = _AuthUser;
}
