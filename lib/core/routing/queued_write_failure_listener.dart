/// Shows a snackbar when a write that was queued offline is rejected after the
/// UI moved on. Mounted via `MaterialApp.router(builder:)` so it lives above
/// the router: a late failure shows on any route (meal detail, chat, tabs),
/// not only inside the tab shell. Silent while signed out.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/core/util/queued_write_failures.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

/// Wraps [child] (the router) with the late-write-failure snackbar.
class QueuedWriteFailureListener extends ConsumerStatefulWidget {
  /// Creates the listener.
  const QueuedWriteFailureListener({required this.child, super.key});

  /// The app content (router) underneath.
  final Widget child;

  @override
  ConsumerState<QueuedWriteFailureListener> createState() =>
      _QueuedWriteFailureListenerState();
}

class _QueuedWriteFailureListenerState
    extends ConsumerState<QueuedWriteFailureListener> {
  /// Failures arriving while this runs are folded into the snackbar shown.
  static const _quietPeriod = Duration(seconds: 2);
  Timer? _quiet;
  String? _uid;

  @override
  void dispose() {
    _quiet?.cancel();
    super.dispose();
  }

  void _onFailure(QueuedWriteFailure? previous, QueuedWriteFailure? next) {
    if (next == null || (_quiet?.isActive ?? false)) return;
    if (_uid == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final l10n = context.l10n;
    final text = switch (next.kind) {
      QueuedWriteKind.joinRequest => l10n.queuedWriteJoinRequestFailed,
      QueuedWriteKind.meal => l10n.queuedWriteMealFailed,
      QueuedWriteKind.rating => l10n.queuedWriteRatingFailed,
      QueuedWriteKind.message => l10n.queuedWriteMessageFailed,
    };
    _quiet = Timer(_quietPeriod, () {});
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    _uid = ref.watch(authStateProvider.select((u) => u.value?.uid));
    ref.listen<QueuedWriteFailure?>(queuedWriteFailuresProvider, _onFailure);
    return widget.child;
  }
}
