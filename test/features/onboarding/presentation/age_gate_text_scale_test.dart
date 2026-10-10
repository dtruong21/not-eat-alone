import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/onboarding/presentation/age_gate_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

import '../../../helpers/load_app_fonts.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockUser extends Mock implements UserRepository {}

/// The age gate must stay usable at large accessibility text sizes on a small
/// phone: it scrolls instead of overflowing.
void main() {
  setUpAll(loadAppFonts);

  for (final scale in [1.5, 2.0]) {
    testWidgets('360x640 at ${scale}x: no overflow, button reachable', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = _MockAuth();
      when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'u'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userRepositoryProvider.overrideWithValue(_MockUser()),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: const AgeGateScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Continue'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Continue'), findsOneWidget);
    });
  }
}
