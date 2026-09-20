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
  }) async {
    final controller = FakeProfileController();
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
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Non-binary'));
      await tester.pump();
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('profile_bio_field')),
        'Hi there',
      );
      await tester.pump();
      await tester.pump();

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
}
