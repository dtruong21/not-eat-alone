import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';

import '../../../support/pump_localized.dart';

void main() {
  testWidgets('ErrorState defaults are French and no English remains', (
    tester,
  ) async {
    await pumpLocalized(tester, ErrorState(onRetry: () {}));

    expect(find.text('Chargement impossible'), findsOneWidget);
    expect(find.text('Vérifie ta connexion et réessaie.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text("Couldn't load this"), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('ErrorState keeps a caller-supplied title and message', (
    tester,
  ) async {
    await pumpLocalized(
      tester,
      ErrorState(onRetry: () {}, title: 'Titre', message: 'Message'),
    );

    expect(find.text('Titre'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Chargement impossible'), findsNothing);
  });

  testWidgets('ErrorState has no overflow at 320 px and 2.0x in French', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpLocalized(
      tester,
      ErrorState(onRetry: () {}),
      size: const Size(320, 640),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('skeleton lists announce "Chargement"', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLocalized(
      tester,
      const Column(
        children: [
          Expanded(child: SkeletonList()),
          Expanded(child: SkeletonMessages()),
        ],
      ),
    );
    // flutter_animate starts via a zero-delay timer.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.bySemanticsLabel('Chargement'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Loading'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });
}
