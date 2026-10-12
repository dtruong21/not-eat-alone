import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/safety/application/report_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/report_repository.dart';
import 'package:not_eat_alone/features/safety/presentation/report_sheet.dart';

import '../../../support/contrast.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockReports extends Mock implements ReportRepository {}

/// UX plan 18, task 3: the report sheet says who it is about, the note field
/// has a visible edge on the sheet, and the selected reason stays readable.
void main() {
  Future<ThemeData> pump(
    WidgetTester tester, {
    String targetType = 'user',
    String? targetName,
    Brightness brightness = Brightness.light,
  }) async {
    final theme = buildTheme(brightness);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_MockAuth()),
          reportRepositoryProvider.overrideWithValue(_MockReports()),
        ],
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showReportSheet(
                  context,
                  targetType: targetType,
                  targetId: 't',
                  targetName: targetName,
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
    return theme;
  }

  testWidgets('title names the person', (tester) async {
    await pump(tester, targetName: 'Bastien');
    expect(find.text('Report Bastien'), findsOneWidget);
  });

  testWidgets('title names a meal target without a name', (tester) async {
    await pump(tester, targetType: 'meal');
    expect(find.text('Report this meal'), findsOneWidget);
  });

  testWidgets('title falls back to the generic "Report"', (tester) async {
    await pump(tester);
    expect(find.text('Report'), findsOneWidget);
  });

  testWidgets('note field closes the keyboard with Done', (tester) async {
    await pump(tester);
    final field = tester.widget<TextField>(
      find.byKey(const Key('report_note_field')),
    );
    expect(field.textInputAction, TextInputAction.done);
  });

  for (final b in Brightness.values) {
    testWidgets('note field has a visible edge on the sheet ($b)', (
      tester,
    ) async {
      final theme = await pump(tester, brightness: b);
      final field = tester.widget<TextField>(
        find.byKey(const Key('report_note_field')),
      );
      final edge =
          (field.decoration!.enabledBorder! as OutlineInputBorder).borderSide;
      expect(edge.style, BorderStyle.solid);
      expect(edge.width, 1);
      expect(
        contrast(edge.color, theme.bottomSheetTheme.backgroundColor!),
        greaterThanOrEqualTo(3),
      );
    });

    // Regression guard: Flutter paints a selected ChoiceChip's label with the
    // chip theme's secondaryLabelStyle (onAccent); this fails if the theme or
    // the chip stops doing that and the label ends up unreadable on the fill.
    testWidgets('selected reason label contrasts with its fill ($b)', (
      tester,
    ) async {
      final theme = await pump(tester, brightness: b);
      await tester.tap(find.byKey(const Key('report_reason_chip_spam')));
      await tester.pumpAndSettle();
      final chip = find.byKey(const Key('report_reason_chip_spam'));
      final fill = theme.chipTheme.selectedColor!;
      final label = tester
          .widget<RichText>(
            find.descendant(of: chip, matching: find.byType(RichText)).first,
          )
          .text
          .style!
          .color!;
      expect(contrast(label, fill), greaterThanOrEqualTo(4.5));
    });
  }
}
