/// App-level channel for writes that were queued offline and then rejected
/// after the UI moved on (see `queued_write.dart`). Controllers report a
/// [QueuedWriteKind]; `QueuedWriteFailureListener` (mounted above the router)
/// shows the localized message. The notifier is NOT autoDispose, so a report
/// still lands after the screen that started the write is gone.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which user action's write failed late.
enum QueuedWriteKind {
  /// A request to join a meal.
  joinRequest,

  /// A newly created meal.
  meal,

  /// A post-meal rating.
  rating,

  /// A chat message.
  message,
}

/// One reported failure. [id] increments so the same kind twice still notifies.
class QueuedWriteFailure {
  /// Creates a failure event.
  const QueuedWriteFailure(this.kind, this.id);

  /// The action that failed.
  final QueuedWriteKind kind;

  /// Monotonic event number.
  final int id;
}

/// Latest late failure, or null before any.
class QueuedWriteFailures extends Notifier<QueuedWriteFailure?> {
  var _next = 0;

  @override
  QueuedWriteFailure? build() => null;

  /// Records a late failure of [kind].
  void report(QueuedWriteKind kind) =>
      state = QueuedWriteFailure(kind, ++_next);
}

/// The app-level (keep-alive) failure channel.
final queuedWriteFailuresProvider =
    NotifierProvider<QueuedWriteFailures, QueuedWriteFailure?>(
      QueuedWriteFailures.new,
    );
