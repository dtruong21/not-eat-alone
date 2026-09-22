import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/routing/app_shell.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';

/// Minimal shell router mirroring `router.dart`'s `StatefulShellRoute` shape
/// — placeholder branch screens (not the real `DiscoveryScreen` /
/// `RequestInboxScreen` / `ProfileEditScreen`, which pull in Firebase-backed
/// providers out of scope for this widget test) so the test isolates
/// `AppShell`'s tab-switching and badge behavior.
GoRouter _buildRouter() => GoRouter(
      initialLocation: '/discover',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/discover',
                  builder: (context, state) => const Scaffold(
                    body: Center(
                      child: Text('discover body', key: Key('discover_body')),
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chats',
                  builder: (context, state) => const Scaffold(
                    body: Center(
                      child: Text('chats body', key: Key('chats_body')),
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/requests',
                  builder: (context, state) => const Scaffold(
                    body: Center(
                      child: Text('requests body', key: Key('requests_body')),
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const Scaffold(
                    body: Center(
                      child: Text('profile body', key: Key('profile_body')),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

Future<void> _pumpShell(WidgetTester tester, {required int pending}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pendingRequestCountProvider.overrideWithValue(pending),
      ],
      child: MaterialApp.router(
        theme: buildTheme(Brightness.light),
        routerConfig: _buildRouter(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows all four tab labels', (tester) async {
    await _pumpShell(tester, pending: 0);

    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('tapping the Chats destination switches the body', (
    tester,
  ) async {
    await _pumpShell(tester, pending: 0);

    // Initial branch body is the Discover placeholder.
    expect(find.byKey(const Key('discover_body')), findsOneWidget);
    expect(find.byKey(const Key('chats_body')), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Chats'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discover_body')), findsNothing);
    expect(find.byKey(const Key('chats_body')), findsOneWidget);
  });

  testWidgets('a zero pending count hides the Requests badge', (
    tester,
  ) async {
    await _pumpShell(tester, pending: 0);

    final badge = tester.widget<Badge>(find.byType(Badge).first);
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('a nonzero pending count shows the Requests badge', (
    tester,
  ) async {
    await _pumpShell(tester, pending: 3);

    final badge = tester.widget<Badge>(find.byType(Badge).first);
    expect(badge.isLabelVisible, isTrue);
    expect(find.text('3'), findsWidgets);
  });
}
