import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/presentation/profile_edit_screen.dart';

class _FakeProfileController extends ProfileController {
  _FakeProfileController({this.fail = false});

  bool fail;
  final saves = <({String? name, String? bio, Gender? gender})>[];

  @override
  Future<void> save({String? displayName, String? bio, Gender? gender}) async {
    saves.add((name: displayName, bio: bio, gender: gender));
    state = const AsyncValue.loading();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = fail
        ? AsyncValue.error(StateError('boom'), StackTrace.empty)
        : const AsyncValue.data(null);
  }
}

AppUser _user({int ratingCount = 7, double ratingAvg = 4.7}) => AppUser(
  uid: 'u1',
  dob: DateTime.utc(1995, 6),
  displayName: 'Alex',
  bio: 'Loves ramen.',
  gender: Gender.woman,
  photoUrls: const ['https://example.com/1.jpg'],
  ratingCount: ratingCount,
  ratingAvg: ratingAvg,
);

void main() {
  Future<_FakeProfileController> pumpScreen(
    WidgetTester tester, {
    AppUser? user,
    bool fail = false,
    double textScale = 1,
    Size? size,
    Stream<AppUser>? userStream,
  }) async {
    final u = user ?? _user();
    Stream<AppUser> stream() => userStream ?? Stream.value(u);
    final controller = _FakeProfileController(fail: fail);
    if (size != null) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDocProvider.overrideWith((ref) => stream()),
          userDocProvider('u1').overrideWith((ref) => stream()),
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
          home: const ProfileEditScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    return controller;
  }

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Save'))
          .onPressed !=
      null;

  Future<void> typeName(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('profile_name_field')), text);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('is titled Profile, keeps the Settings gear', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.byKey(const Key('profile_settings_button')), findsOneWidget);
  });

  testWidgets('labels the rating: Your rating + star, average, count', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Your rating'), findsOneWidget);
    expect(find.byKey(const Key('rating_badge')), findsOneWidget);
    expect(find.text('4.7 (7)'), findsOneWidget);
  });

  testWidgets('no ratings yet says so', (tester) async {
    await pumpScreen(tester, user: _user(ratingCount: 0, ratingAvg: 0));

    expect(find.text('Your rating'), findsOneWidget);
    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.byKey(const Key('rating_badge_new')), findsNothing);
  });

  testWidgets('Save is disabled until the form differs from the profile', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(saveEnabled(tester), isFalse);

    await typeName(tester, 'Alexandra');
    expect(saveEnabled(tester), isTrue);

    // Back to the saved value: nothing to save again.
    await typeName(tester, 'Alex');
    expect(saveEnabled(tester), isFalse);

    // Whitespace-only differences are not changes.
    await typeName(tester, 'Alex  ');
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('a bio edit or a gender change enables Save', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('profile_bio_field')),
      'Loves ramen and sushi.',
    );
    await tester.pump();
    await tester.pump();
    expect(saveEnabled(tester), isTrue);

    await tester.enterText(
      find.byKey(const Key('profile_bio_field')),
      'Loves ramen.',
    );
    await tester.pump();
    await tester.pump();
    expect(saveEnabled(tester), isFalse);

    await tester.ensureVisible(find.text('Man'));
    await tester.tap(find.text('Man'));
    await tester.pump();
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('clearing the bio saves an empty bio and disables Save', (
    tester,
  ) async {
    final controller = await pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('profile_bio_field')), '');
    await tester.pump();
    await tester.pump();
    expect(saveEnabled(tester), isTrue);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    // '' (not null): null means "leave unchanged" in updateProfile.
    expect(controller.saves.single.bio, '');
    expect(find.text('Profile saved'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('a blank name cannot be saved', (tester) async {
    await pumpScreen(tester);

    await typeName(tester, '   ');
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('a photo-only change leaves Save disabled (photos persist '
      'immediately)', (tester) async {
    final users = StreamController<AppUser>.broadcast();
    addTearDown(users.close);
    await pumpScreen(tester, userStream: users.stream);
    users.add(_user());
    await tester.pump();
    await tester.pump();
    expect(saveEnabled(tester), isFalse);

    users.add(
      _user().copyWith(
        photoUrls: const [
          'https://example.com/1.jpg',
          'https://example.com/2.jpg',
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('profile_photo_https://example.com/2.jpg')),
      findsOneWidget,
    );
    expect(saveEnabled(tester), isFalse);
    expect(find.byKey(const Key('profile_save_hint')), findsNothing);
  });

  testWidgets('typed name and bio survive a user-doc re-emit', (tester) async {
    final users = StreamController<AppUser>.broadcast();
    addTearDown(users.close);
    await pumpScreen(tester, userStream: users.stream);
    users.add(_user());
    await tester.pump();
    await tester.pump();

    await typeName(tester, 'Alexandra');
    await tester.enterText(
      find.byKey(const Key('profile_bio_field')),
      'Loves ramen and sushi.',
    );
    await tester.pump();

    users.add(_user(ratingCount: 8, ratingAvg: 4.8));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    String text(String key) =>
        tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;
    expect(text('profile_name_field'), 'Alexandra');
    expect(text('profile_bio_field'), 'Loves ramen and sushi.');
    expect(find.text('4.8 (8)'), findsOneWidget);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('retrying after a failed save works and keeps the form', (
    tester,
  ) async {
    final controller = await pumpScreen(tester, fail: true);
    await typeName(tester, 'Alexandra');

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Profile saved'), findsNothing);
    expect(saveEnabled(tester), isTrue);

    controller.fail = false;
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(controller.saves.length, 2);
    expect(find.text('Profile saved'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('profile_name_field')))
          .controller!
          .text,
      'Alexandra',
    );
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('an invalid form says what is still needed; an unchanged one '
      'stays silent', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('profile_save_hint')), findsNothing);

    await typeName(tester, '   ');
    expect(saveEnabled(tester), isFalse);
    expect(find.text('Still needed: your name.'), findsOneWidget);

    await typeName(tester, 'Alex');
    expect(find.byKey(const Key('profile_save_hint')), findsNothing);
  });

  testWidgets('saving shows "Profile saved", stays on the screen and '
      'disables Save again', (tester) async {
    final controller = await pumpScreen(tester);
    await typeName(tester, 'Alexandra');

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(controller.saves, [
      (name: 'Alexandra', bio: 'Loves ramen.', gender: Gender.woman),
    ]);
    expect(find.text('Profile saved'), findsOneWidget);
    // A tab root: nothing is popped.
    expect(find.byType(ProfileEditScreen), findsOneWidget);
    expect(find.byKey(const Key('profile_name_field')), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    // A further edit enables it again.
    await typeName(tester, 'Alexandre');
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('a failed save keeps the form and Save, with the error shown', (
    tester,
  ) async {
    await pumpScreen(tester, fail: true);
    await typeName(tester, 'Alexandra');

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.text('Profile saved'), findsNothing);
    expect(find.text('Something went wrong — please try again.'), findsOne);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('profile_name_field')))
          .controller!
          .text,
      'Alexandra',
    );
    expect(saveEnabled(tester), isTrue);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('no overflow at 320x568, ${scale}x text', (tester) async {
      await pumpScreen(tester, textScale: scale, size: const Size(320, 568));

      expect(tester.takeException(), isNull);
      expect(find.text('Your rating'), findsOneWidget);
      // Label and value both on screen (wrapped under each other at 2.0x),
      // not clipped off the 320 px width.
      for (final f in [find.text('Your rating'), find.text('4.7 (7)')]) {
        final r = tester.getRect(f);
        expect(r.width, greaterThan(0));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(320));
        expect(r.top, greaterThanOrEqualTo(0));
      }
      await tester.ensureVisible(find.text('Save'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
