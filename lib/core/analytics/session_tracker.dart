/// Session-level analytics: who the device belongs to and the core
/// acquisition events (`signup_completed`, `signin_completed`).
///
/// Fed by [SessionTracker.onAuthUser] from the auth state stream (see
/// `AnalyticsListener`). Keeps analytics out of the sign-in screens and out of
/// the auth repository.
library;

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';

class SessionTracker {
  SessionTracker({this.platform, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// `'ios' | 'android' | 'web'` for the `platform` user property.
  final String? platform;

  final DateTime Function() _now;

  /// A sign-in newer than this counts as a fresh sign-in, not a session
  /// restored at app start.
  static const freshSignInWindow = Duration(minutes: 2);

  /// An account whose creation and first sign-in are this close together was
  /// created by that sign-in (a sign-up).
  static const newAccountWindow = Duration(seconds: 10);

  String? _identifiedUid;

  /// Call with every auth state emission (including the current one at
  /// startup). Idempotent per uid. [appVersion] is the semver for the
  /// `app_version` user property (null when unknown).
  Future<void> onAuthUser(AuthUser? user, {String? appVersion}) async {
    if (user == null) {
      if (_identifiedUid != null) {
        _identifiedUid = null;
        await analytics.reset();
      }
      return;
    }
    if (user.uid == _identifiedUid) return;
    _identifiedUid = user.uid;

    final created = user.createdAt;
    await analytics.identify(
      user.uid,
      UserProperties(
        signupDate: created == null ? null : _isoDate(created),
        signupMethod: _signupMethod(user.method),
        appVersion: appVersion,
        platform: platform,
      ),
    );

    final method = user.method;
    final lastSignIn = user.lastSignInAt;
    if (method == null || lastSignIn == null) return;
    if (_now().difference(lastSignIn).abs() > freshSignInWindow) return;

    final isNewAccount =
        created != null &&
        lastSignIn.difference(created).abs() <= newAccountWindow;
    if (isNewAccount) {
      await analytics.track(SignupCompleted(method: _signupMethod(method)!));
    } else {
      await analytics.track(SigninCompleted(method: _signinMethod(method)));
    }
  }

  static String _isoDate(DateTime d) {
    final u = d.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)}';
  }

  static SignupMethod? _signupMethod(AuthMethod? m) => switch (m) {
    AuthMethod.google => SignupMethod.google,
    AuthMethod.apple => SignupMethod.apple,
    AuthMethod.phone => SignupMethod.phone,
    null => null,
  };

  static SigninMethod _signinMethod(AuthMethod m) => switch (m) {
    AuthMethod.google => SigninMethod.google,
    AuthMethod.apple => SigninMethod.apple,
    AuthMethod.phone => SigninMethod.phone,
  };
}
