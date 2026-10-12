import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/chat/application/chat_providers.dart';
import 'package:not_eat_alone/features/chat/domain/entities/message_read.dart';

typedef ReadKey = ({String matchId, String otherUid});

/// The other participant's read state. Auto-disposed and tied to the signed-in
/// uid (see [chatMessagesProvider]).
final otherReadProvider = StreamProvider.autoDispose
    .family<MessageRead?, ReadKey>((ref, key) {
      switch (watchSession(ref)) {
        case SessionState.resolving:
          return const Stream.empty();
        case SessionState.signedOut:
          return Stream.value(null);
        case SessionState.signedIn:
          break;
      }
      return ref
          .watch(chatRepositoryProvider)
          .watchRead(matchId: key.matchId, uid: key.otherUid);
    });
