import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/matching/application/request_providers.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';

/// All pending requests across the signed-in host's meals, newest first.
final hostInboxProvider = StreamProvider<List<JoinRequest>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(requestRepositoryProvider).watchPendingForHost(uid);
});

/// Pending-request count for the discovery app-bar badge (0 when none/loading).
final pendingRequestCountProvider = Provider<int>((ref) {
  return ref.watch(hostInboxProvider).maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
});
