import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/safety/application/report_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/report_repository.dart';
import 'package:not_eat_alone/features/safety/presentation/report_sheet.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockReportRepository extends Mock implements ReportRepository {}

void main() {
  late MockAuthRepository authRepository;
  late MockReportRepository reportRepository;

  setUp(() {
    authRepository = MockAuthRepository();
    reportRepository = MockReportRepository();

    when(
      () => authRepository.currentUser,
    ).thenReturn(const AuthUser(uid: 'me'));
    when(
      () => reportRepository.report(
        reporterId: any(named: 'reporterId'),
        targetType: any(named: 'targetType'),
        targetId: any(named: 'targetId'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          reportRepositoryProvider.overrideWithValue(reportRepository),
        ],
        child: MaterialApp(
          theme: buildTheme(brightness),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showReportSheet(
                  context,
                  targetType: 'user',
                  targetId: 'them',
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
  }

  testWidgets('Submit is disabled until a reason is picked', (tester) async {
    await pumpSheet(tester);

    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('report_submit_button')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'picking a reason then submitting calls ReportController.submit '
    'with the target + reason',
    (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.byKey(const Key('report_reason_chip_spam')));
      await tester.pump();

      final enabledButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('report_submit_button')),
        matching: find.byType(FilledButton),
      ),
    );
      expect(enabledButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('report_submit_button')));
      await tester.pumpAndSettle();

      verify(
        () => reportRepository.report(
          reporterId: 'me',
          targetType: 'user',
          targetId: 'them',
          reason: 'spam',
        ),
      ).called(1);

      expect(find.text("Thanks — we'll review this."), findsOneWidget);
    },
  );

  for (final b in Brightness.values) {
    testWidgets('in-flight spinner stays visible on the button fill ($b)', (
      tester,
    ) async {
      final inFlight = Completer<void>();
      when(
        () => reportRepository.report(
          reporterId: any(named: 'reporterId'),
          targetType: any(named: 'targetType'),
          targetId: any(named: 'targetId'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) => inFlight.future);
      await pumpSheet(tester, brightness: b);

      await tester.tap(find.byKey(const Key('report_reason_chip_spam')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report_submit_button')));
      await tester.pump();

      final button = find.byKey(const Key('report_submit_button'));
      final fill = tester
          .widget<Material>(
            find
                .descendant(of: button, matching: find.byType(Material))
                .first,
          )
          .color!;
      final spinner = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: button,
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      final la = spinner.color!.computeLuminance();
      final lb = fill.computeLuminance();
      final ratio = (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
      expect(ratio, greaterThanOrEqualTo(3));
      // Still disabled: no tap-through while sending.
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: button, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNull,
      );

      inFlight.complete();
      await tester.pumpAndSettle();
    });
  }
}
