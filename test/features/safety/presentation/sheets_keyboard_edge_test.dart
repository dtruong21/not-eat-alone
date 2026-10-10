import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/rating/presentation/rating_sheet.dart';
import 'package:not_eat_alone/features/safety/application/report_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/report_repository.dart';
import 'package:not_eat_alone/features/safety/presentation/report_sheet.dart';

import '../../../helpers/load_app_fonts.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockReports extends Mock implements ReportRepository {}

/// QA sweep 2026-10-09: the rating and report bottom sheets host a text field,
/// so they are used with the software keyboard open. Both are non-scrolling
/// `Column`s. Open bug:
/// docs/bugs/2026-10-09-text-scale-overflow-signin-and-sheets.md
void main() {
  setUpAll(loadAppFonts);

  Future<void> open(
    WidgetTester tester, {
    required bool rating,
    required Size size,
    required double keyboard,
    required double scale,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size
      ..viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_MockAuth()),
          reportRepositoryProvider.overrideWithValue(_MockReports()),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => rating
                    ? showRatingSheet(context, matchId: 'm', targetUid: 't')
                    : showReportSheet(
                        context,
                        targetType: 'user',
                        targetId: 't',
                      ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // Un-skip when the sheets scroll (see the bug file).
  const bug = true;

  for (final rating in [true, false]) {
    final name = rating ? 'rating' : 'report';

    testWidgets('$name sheet, 360x800, 1.0x, no keyboard: no overflow', (
      tester,
    ) async {
      await open(
        tester,
        rating: rating,
        size: const Size(360, 800),
        keyboard: 0,
        scale: 1,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name sheet, 360x800, 1.0x, keyboard open: no overflow', (
      tester,
    ) async {
      await open(
        tester,
        rating: rating,
        size: const Size(360, 800),
        keyboard: 300,
        scale: 1,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name sheet, 360x640, 1.0x, keyboard open: no overflow', (
      tester,
    ) async {
      await open(
        tester,
        rating: rating,
        size: const Size(360, 640),
        keyboard: 280,
        scale: 1,
      );
      expect(tester.takeException(), isNull);
    }, skip: bug);

    testWidgets('$name sheet, 360x800, 1.5x, keyboard open: no overflow', (
      tester,
    ) async {
      await open(
        tester,
        rating: rating,
        size: const Size(360, 800),
        keyboard: 300,
        scale: 1.5,
      );
      expect(tester.takeException(), isNull);
    }, skip: bug);
  }
}
