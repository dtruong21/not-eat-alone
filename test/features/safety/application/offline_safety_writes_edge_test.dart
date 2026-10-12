import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/util/queued_write.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/safety/application/block_controller.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';
import 'package:not_eat_alone/features/safety/application/report_controller.dart';
import 'package:not_eat_alone/features/safety/application/report_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/block_repository.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/report_repository.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockBlock extends Mock implements BlockRepository {}

class _MockReport extends Mock implements ReportRepository {}

/// QA sweep 2026-10-12: the offline fix (`settleOrQueue`) was applied to chat,
/// create-meal, request and rating, but Block and Report still await the
/// server acknowledgement. Offline, Firestore queues the write and its Future
/// never completes, so the report sheet / block flow stays on a spinner (and
/// the chat is not left after blocking) for as long as the network is down,
/// in exactly the situation (bad network, someone to get away from) where it
/// matters most.
/// Bug: docs/bugs/2026-10-12-report-and-block-spin-forever-offline.md
const _bug = 'docs/bugs/2026-10-12-report-and-block-spin-forever-offline.md';

void main() {
  late _MockAuth auth;
  late _MockBlock block;
  late _MockReport report;

  setUp(() {
    auth = _MockAuth();
    block = _MockBlock();
    report = _MockReport();
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'me'));
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        blockRepositoryProvider.overrideWithValue(block),
        reportRepositoryProvider.overrideWithValue(report),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('harness: a write acknowledged at once completes block()', () {
    fakeAsync((async) {
      when(() => block.block(any(), any())).thenAnswer((_) async {});
      var done = false;
      unawaited(
        container()
            .read(blockControllerProvider.notifier)
            .block('x')
            .then((_) => done = true),
      );
      async.flushMicrotasks();
      expect(done, isTrue);
    });
  });

  test('block() is released after the grace period when offline', () {
    fakeAsync((async) {
      final neverAcked = Completer<void>();
      when(() => block.block(any(), any())).thenAnswer((_) => neverAcked.future);
      var done = false;
      unawaited(
        container()
            .read(blockControllerProvider.notifier)
            .block('x')
            .then((_) => done = true),
      );
      async.elapse(queuedWriteGrace + const Duration(seconds: 1));
      expect(done, isTrue, reason: _bug);
    });
  }, skip: 'open bug: $_bug');

  test('report submit() is released after the grace period when offline', () {
    fakeAsync((async) {
      final neverAcked = Completer<void>();
      when(
        () => report.report(
          reporterId: any(named: 'reporterId'),
          targetType: any(named: 'targetType'),
          targetId: any(named: 'targetId'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) => neverAcked.future);
      var done = false;
      unawaited(
        container()
            .read(reportControllerProvider.notifier)
            .submit(targetType: 'user', targetId: 'x', reason: 'spam')
            .then((_) => done = true),
      );
      async.elapse(queuedWriteGrace + const Duration(seconds: 1));
      expect(done, isTrue, reason: _bug);
    });
  }, skip: 'open bug: $_bug');
}
