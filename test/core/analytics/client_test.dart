import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';

void main() {
  tearDown(analytics.debugResetAnalytics);

  test('track forwards name + props to the sink', () async {
    analytics.debugSetForceSend(true);
    final calls = <(String, Map<String, Object?>)>[];
    analytics.debugSetLogSink((name, params) async {
      calls.add((name, params));
    });

    await analytics.track(const MealRated(stars: 5, showedUp: true));

    expect(calls.single.$1, 'meal_rated');
    expect(calls.single.$2['stars'], 5);
    expect(calls.single.$2['showed_up'], true);
  });

  test('track never throws even if the sink fails', () async {
    analytics.debugSetForceSend(true);
    analytics.debugSetLogSink((name, params) async {
      throw Exception('boom');
    });

    // Must complete without throwing.
    await analytics.track(const MealRated(stars: 5, showedUp: true));
  });

  test('drops in debug mode unless forced', () async {
    var called = false;
    analytics.debugSetLogSink((name, params) async {
      called = true;
    });

    await analytics.track(const MealRated(stars: 5, showedUp: true));

    expect(called, isFalse);
  });
}
