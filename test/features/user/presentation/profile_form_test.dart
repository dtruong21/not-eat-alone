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

AppUser _user({List<String> photoUrls = const []}) => AppUser(
      uid: 'u1',
      dob: DateTime.utc(2000, 1, 1),
      photoUrls: photoUrls,
    );

void main() {
  Future<ProfileFormData?> pumpForm(
    WidgetTester tester, {
    required GlobalKey<ProfileFormState> formKey,
    required AppUser user,
    FakeProfileController? controller,
  }) async {
    ProfileFormData? captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserDocProvider.overrideWith((ref) => Stream.value(user)),
          profileControllerProvider
              .overrideWith(() => controller ?? FakeProfileController()),
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
    return captured;
  }

  testWidgets(
    'no name, gender, or photo reports the required set as invalid',
    (tester) async {
      final formKey = GlobalKey<ProfileFormState>();
      final captured =
          await pumpForm(tester, formKey: formKey, user: _user());

      expect(captured, isNotNull);
      expect(captured!.isValid, isFalse);
      expect(captured.photoCount, 0);
      expect(captured.name, isEmpty);
      expect(captured.gender, isNull);
    },
  );

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
            profileControllerProvider
                .overrideWith(FakeProfileController.new),
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

  testWidgets(
    'tapping the remove button on a thumbnail calls removePhoto',
    (tester) async {
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
    },
  );
}
