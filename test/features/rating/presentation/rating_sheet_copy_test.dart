import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/rating/application/rating_controller.dart';
import 'package:not_eat_alone/features/rating/presentation/rating_sheet.dart';

import '../../../helpers/load_app_fonts.dart';
import '../../../support/contrast.dart';

class _FakeRating extends RatingController {
  @override
  Future<void> submit({
    required String matchId,
    required String targetUid,
    required int stars,
    required bool showedUp,
    String? comment,
  }) async {}
}

/// UX plan 18, task 3: the rating sheet names who is rated, stars are visible
/// on the sheet and announce their state.
void main() {
  setUpAll(loadAppFonts);

  Future<ThemeData> pump(
    WidgetTester tester, {
    String? partnerName,
    Brightness brightness = Brightness.light,
    double scale = 1,
    Size size = const Size(360, 800),
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    final theme = buildTheme(brightness);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ratingControllerProvider.overrideWith(_FakeRating.new)],
        child: MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRatingSheet(
                  context,
                  matchId: 'm',
                  targetUid: 't',
                  partnerName: partnerName,
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

  Icon star(WidgetTester tester, int i) => tester.widget<Icon>(
    find.descendant(
      of: find.byKey(Key('rating_star_$i')),
      matching: find.byType(Icon),
    ),
  );

  testWidgets('title names the person', (tester) async {
    await pump(tester, partnerName: 'Giulia');
    expect(find.text('How was your meal with Giulia?'), findsOneWidget);
  });

  testWidgets('title falls back to the generic question', (tester) async {
    await pump(tester);
    expect(find.text('How was your meal?'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('stars are visible on the sheet, filled once picked ($b)', (
      tester,
    ) async {
      final theme = await pump(tester, brightness: b);
      final sheet = theme.bottomSheetTheme.backgroundColor!;

      expect(star(tester, 4).icon, Icons.star_border_rounded);
      expect(contrast(star(tester, 4).color!, sheet), greaterThanOrEqualTo(3));

      await tester.tap(find.byKey(const Key('rating_star_3')));
      await tester.pump();
      expect(star(tester, 3).icon, Icons.star_rounded);
      expect(star(tester, 4).icon, Icons.star_border_rounded);
      expect(contrast(star(tester, 3).color!, sheet), greaterThanOrEqualTo(3));
    });
  }

  testWidgets('stars announce "N stars" and which are selected', (
    tester,
  ) async {
    await pump(tester);
    SemanticsData data(int i) => tester
        .getSemantics(find.byKey(Key('rating_star_$i')))
        .getSemanticsData();

    expect(data(1).tooltip, '1 star');
    expect(data(5).tooltip, '5 stars');
    await tester.tap(find.byKey(const Key('rating_star_2')));
    await tester.pump();
    expect(data(2).flagsCollection.isSelected, Tristate.isTrue);
    expect(data(3).flagsCollection.isSelected, Tristate.isFalse);
  });

  testWidgets('comment field closes the keyboard with Done', (tester) async {
    await pump(tester);
    final field = tester.widget<TextField>(
      find.byKey(const Key('rating_comment_field')),
    );
    expect(field.textInputAction, TextInputAction.done);
  });

  for (final b in Brightness.values) {
    testWidgets('comment field has a visible edge on the sheet ($b)', (
      tester,
    ) async {
      final theme = await pump(tester, brightness: b);
      final field = tester.widget<TextField>(
        find.byKey(const Key('rating_comment_field')),
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
  }

  testWidgets('long name at 320 px / 2.0x does not overflow', (tester) async {
    await pump(
      tester,
      partnerName: 'Maximilian-Alexander von Hohenzollern',
      scale: 2,
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
  });
}
