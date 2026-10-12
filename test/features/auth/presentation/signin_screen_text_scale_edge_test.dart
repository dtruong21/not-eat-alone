import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/auth/presentation/signin_screen.dart';

import '../../../helpers/load_app_fonts.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// QA sweep 2026-10-09: the sign-in buttons must hold up to 1.5x system text
/// (project bar, docs/DESIGN.md) on a 360dp-wide phone, in both themes.
/// Fixed: docs/bugs/closed/2026-10-09-text-scale-overflow-signin-and-sheets.md
void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(
    WidgetTester tester, {
    required double scale,
    required Brightness brightness,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
        ],
        child: MaterialApp(
          theme: buildTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const SigninScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  for (final brightness in Brightness.values) {
    testWidgets('1.0x ${brightness.name}: no overflow', (tester) async {
      await pump(tester, scale: 1, brightness: brightness);
      expect(tester.takeException(), isNull);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('1.5x ${brightness.name}: no overflow', (tester) async {
      await pump(tester, scale: 1.5, brightness: brightness);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2.0x ${brightness.name}: no overflow', (tester) async {
      await pump(tester, scale: 2, brightness: brightness);
      expect(tester.takeException(), isNull);
    });
  }
}
