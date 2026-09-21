import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/features/meal/application/discovery_controller.dart';
import 'package:not_eat_alone/features/meal/domain/entities/discoverable_meal.dart';
import 'package:not_eat_alone/features/meal/presentation/discovery_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

final _viewer = AppUser(uid: 'viewer1', dob: DateTime(1995, 1, 1));

void main() {
  late MockAuthRepository authRepository;

  setUp(() {
    FlavorConfig.current = FlavorConfig(flavor: Flavor.prod);
    authRepository = MockAuthRepository();
    when(() => authRepository.signOut()).thenAnswer((_) async {});
  });

  Future<void> pumpDiscovery(
    WidgetTester tester, {
    required int pendingRequestCount,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DiscoveryScreen(),
        ),
        GoRoute(
          path: '/requests',
          builder: (context, state) => const Scaffold(body: Text('requests')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          discoveryControllerProvider.overrideWith(
            (ref) => Stream.value(const <DiscoverableMeal>[]),
          ),
          currentUserDocProvider.overrideWith(
            (ref) => Stream.value(_viewer),
          ),
          pendingRequestCountProvider.overrideWithValue(pendingRequestCount),
        ],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a nonzero pending count shows a visible badge with the count',
      (tester) async {
    await pumpDiscovery(tester, pendingRequestCount: 2);

    final badge = tester.widget<Badge>(
      find.byKey(const Key('discovery_inbox_badge')),
    );
    expect(badge.isLabelVisible, isTrue);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a zero pending count hides the badge label', (tester) async {
    await pumpDiscovery(tester, pendingRequestCount: 0);

    final badge = tester.widget<Badge>(
      find.byKey(const Key('discovery_inbox_badge')),
    );
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('tapping the inbox button navigates to /requests', (
    tester,
  ) async {
    await pumpDiscovery(tester, pendingRequestCount: 1);

    await tester.tap(find.byKey(const Key('discovery_inbox_button')));
    await tester.pumpAndSettle();

    expect(find.text('requests'), findsOneWidget);
  });
}
