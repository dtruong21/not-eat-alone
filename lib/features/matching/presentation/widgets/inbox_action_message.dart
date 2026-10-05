/// Pure mapping from an inbox action's outcome to the snackbar text the host
/// sees. Kept free of Flutter/Riverpod so every row is unit-testable.
library;

import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';

/// A host decision on a pending join request.
enum InboxAction {
  /// The host accepts the request.
  approve,

  /// The host declines the request.
  deny,
}

/// Snackbar text for [action] given its outcome: [error] is `null` on
/// success, otherwise whatever the controller surfaced.
///
/// One generic wording covers "any other error" on purpose: the app layer
/// cannot tell permission-denied causes apart (already decided, past meal,
/// offline) without leaking Firebase types, and all of them mean nothing
/// changed.
String inboxActionMessage(InboxAction action, Object? error) {
  switch (action) {
    case InboxAction.approve:
      if (error == null) return 'Approved. You can chat now.';
      if (error is MealNoLongerOpenException) {
        return 'This meal is no longer open.';
      }
      return "Couldn't approve this request. It may already have been handled.";
    case InboxAction.deny:
      if (error == null) return 'Request denied.';
      return "Couldn't deny this request. It may already have been handled.";
  }
}

/// Whether the snackbar carries the **Chat** action: only after a successful
/// approve (the chat exists then).
bool inboxActionHasChatAction(InboxAction action, Object? error) =>
    action == InboxAction.approve && error == null;
