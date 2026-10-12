import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/domain/repositories/chat_repository.dart';
import 'package:not_eat_alone/features/chat/presentation/widgets/message_composer.dart';
import 'package:not_eat_alone/features/meal/presentation/widgets/paris_notice.dart';
import 'package:not_eat_alone/features/rating/application/rating_controller.dart';
import 'package:not_eat_alone/features/rating/presentation/rating_sheet.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockChat extends Mock implements ChatRepository {}

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

/// QA sweep 2026-10-12: every icon-only control must expose a name to
/// TalkBack / VoiceOver (TEST-PLAN: "Screen reader reaches every action").
/// Icon-only `IconButton`s without `tooltip` are announced as an unnamed
/// "button". Each case asserts the control carries a non-empty label.
/// Bug: docs/bugs/2026-10-12-icon-only-controls-have-no-screen-reader-label.md
const _bug = 'docs/bugs/2026-10-12-icon-only-controls-have-no-screen-reader-label.md';

void main() {
  // What a screen reader speaks: the label, or the tooltip that IconButton
  // exposes as `SemanticsData.tooltip`.
  String labelOf(WidgetTester tester, Finder f) {
    final data = tester.getSemantics(f).getSemanticsData();
    return '${data.label} ${data.tooltip}'.trim();
  }

  testWidgets('control: the leave-chat style baseline has a label (harness check)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IconButton(
            key: const Key('probe'),
            tooltip: 'Named',
            onPressed: () {},
            icon: const Icon(Icons.close),
          ),
        ),
      ),
    );
    expect(labelOf(tester, find.byKey(const Key('probe'))), 'Named');
  });

  testWidgets('chat send button has a screen-reader label', (tester) async {
    final auth = _MockAuth();
    final chat = _MockChat();
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'me'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          chatRepositoryProvider.overrideWithValue(chat),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: MessageComposer(matchId: 'm1')),
        ),
      ),
    );
    expect(
      labelOf(tester, find.byKey(const Key('message_composer_send_button'))),
      isNotEmpty,
      reason: _bug,
    );
  });

  testWidgets('"Paris-only" notice close button has a screen-reader label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: ParisNotice(onDismiss: () {})),
      ),
    );
    expect(
      labelOf(tester, find.byKey(const Key('paris_notice_close_button'))),
      isNotEmpty,
      reason: _bug,
    );
  });

  testWidgets('rating stars have screen-reader labels', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ratingControllerProvider.overrideWith(_FakeRating.new)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRatingSheet(
                  context,
                  matchId: 'm1',
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
    for (var i = 1; i <= 5; i++) {
      expect(
        labelOf(tester, find.byKey(Key('rating_star_$i'))),
        isNotEmpty,
        reason: 'star $i: $_bug',
      );
    }
  });
}
