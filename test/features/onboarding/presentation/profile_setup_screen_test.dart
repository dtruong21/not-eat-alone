import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/onboarding/presentation/profile_setup_screen.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';

/// Records the `completeSetup` call instead of hitting real
/// repositories/analytics, so the screen's gating logic can be verified in
/// isolation.
class FakeProfileController extends ProfileController {
  ({String displayName, Gender gender, String? bio})? completeSetupCall;

  @override
  Future<void> completeSetup({
    required String displayName,
    required Gender gender,
    String? bio,
  }) async {
    completeSetupCall = (displayName: displayName, gender: gender, bio: bio);
  }
}

AppUser _user({List<String> photoUrls = const []}) => AppUser(
      uid: 'u1',
      dob: DateTime.utc(2000, 1, 1),
      photoUrls: photoUrls,
    );

void main() {
  Future<FakeProfileController> pumpScreen(
    WidgetTester tester, {
    List<String> photoUrls = const [],
    double? width,
    double height = 568,
    double textScale = 1,
  }) async {
    final controller = FakeProfileController();
    if (width != null) {
      tester.view
        ..physicalSize = Size(width, height)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDocProvider.overrideWith(
            (ref) => Stream.value(_user(photoUrls: photoUrls)),
          ),
          profileControllerProvider.overrideWith(() => controller),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const ProfileSetupScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    return controller;
  }

  testWidgets(
    'Continue is disabled until name, gender, and a photo are all present',
    (tester) async {
      await pumpScreen(tester);

      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNull);
    },
  );

  testWidgets(
    'the tree reaches idle instead of rebuilding forever',
    (tester) async {
      final controller = FakeProfileController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserDocProvider.overrideWith(
              (ref) => Stream.value(_user()),
            ),
            profileControllerProvider.overrideWith(() => controller),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const ProfileSetupScreen(),
          ),
        ),
      );

      // Regression test: ProfileForm.build() used to schedule
      // widget.onChanged unconditionally on every frame, and both host
      // screens' onChanged handlers called setState unconditionally, so the
      // tree never settled and this would time out.
      await tester.pumpAndSettle();
    },
  );

  testWidgets('no back navigation is offered', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets(
    'Continue becomes enabled once required fields are valid, and calls '
    'completeSetup with the entered values',
    (tester) async {
      final controller = await pumpScreen(
        tester,
        photoUrls: const ['https://example.com/1.jpg'],
      );

      await tester.enterText(
        find.byKey(const Key('profile_name_field')),
        'Ada Lovelace',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Non-binary'));
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('profile_bio_field')),
        'Hi there',
      );
      await tester.pumpAndSettle();

      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNotNull);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();
      await tester.pump();

      expect(controller.completeSetupCall, isNotNull);
      expect(controller.completeSetupCall!.displayName, 'Ada Lovelace');
      expect(controller.completeSetupCall!.gender, Gender.nonBinary);
      expect(controller.completeSetupCall!.bio, 'Hi there');
    },
  );

  testWidgets('the subtitle is the short copy', (tester) async {
    await pumpScreen(tester);
    expect(find.text("Name, photo and gender. That's it."), findsOneWidget);
  });

  testWidgets(
    'while invalid, a live-region hint under Continue says what is missing',
    (tester) async {
      await pumpScreen(tester);

      const hint = 'Still needed: a photo, your name and how you identify.';
      expect(find.text(hint), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(hint),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
      // Below the Continue button.
      expect(
        tester.getTopLeft(find.text(hint)).dy,
        greaterThan(
          tester
              .getBottomLeft(find.widgetWithText(FilledButton, 'Continue'))
              .dy,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('profile_name_field')),
        'Ada',
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Still needed: a photo and how you identify.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the hint names the one missing field', (tester) async {
    await pumpScreen(tester, photoUrls: const ['https://example.com/1.jpg']);
    await tester.enterText(find.byKey(const Key('profile_name_field')), 'Ada');
    await tester.pumpAndSettle();

    expect(find.text('Still needed: how you identify.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profile_name_field')), '');
    await tester.tap(find.text('Woman'));
    await tester.pumpAndSettle();
    expect(find.text('Still needed: your name.'), findsOneWidget);
  });

  testWidgets('the hint names a missing photo on its own', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('profile_name_field')), 'Ada');
    await tester.tap(find.text('Woman'));
    await tester.pumpAndSettle();

    expect(find.text('Still needed: a photo.'), findsOneWidget);
  });

  testWidgets('the hint is hidden once the form is valid', (tester) async {
    await pumpScreen(tester, photoUrls: const ['https://example.com/1.jpg']);
    await tester.enterText(find.byKey(const Key('profile_name_field')), 'Ada');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Woman'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Still needed'), findsNothing);
  });

  testWidgets('typing at the end of Bio keeps Continue above the keyboard', (
    tester,
  ) async {
    // Short viewport + big text: Continue starts far below the keyboard line.
    await pumpScreen(
      tester,
      width: 320,
      height: 480,
      textScale: 2,
      photoUrls: const ['https://example.com/1.jpg'],
    );
    const keyboard = 200.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    final continueFinder = find.widgetWithText(FilledButton, 'Continue');
    const visibleBottom = 480 - keyboard;
    expect(
      tester.getBottomLeft(continueFinder).dy,
      greaterThan(visibleBottom),
      reason: 'precondition: Continue starts below the keyboard line',
    );

    await tester.tap(find.byKey(const Key('profile_bio_field')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('profile_bio_field')),
      'Loves ramen and long dinners.',
    );
    await tester.pumpAndSettle();

    expect(
      tester.getBottomLeft(continueFinder).dy,
      lessThanOrEqualTo(visibleBottom),
    );
  });

  testWidgets('no overflow at 320 px and 2.0x text', (tester) async {
    await pumpScreen(
      tester,
      width: 320,
      height: 640,
      textScale: 2,
      photoUrls: const ['https://example.com/1.jpg'],
    );
    expect(tester.takeException(), isNull);
  });
}
