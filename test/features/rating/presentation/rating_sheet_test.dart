import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/rating/application/rating_controller.dart';
import 'package:not_eat_alone/features/rating/presentation/rating_sheet.dart';

/// Records the `submit(...)` call instead of hitting a real
/// `RatingRepository`/`AuthRepository` — mirrors `FakeCreateMealController`
/// in `create_meal_screen_test.dart`. Deliberately doesn't touch `state`, so
/// the sheet's post-submit navigation/SnackBar path (which reads
/// `ratingControllerProvider.error` after awaiting `submit`) sees a clean
/// `AsyncData(null)`.
class FakeRatingController extends RatingController {
  String? calledMatchId;
  String? calledTargetUid;
  int? calledStars;
  bool? calledShowedUp;
  String? calledComment;
  int callCount = 0;

  @override
  Future<void> submit({
    required String matchId,
    required String targetUid,
    required int stars,
    required bool showedUp,
    String? comment,
  }) async {
    callCount++;
    calledMatchId = matchId;
    calledTargetUid = targetUid;
    calledStars = stars;
    calledShowedUp = showedUp;
    calledComment = comment;
  }
}

Future<FakeRatingController> pumpSheet(WidgetTester tester) async {
  final controller = FakeRatingController();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ratingControllerProvider.overrideWith(() => controller),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showRatingSheet(
                context,
                matchId: 'match_1',
                targetUid: 'them',
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

  return controller;
}

void main() {
  testWidgets('Submit is disabled until a star is tapped', (tester) async {
    await pumpSheet(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('rating_submit_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'tapping a star then submitting calls RatingController.submit '
    'with the target + stars (+ showedUp default true)',
    (tester) async {
      final controller = await pumpSheet(tester);

      await tester.tap(find.byKey(const Key('rating_star_4')));
      await tester.pump();

      final enabledButton = tester.widget<FilledButton>(
        find.byKey(const Key('rating_submit_button')),
      );
      expect(enabledButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('rating_submit_button')));
      await tester.pumpAndSettle();

      expect(controller.callCount, 1);
      expect(controller.calledMatchId, 'match_1');
      expect(controller.calledTargetUid, 'them');
      expect(controller.calledStars, 4);
      expect(controller.calledShowedUp, isTrue);
      expect(controller.calledComment, isNull);

      expect(find.text('Thanks for the feedback!'), findsOneWidget);
    },
  );

  testWidgets(
    'toggling "Did they show up?" off is passed through on submit',
    (tester) async {
      final controller = await pumpSheet(tester);

      await tester.tap(find.byKey(const Key('rating_star_5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('rating_showed_up_switch')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('rating_submit_button')));
      await tester.pumpAndSettle();

      expect(controller.calledShowedUp, isFalse);
    },
  );
}
