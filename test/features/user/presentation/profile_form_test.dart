import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/user/application/profile_controller.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/entities/gender.dart';
import 'package:not_eat_alone/features/user/presentation/widgets/profile_form.dart';

/// Records calls instead of hitting real repositories/Storage, so
/// [ProfileForm]'s add/remove-photo wiring can be verified without a
/// `ProviderContainer` full of auth/user/storage mocks.
class FakeProfileController extends ProfileController {
  Uint8List? addedPhotoBytes;
  String? removedPhotoUrl;

  @override
  Future<void> addPhoto(Uint8List bytes) async {
    addedPhotoBytes = bytes;
  }

  @override
  Future<void> removePhoto(String url) async {
    removedPhotoUrl = url;
  }
}

AppUser _user({List<String> photoUrls = const []}) =>
    AppUser(uid: 'u1', dob: DateTime.utc(2000, 1, 1), photoUrls: photoUrls);

void main() {
  Future<ProfileFormData?> pumpForm(
    WidgetTester tester, {
    required GlobalKey<ProfileFormState> formKey,
    required AppUser user,
    FakeProfileController? controller,
    double? width,
    double textScale = 1,
  }) async {
    ProfileFormData? captured;
    if (width != null) {
      tester.view
        ..physicalSize = Size(width, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDocProvider.overrideWith((ref) => Stream.value(user)),
          profileControllerProvider.overrideWith(
            () => controller ?? FakeProfileController(),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileForm(
                key: formKey,
                onChanged: (data) => captured = data,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    return captured;
  }

  testWidgets('no name, gender, or photo reports the required set as invalid', (
    tester,
  ) async {
    final formKey = GlobalKey<ProfileFormState>();
    final captured = await pumpForm(tester, formKey: formKey, user: _user());

    expect(captured, isNotNull);
    expect(captured!.isValid, isFalse);
    expect(captured.photoCount, 0);
    expect(captured.name, isEmpty);
    expect(captured.gender, isNull);
  });

  testWidgets(
    'a name, a gender, and an existing photo make the required set valid',
    (tester) async {
      final formKey = GlobalKey<ProfileFormState>();
      ProfileFormData? captured;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserDocProvider.overrideWith(
              (ref) => Stream.value(
                _user(photoUrls: const ['https://example.com/1.jpg']),
              ),
            ),
            profileControllerProvider.overrideWith(FakeProfileController.new),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileForm(
                  key: formKey,
                  onChanged: (data) => captured = data,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Still invalid: a photo is present, but no name/gender yet.
      expect(captured!.isValid, isFalse);
      expect(captured!.photoCount, 1);

      await tester.enterText(
        find.byKey(const Key('profile_name_field')),
        'Ada',
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Woman'));
      await tester.pump();
      await tester.pump();

      expect(captured!.name, 'Ada');
      expect(captured!.gender, Gender.woman);
      expect(captured!.photoCount, 1);
      expect(captured!.isValid, isTrue);
    },
  );

  testWidgets(
    'tapping "add photo" uses the injected bytes and calls addPhoto',
    (tester) async {
      final formKey = GlobalKey<ProfileFormState>();
      final controller = FakeProfileController();

      await pumpForm(
        tester,
        formKey: formKey,
        user: _user(),
        controller: controller,
      );

      final bytes = Uint8List.fromList([1, 2, 3]);
      formKey.currentState!.debugInjectPickedBytes(bytes);

      await tester.tap(find.byKey(const Key('add_photo_tile')));
      await tester.pump();
      await tester.pump();

      expect(controller.addedPhotoBytes, bytes);
    },
  );

  testWidgets('the add-photo tile outline reaches 3:1 on its surface', (
    tester,
  ) async {
    await pumpForm(
      tester,
      formKey: GlobalKey<ProfileFormState>(),
      user: _user(),
    );

    final tile = find.byKey(const Key('add_photo_tile'));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: tile, matching: find.byType(DecoratedBox)).first,
    );
    final border = (box.decoration as BoxDecoration).border! as Border;
    final surface = Theme.of(tester.element(tile)).colorScheme.surface;
    final a = border.top.color.computeLuminance();
    final b = surface.computeLuminance();
    final hi = a > b ? a : b;
    final lo = a > b ? b : a;
    expect((hi + 0.05) / (lo + 0.05), greaterThanOrEqualTo(3));
  });

  testWidgets('tapping the remove button on a thumbnail calls removePhoto', (
    tester,
  ) async {
    final formKey = GlobalKey<ProfileFormState>();
    final controller = FakeProfileController();
    const url = 'https://example.com/1.jpg';

    await pumpForm(
      tester,
      formKey: formKey,
      user: _user(photoUrls: const [url]),
      controller: controller,
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump();

    expect(controller.removedPhotoUrl, url);
  });

  testWidgets('missingFields lists what is still needed, in screen order', (
    tester,
  ) async {
    final captured = await pumpForm(
      tester,
      formKey: GlobalKey<ProfileFormState>(),
      user: _user(),
    );
    expect(captured!.missingFields, [
      'a photo',
      'your name',
      'how you identify',
    ]);

    const complete = ProfileFormData(
      name: 'Ada',
      gender: Gender.woman,
      bio: null,
      photoCount: 1,
    );
    expect(complete.missingFields, isEmpty);
    expect(
      const ProfileFormData(
        name: '  ',
        gender: Gender.man,
        bio: null,
        photoCount: 2,
      ).missingFields,
      ['your name'],
    );
  });

  testWidgets('the add-photo tile is labelled, with an onSurface icon', (
    tester,
  ) async {
    await pumpForm(
      tester,
      formKey: GlobalKey<ProfileFormState>(),
      user: _user(),
    );
    final tile = find.byKey(const Key('add_photo_tile'));
    expect(
      find.descendant(of: tile, matching: find.text('Add photo')),
      findsOneWidget,
    );
    final icon = tester.widget<Icon>(
      find.descendant(of: tile, matching: find.byType(Icon)),
    );
    expect(icon.color, Theme.of(tester.element(tile)).colorScheme.onSurface);
    expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(tile),
      matchesSemantics(
        label: 'Add photo',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
      ),
    );
  });

  testWidgets('the busy add-photo tile shows an onSurface spinner', (
    tester,
  ) async {
    final controller = _SlowController();
    final formKey = GlobalKey<ProfileFormState>();
    await pumpForm(
      tester,
      formKey: formKey,
      user: _user(),
      controller: controller,
    );
    formKey.currentState!.debugInjectPickedBytes(Uint8List.fromList([1]));
    await tester.tap(find.byKey(const Key('add_photo_tile')));
    await tester.pump();
    await tester.pump();

    final spinner = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: find.byKey(const Key('add_photo_tile')),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(
      spinner.color,
      Theme.of(tester.element(find.byType(ProfileForm))).colorScheme.onSurface,
    );
    controller.release();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('every remove button has a 44pt hit area and a 24pt visual', (
    tester,
  ) async {
    await pumpForm(
      tester,
      formKey: GlobalKey<ProfileFormState>(),
      user: _user(
        photoUrls: const [
          'https://example.com/1.jpg',
          'https://example.com/2.jpg',
          'https://example.com/3.jpg',
        ],
      ),
    );

    expect(find.byTooltip('Remove photo'), findsNWidgets(3));
    final buttons = find.byType(IconButton);
    expect(buttons, findsNWidgets(3));
    final rects = <Rect>[];
    for (final button in buttons.evaluate().map(
      (e) => find.byWidget(e.widget),
    )) {
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      rects.add(tester.getRect(button));
      expect(
        tester.getSemantics(button),
        matchesSemantics(
          label: 'Remove photo',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
        ),
      );
    }
    // Hit areas stay inside their own thumbnail: no overlap between buttons.
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(rects[i].overlaps(rects[j]), isFalse);
      }
    }

    final visual = tester.getSize(
      find.ancestor(
        of: find.byIcon(Icons.close).first,
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(visual, const Size(24, 24));
  });

  testWidgets('name and bio fields leave room to scroll above the keyboard', (
    tester,
  ) async {
    await pumpForm(
      tester,
      formKey: GlobalKey<ProfileFormState>(),
      user: _user(),
    );
    for (final key in const ['profile_name_field', 'profile_bio_field']) {
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(TextField),
        ),
      );
      expect(
        field.scrollPadding.bottom,
        greaterThanOrEqualTo(120),
        reason: key,
      );
    }
  });

  testWidgets('no overflow at 320 px and 2.0x text', (tester) async {
    await pumpForm(
      tester,
      formKey: GlobalKey<ProfileFormState>(),
      user: _user(photoUrls: const ['https://example.com/1.jpg']),
      width: 320,
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

/// Holds `addPhoto` open so the busy state can be observed.
class _SlowController extends FakeProfileController {
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<void> addPhoto(Uint8List bytes) async {
    state = const AsyncLoading();
    await _gate.future;
    state = const AsyncData(null);
  }
}
