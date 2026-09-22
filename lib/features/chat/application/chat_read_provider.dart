import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/domain/entities/message_read.dart';

typedef ReadKey = ({String matchId, String otherUid});

final otherReadProvider =
    StreamProvider.family<MessageRead?, ReadKey>((ref, key) {
  return ref
      .watch(chatRepositoryProvider)
      .watchRead(matchId: key.matchId, uid: key.otherUid);
});
