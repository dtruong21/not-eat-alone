/// Repository for managing push notification permissions and FCM tokens.
abstract class PushRepository {
  /// Ask the OS for notification permission. Returns whether granted.
  Future<bool> requestPermission();

  /// Register the current device's FCM token under users/{uid}/fcmTokens and
  /// keep it fresh on refresh.
  Future<void> registerToken(String uid);

  /// Delete the current device's token (on sign-out).
  Future<void> unregisterCurrentToken(String uid);
}
