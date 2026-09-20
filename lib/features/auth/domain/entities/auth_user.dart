import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

/// Pure domain auth entity — the signed-in user's identity, with none of
/// `firebase_auth`'s `User` fields beyond the uid. Feature/domain code
/// depends on this, never on `firebase_auth.User` directly.
@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({required String uid}) = _AuthUser;
}
