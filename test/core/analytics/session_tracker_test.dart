import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/session_tracker.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';

void main() {
  final now = DateTime.utc(2026, 10, 10, 12);
  late List<(String, Map<String, Object?>)> events;
  late List<String?> userIds;
  late Map<String, String?> userProps;

  setUp(() {
    events = [];
    userIds = [];
    userProps = {};
    analytics.debugSetForceSend(true);
    analytics.debugSetLogSink((name, params) async => events.add((name, params)));
    analytics.debugSetUserIdSink((uid) async => userIds.add(uid));
    analytics.debugSetUserPropertySink((n, v) async => userProps[n] = v);
  });
  tearDown(analytics.debugResetAnalytics);

  SessionTracker tracker() => SessionTracker(platform: 'ios', now: () => now);

  AuthUser user({
    String uid = 'u1',
    AuthMethod? method = AuthMethod.google,
    DateTime? createdAt,
    DateTime? lastSignInAt,
  }) => AuthUser(
    uid: uid,
    method: method,
    createdAt: createdAt,
    lastSignInAt: lastSignInAt,
  );

  test('a brand-new account fires signup_completed and sets properties', () async {
    final t = now.subtract(const Duration(seconds: 3));
    await tracker().onAuthUser(
      user(createdAt: t, lastSignInAt: t),
      appVersion: '1.2.3',
    );

    expect(userIds, ['u1']);
    expect(userProps, {
      'signup_date': '2026-10-10',
      'signup_method': 'google',
      'app_version': '1.2.3',
      'platform': 'ios',
    });
    expect(events.map((e) => e.$1), ['signup_completed']);
    expect(events.single.$2['method'], 'google');
  });

  test('a returning user signing in fires signin_completed', () async {
    await tracker().onAuthUser(
      user(
        method: AuthMethod.phone,
        createdAt: now.subtract(const Duration(days: 40)),
        lastSignInAt: now.subtract(const Duration(seconds: 20)),
      ),
    );

    expect(events.map((e) => e.$1), ['signin_completed']);
    expect(events.single.$2['method'], 'phone');
  });

  test('a restored session identifies but fires no sign-in/up event', () async {
    await tracker().onAuthUser(
      user(
        createdAt: now.subtract(const Duration(days: 40)),
        lastSignInAt: now.subtract(const Duration(hours: 5)),
      ),
    );

    expect(userIds, ['u1']);
    expect(events, isEmpty);
  });

  test('unknown method or sign-in time fires nothing but still identifies', () async {
    final t = now.subtract(const Duration(seconds: 1));
    final tr = tracker();
    await tr.onAuthUser(user(method: null, createdAt: t, lastSignInAt: t));
    await tr.onAuthUser(user(uid: 'u2', createdAt: t));

    expect(userIds, ['u1', 'u2']);
    expect(events, isEmpty);
  });

  test('the same uid is processed once', () async {
    final t = now.subtract(const Duration(seconds: 1));
    final tr = tracker();
    await tr.onAuthUser(user(createdAt: t, lastSignInAt: t));
    await tr.onAuthUser(user(createdAt: t, lastSignInAt: t));

    expect(userIds, ['u1']);
    expect(events, hasLength(1));
  });

  test('sign-out resets the identity once; a later sign-in re-identifies', () async {
    final tr = tracker();
    await tr.onAuthUser(null); // never signed in: nothing to reset
    expect(userIds, isEmpty);

    await tr.onAuthUser(user());
    await tr.onAuthUser(null);
    await tr.onAuthUser(null);
    expect(userIds, ['u1', null]);

    await tr.onAuthUser(user());
    expect(userIds, ['u1', null, 'u1']);
  });
}
