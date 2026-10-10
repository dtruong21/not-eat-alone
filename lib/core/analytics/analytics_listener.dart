/// App-root analytics wiring: fires `app_opened` (cold start and every resume
/// from background) and feeds auth state changes to [SessionTracker]
/// (identify / reset, `signup_completed`, `signin_completed`).
///
/// Mounted once above the router in `NotEatAloneApp`, so it also covers the
/// signed-out screens.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/core/analytics/session_tracker.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';

/// Builds the app-wide [SessionTracker]. Override in tests.
final sessionTrackerProvider = Provider<SessionTracker>((ref) {
  return SessionTracker(platform: _platformName());
});

/// Resolves the semver for the `app_version` user property; override in tests
/// (`PackageInfo.fromPlatform` needs platform channels).
final analyticsAppVersionProvider = FutureProvider<String?>((ref) async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } on Object {
    return null;
  }
});

String? _platformName() => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => 'ios',
  TargetPlatform.android => 'android',
  _ => null,
};

class AnalyticsListener extends ConsumerStatefulWidget {
  const AnalyticsListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AnalyticsListener> createState() => _AnalyticsListenerState();
}

class _AnalyticsListenerState extends ConsumerState<AnalyticsListener>
    with WidgetsBindingObserver {
  late final SessionTracker _tracker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tracker = ref.read(sessionTrackerProvider);
    unawaited(analytics.track(const AppOpened(isColdStart: true)));
    // The tracker is idempotent per uid, so it is safe that this fires for the
    // current value at startup as well as on every later change.
    ref.listenManual(
      authStateProvider,
      (previous, next) {
        if (next.isLoading) return;
        unawaited(_onAuth(next.value));
      },
      fireImmediately: true,
    );
  }

  Future<void> _onAuth(AuthUser? user) async {
    final version = user == null
        ? null
        : await ref.read(analyticsAppVersionProvider.future);
    if (!mounted) return;
    await _tracker.onAuthUser(user, appVersion: version);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(analytics.track(const AppOpened(isColdStart: false)));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
