import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/safety/application/report_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/report_repository.dart';
import 'package:not_eat_alone/features/safety/presentation/widgets/safety_actions.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockReports extends Mock implements ReportRepository {}

/// UX plan 18, task 3: the block dialog and the report sheet opened from the
/// menu name the person; "Block" is in the danger colour, "Cancel" is not.
void main() {
  Future<ThemeData> pump(
    WidgetTester tester, {
    String? name,
    Brightness brightness = Brightness.light,
  }) async {
    final theme = buildTheme(brightness);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_MockAuth()),
          reportRepositoryProvider.overrideWithValue(_MockReports()),
          userDocProvider('them').overrideWith(
            (ref) => Stream.value(
              name == null ? null : AppUser(uid: 'them', displayName: name),
            ),
          ),
        ],
        child: MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: SafetyActions(
              reportTargetType: 'user',
              reportTargetId: 'them',
              blockUid: 'them',
            ),
          ),
        ),
      ),
    );
    // Let the name stream emit, as it already has once chat shows the title.
    ProviderScope.containerOf(
      tester.element(find.byType(SafetyActions)),
    ).listen(userDocProvider('them'), (_, _) {});
    await tester.pump();
    return theme;
  }

  Future<void> choose(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(const Key('safety_actions_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  for (final b in Brightness.values) {
    testWidgets('block dialog names the person; Block is danger ($b)', (
      tester,
    ) async {
      final theme = await pump(tester, name: 'Bastien', brightness: b);
      await choose(tester, 'safety_actions_block_item');

      expect(find.text('Block Bastien?'), findsOneWidget);
      final danger = theme.extension<WarmPlayfulExtensions>()!.dangerText;
      final confirm = tester.widget<TextButton>(
        find.byKey(const Key('safety_actions_block_confirm')),
      );
      expect(confirm.style!.foregroundColor!.resolve(<WidgetState>{}), danger);
      final cancel = tester.widget<TextButton>(
        find.byKey(const Key('safety_actions_block_cancel')),
      );
      expect(cancel.style?.foregroundColor?.resolve(<WidgetState>{}), isNull);
    });
  }

  testWidgets('block dialog falls back to "this person"', (tester) async {
    await pump(tester);
    await choose(tester, 'safety_actions_block_item');
    expect(find.text('Block this person?'), findsOneWidget);
  });

  testWidgets('report sheet from the menu is titled with the name', (
    tester,
  ) async {
    await pump(tester, name: 'Bastien');
    await choose(tester, 'safety_actions_report_item');
    expect(find.text('Report Bastien'), findsOneWidget);
  });
}
