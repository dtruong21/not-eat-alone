import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/location/location_providers.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/application/paris_notice_provider.dart';
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/meal/presentation/discovery_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  const noticeKey = Key('paris_notice_card');

  setUp(() {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpDiscovery(
    WidgetTester tester, {
    required bool seededDismissed,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parisNoticeSeedProvider.overrideWithValue(seededDismissed),
          userRepositoryProvider.overrideWithValue(_MockUserRepository()),
          locationProvider.overrideWith((ref) async => (lat: 48.8, lng: 2.3)),
          discoveryControllerProvider.overrideWith(
            (ref) => Stream.value(const <DiscoverableMeal>[]),
          ),
          currentUserDocProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const DiscoveryScreen(),
        ),
      ),
    );
  }

  // Lets the stream resolve and the skeleton's zero-delay shimmer timer fire.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('shows the notice by default', (tester) async {
    await pumpDiscovery(tester, seededDismissed: false);
    expect(find.byKey(noticeKey), findsOneWidget);
    await settle(tester);
    expect(find.byKey(noticeKey), findsOneWidget);
  });

  testWidgets('a returning user never sees it, not even on the first frame', (
    tester,
  ) async {
    await pumpDiscovery(tester, seededDismissed: true);
    expect(find.byKey(noticeKey), findsNothing);
    await settle(tester);
    expect(find.byKey(noticeKey), findsNothing);
  });

  testWidgets('dismissing hides it and remembers the choice', (tester) async {
    await pumpDiscovery(tester, seededDismissed: false);
    await settle(tester);
    await tester.tap(find.byKey(const Key('paris_notice_close_button')));
    await tester.pump();
    expect(find.byKey(noticeKey), findsNothing);
    expect(await readParisNoticeDismissed(), isTrue);
  });
}
