import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/safety/application/report_controller.dart';
import 'package:not_eat_alone/features/safety/application/report_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/report_repository.dart';

import '../../../helpers/in_flight_dispose.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockReportRepository extends Mock implements ReportRepository {}

void main() {
  late MockAuthRepository authRepository;
  late MockReportRepository reportRepository;
  late ProviderContainer container;

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

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        reportRepositoryProvider.overrideWithValue(reportRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ReportController', () {
    test(
      'submit() calls repo.report with myUid and leaves state AsyncData',
      () async {
        await container
            .read(reportControllerProvider.notifier)
            .submit(targetType: 'user', targetId: 'x', reason: 'spam');

        verify(
          () => reportRepository.report(
            reporterId: 'me',
            targetType: 'user',
            targetId: 'x',
            reason: 'spam',
          ),
        ).called(1);

        final state = container.read(reportControllerProvider);
        expect(state.hasError, isFalse);
        expect(state, isA<AsyncData<void>>());
      },
    );

    test('submit() leaves state.hasError true when the repo throws', () async {
      when(
        () => reportRepository.report(
          reporterId: any(named: 'reporterId'),
          targetType: any(named: 'targetType'),
          targetId: any(named: 'targetId'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(Exception('boom'));

      await container
          .read(reportControllerProvider.notifier)
          .submit(targetType: 'user', targetId: 'x');

      final state = container.read(reportControllerProvider);
      expect(state.hasError, isTrue);
    });
  });

  // Regression: the controller's only watcher unmounting mid-action used
  // to dispose it, so the trailing `state =` threw UnmountedRefException.
  test('ReportController.submit survives its listener '
      'unmounting mid-flight', () async {
    final gate = Completer<void>();
    when(
      () => reportRepository.report(
        reporterId: any(named: 'reporterId'),
        targetType: any(named: 'targetType'),
        targetId: any(named: 'targetId'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) => gate.future);
    final seen = await runWithListenerRemovedMidFlight(
      container,
      reportControllerProvider,
      action: () => container
          .read(reportControllerProvider.notifier)
          .submit(targetType: 'user', targetId: 'x'),
      release: gate.complete,
    );

    expect(seen.first.isLoading, isTrue);
    expect(seen.last, isA<AsyncData<void>>());
  });
}
