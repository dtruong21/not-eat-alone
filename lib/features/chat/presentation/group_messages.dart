/// Pure grouping of a chat thread into day separators and message runs.
///
/// Input is ascending by time (the stream's order); output is the same order,
/// with a [DaySeparatorEntry] before the first message of each local calendar
/// day. A [MessageEntry.endsRun] message is the last of a run: the next
/// message is from someone else, more than [runGap] later, on another day, or
/// absent. Only those bubbles show a timestamp (CHAT-05).
library;

import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';

/// Longest pause inside one run of same-sender messages.
const runGap = Duration(minutes: 5);

sealed class ChatListEntry {
  const ChatListEntry();
}

/// A centred day label ("Today", "Yesterday", "Mon 5 Oct").
class DaySeparatorEntry extends ChatListEntry {
  const DaySeparatorEntry(this.label);

  final String label;
}

class MessageEntry extends ChatListEntry {
  const MessageEntry(this.message, {required this.endsRun});

  final ChatMessage message;

  /// Last bubble of its run: shows the timestamp and the wider gap below.
  final bool endsRun;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Groups [messages] (ascending) for display. A message whose server
/// timestamp has not arrived yet counts as sent at [now].
List<ChatListEntry> groupMessages(List<ChatMessage> messages, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toLocal();
  DateTime timeOf(ChatMessage m) => (m.createdAt ?? reference).toLocal();

  final entries = <ChatListEntry>[];
  for (var i = 0; i < messages.length; i++) {
    final message = messages[i];
    final at = timeOf(message);
    // Calendar fields, not a Duration: a DST day is 23 or 25 hours long.
    if (i == 0 || !_sameDay(timeOf(messages[i - 1]), at)) {
      entries.add(DaySeparatorEntry(formatDayLabel(at, now: reference)));
    }
    final next = i + 1 < messages.length ? messages[i + 1] : null;
    final nextAt = next == null ? null : timeOf(next);
    final continuesRun =
        next != null &&
        next.senderId == message.senderId &&
        _sameDay(at, nextAt!) &&
        nextAt.difference(at) <= runGap;
    entries.add(MessageEntry(message, endsRun: !continuesRun));
  }
  return entries;
}
