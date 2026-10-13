import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences` key holding whether the Paris notice was dismissed.
const parisNoticeDismissedKey = 'paris_notice_dismissed';

/// Reads the persisted dismissal. Called before `runApp` so the first frame
/// already knows it and the notice never flashes for returning users.
Future<bool> readParisNoticeDismissed() async {
  try {
    return (await SharedPreferences.getInstance()).getBool(
          parisNoticeDismissedKey,
        ) ??
        false;
  } on Object {
    // Unreadable storage must never block startup: show the notice.
    return false;
  }
}

/// The value read at bootstrap; overridden in `bootstrap`, false elsewhere
/// (tests, E2E and the capture harness keep seeing the notice).
final parisNoticeSeedProvider = Provider<bool>((ref) => false);

/// Whether the user dismissed the Paris notice on this device.
final parisNoticeControllerProvider =
    NotifierProvider<ParisNoticeController, bool>(ParisNoticeController.new);

/// Holds and persists the Paris-notice dismissal (per device, not per user).
class ParisNoticeController extends Notifier<bool> {
  @override
  bool build() => ref.read(parisNoticeSeedProvider);

  /// Hides the notice now and remembers it for later launches.
  Future<void> dismiss() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(parisNoticeDismissedKey, true);
    } on Object {
      // The choice still applies for this session. Callers fire this
      // unawaited, so a failed write must not surface as an unhandled error.
    }
  }
}
