import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/avatar_image.dart';

void main() {
  Widget host(Widget child, {double dpr = 1}) => MediaQuery(
    data: MediaQueryData(devicePixelRatio: dpr),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  testWidgets('decodes at avatar size x device pixel ratio, never upscaling', (
    tester,
  ) async {
    late ImageProvider provider;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            provider = avatarImage(context, 'https://x.test/a.jpg', radius: 24);
            return const SizedBox();
          },
        ),
        dpr: 3,
      ),
    );

    expect(provider, isA<ResizeImage>());
    final resize = provider as ResizeImage;
    expect(resize.width, 144); // 24 * 2 * 3
    expect(resize.height, isNull);
    expect(resize.allowUpscaling, isFalse);
  });

  testWidgets('a photo that fails to load does not raise a framework error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => CircleAvatar(
            radius: 24,
            backgroundImage: avatarImage(
              context,
              'https://x.test/missing.jpg',
              radius: 24,
            ),
            onBackgroundImageError: ignoreAvatarImageError,
            child: const Icon(Icons.person_rounded),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
