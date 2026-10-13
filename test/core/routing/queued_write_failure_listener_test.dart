import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/routing/queued_write_failure_listener.dart';
import 'package:not_eat_alone/core/util/queued_write_failures.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required AuthUser? user,
  Locale locale = const Locale('en'),
}) async {
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authStateProvider.overrideWith((ref) => Stream.value(user))],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) =>
                QueuedWriteFailureListener(child: child!),
            home: const Scaffold(body: Text('home')),
          );
        },
      ),
    ),
  );
  await tester.pump();
  return container;
}

void _report(ProviderContainer c, QueuedWriteKind kind) =>
    c.read(queuedWriteFailuresProvider.notifier).report(kind);

void main() {
  const user = AuthUser(uid: 'u1');

  testWidgets('shows the localized snackbar per kind (en)', (tester) async {
    final c = await _pump(tester, user: user);
    final expected = {
      QueuedWriteKind.joinRequest:
          "Your join request didn't go through. Try again.",
      QueuedWriteKind.meal: "Your meal wasn't posted. Try again.",
      QueuedWriteKind.rating: "Your rating wasn't saved.",
      QueuedWriteKind.message: "A message didn't send.",
    };
    for (final e in expected.entries) {
      _report(c, e.key);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(e.value), findsOneWidget, reason: '${e.key}');
      // Let the snackbar and the quiet period pass before the next kind.
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('shows the French text', (tester) async {
    final c = await _pump(tester, user: user, locale: const Locale('fr'));
    _report(c, QueuedWriteKind.rating);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ta note n’a pas été enregistrée.'), findsOneWidget);
  });

  testWidgets('two failures within 2 s show one snackbar', (tester) async {
    final c = await _pump(tester, user: user);
    _report(c, QueuedWriteKind.meal);
    await tester.pump(const Duration(milliseconds: 500));
    _report(c, QueuedWriteKind.rating);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text("Your rating wasn't saved."), findsNothing);

    // After the quiet period the next failure shows again.
    await tester.pump(const Duration(seconds: 5)); // first snackbar gone too
    await tester.pump(const Duration(seconds: 1));
    _report(c, QueuedWriteKind.rating);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("Your rating wasn't saved."), findsOneWidget);
  });

  testWidgets('shows nothing while signed out', (tester) async {
    final c = await _pump(tester, user: null);
    _report(c, QueuedWriteKind.meal);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SnackBar), findsNothing);
  });
}
