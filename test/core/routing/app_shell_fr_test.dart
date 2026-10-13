import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/notifications/push_listener.dart';
import 'package:not_eat_alone/core/routing/app_shell.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/a',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        for (final p in ['/a', '/b', '/c', '/d'])
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: p,
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
      ],
    ),
  ],
);

void main() {
  testWidgets('tab labels are French, fit at 320 px / 2.0x, no English', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingRequestCountProvider.overrideWithValue(3),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          foregroundPushMessagesProvider.overrideWithValue(
            const Stream<RemoteMessage>.empty(),
          ),
          openedPushMessagesProvider.overrideWithValue(
            const Stream<RemoteMessage>.empty(),
          ),
          initialPushMessageProvider.overrideWithValue(() async => null),
        ],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          routerConfig: _router(),
        ),
      ),
    );
    await tester.pump();

    for (final label in ['Découvrir', 'Messages', 'Demandes', 'Profil']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final en in ['Discover', 'Chats', 'Requests', 'Profile']) {
      expect(find.text(en), findsNothing, reason: en);
    }
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
