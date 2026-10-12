import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:not_eat_alone/core/util/queued_write.dart';
import 'package:not_eat_alone/core/analytics/client.dart' as analytics;
import 'package:not_eat_alone/core/analytics/events.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';

part 'chat_controller.g.dart';

@riverpod
class ChatController extends _$ChatController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> send({required String matchId, required String text}) async {
    if (text.trim().isEmpty) return;
    // Keep alive until settled — see CreateRequestController.request.
    final link = ref.keepAlive();
    try {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        final uid = ref.read(authRepositoryProvider).currentUser!.uid;
        await settleOrQueue(
          ref.read(chatRepositoryProvider).sendMessage(
                matchId: matchId, senderId: uid, text: text,
              ),
        );
        await analytics.track(const MessageSent());
      });
    } finally {
      link.close();
    }
  }

  Future<void> markRead(String matchId) async {
    final uid = ref.read(authRepositoryProvider).currentUser!.uid;
    await ref.read(chatRepositoryProvider).markRead(matchId: matchId, uid: uid);
  }
}
