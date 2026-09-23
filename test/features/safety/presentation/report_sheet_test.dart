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

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          reportRepositoryProvider.overrideWithValue(reportRepository),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
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
      find.byKey(const Key('report_submit_button')),
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
        find.byKey(const Key('report_submit_button')),
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
}
