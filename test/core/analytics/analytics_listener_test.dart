import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/analytics/analytics_listener.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';

void main() {
  late List<(String, Map<String, Object?>)> events;
  late List<String?> userIds;

  setUp(() {
    events = [];
    userIds = [];
    analytics.debugSetForceSend(true);
    analytics.debugSetLogSink((name, params) async => events.add((name, params)));
    analytics.debugSetUserIdSink((uid) async => userIds.add(uid));
    analytics.debugSetUserPropertySink((n, v) async {});
  });
  tearDown(analytics.debugResetAnalytics);

  Future<StreamController<AuthUser?>> mount(WidgetTester tester) async {
    final auth = StreamController<AuthUser?>();
    addTearDown(auth.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => auth.stream),
          analyticsAppVersionProvider.overrideWith((ref) async => '1.0.0'),
        ],
        child: const AnalyticsListener(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );
    return auth;
  }

  testWidgets('fires app_opened on cold start and on every resume', (tester) async {
    await mount(tester);

    expect(events.map((e) => e.$1), ['app_opened']);
    expect(events.single.$2['is_cold_start'], true);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(events.map((e) => e.$1), ['app_opened', 'app_opened']);
    expect(events.last.$2['is_cold_start'], false);
  });

  testWidgets('identifies on sign-in and resets on sign-out', (tester) async {
    final auth = await mount(tester);

    auth.add(const AuthUser(uid: 'u1'));
    await tester.pump();
    await tester.pump();
    expect(userIds, ['u1']);

    auth.add(null);
    await tester.pump();
    await tester.pump();
    expect(userIds, ['u1', null]);
  });
}
