import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/matching/application/leave_match_controller.dart';
import 'package:not_eat_alone/features/matching/application/match_providers.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/match_repository.dart';

class _MockMatches extends Mock implements MatchRepository {}

/// `analytics.track()` drops to `debugPrint` in debug builds; capture it
/// (restored in `finally`, before the framework's invariant check).
Future<List<String>> _logs(Future<void> Function() body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

void main() {
  late _MockMatches repo;
  late ProviderContainer container;

  setUp(() {
    repo = _MockMatches();
    container = ProviderContainer(
      overrides: [matchRepositoryProvider.overrideWithValue(repo)],
    );
  });
  tearDown(() => container.dispose());

  test(
    'success: calls the repository, fires meal_cancelled with the role',
    () async {
      when(
        () => repo.cancelMatchedMeal(mealId: any(named: 'mealId')),
      ).thenAnswer((_) async {});
      late bool ok;

      final logs = await _logs(() async {
        ok = await container
            .read(leaveMatchControllerProvider.notifier)
            .leave(mealId: 'm1', role: CancelRole.guest);
      });

      expect(ok, isTrue);
      verify(() => repo.cancelMatchedMeal(mealId: 'm1')).called(1);
      expect(
        logs.any((l) => l.contains('meal_cancelled') && l.contains('guest')),
        isTrue,
      );
      expect(container.read(leaveMatchControllerProvider).hasError, isFalse);
    },
  );

  test(
    'failure: returns false, state is an error, no analytics event',
    () async {
      when(
        () => repo.cancelMatchedMeal(mealId: any(named: 'mealId')),
      ).thenAnswer((_) async => throw StateError('offline'));
      late bool ok;

      final logs = await _logs(() async {
        ok = await container
            .read(leaveMatchControllerProvider.notifier)
            .leave(mealId: 'm1', role: CancelRole.host);
      });

      expect(ok, isFalse);
      expect(container.read(leaveMatchControllerProvider).hasError, isTrue);
      expect(logs.any((l) => l.contains('meal_cancelled')), isFalse);
    },
  );
}
