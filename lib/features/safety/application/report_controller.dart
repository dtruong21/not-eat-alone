/// Report controller — mirrors `BlockController`'s shape (see that file for
/// the master-spec idiom).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/safety/application/report_providers.dart';

part 'report_controller.g.dart';

@riverpod
class ReportController extends _$ReportController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> submit({
    required String targetType,
    required String targetId,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authRepositoryProvider).currentUser!.uid;
      await ref
          .read(reportRepositoryProvider)
          .report(
            reporterId: uid,
            targetType: targetType,
            targetId: targetId,
            reason: reason,
          );
      await analytics.track(UserReported(targetType: targetType));
    });
  }
}
