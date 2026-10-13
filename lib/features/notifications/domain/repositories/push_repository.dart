/// Repository for managing push notification permissions and FCM tokens.
abstract class PushRepository {
  /// Ask the OS for notification permission. Returns whether granted.
  Future<bool> requestPermission();

  /// Register the current device's FCM token under users/{uid}/fcmTokens and
  /// keep it fresh on refresh. [lang] (`en`/`fr`, anything else is stored as
  /// `en`) is the device's app language so the server can localize pushes.
  Future<void> registerToken(String uid, {required String lang});

  /// Updates only the stored language of the current device's token doc.
  /// Does nothing when this device has no token doc.
  Future<void> updateTokenLanguage(String uid, String lang);

  /// Delete the current device's token (on sign-out).
  Future<void> unregisterCurrentToken(String uid);
}
