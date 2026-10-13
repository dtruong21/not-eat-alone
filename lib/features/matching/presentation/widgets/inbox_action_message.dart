/// Pure mapping from an inbox action's outcome to a typed [InboxOutcome], plus
/// its localised snackbar text. The outcome mapping uses no widgets or
/// Riverpod, so every row is unit-testable; only [localizeInboxOutcome]
/// touches l10n.
library;

import 'package:not_eat_alone/features/matching/domain/inbox_action.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';

export 'package:not_eat_alone/features/matching/domain/inbox_action.dart';

/// What the host is told after an Approve/Deny.
enum InboxOutcome {
  /// Approve succeeded.
  approved,

  /// Approve failed because the meal is no longer open.
  mealNoLongerOpen,

  /// Approve failed for any other reason.
  approveFailed,

  /// Deny succeeded.
  denied,

  /// Deny failed.
  denyFailed,
}

/// The outcome of [action] given its [error]: `null` on success, otherwise
/// whatever the controller surfaced.
///
/// One generic failure covers "any other error" on purpose: the app layer
/// cannot tell permission-denied causes apart (already decided, past meal,
/// offline) without leaking Firebase types, and all of them mean nothing
/// changed.
InboxOutcome inboxOutcome(InboxAction action, Object? error) {
  switch (action) {
    case InboxAction.approve:
      if (error == null) return InboxOutcome.approved;
      if (error is MealNoLongerOpenException) {
        return InboxOutcome.mealNoLongerOpen;
      }
      return InboxOutcome.approveFailed;
    case InboxAction.deny:
      return error == null ? InboxOutcome.denied : InboxOutcome.denyFailed;
  }
}

/// Snackbar text for [outcome] in the language of [l10n].
String localizeInboxOutcome(AppLocalizations l10n, InboxOutcome outcome) =>
    switch (outcome) {
      InboxOutcome.approved => l10n.inboxOutcomeApproved,
      InboxOutcome.mealNoLongerOpen => l10n.mealActionNoLongerOpen,
      InboxOutcome.approveFailed => l10n.inboxOutcomeApproveFailed,
      InboxOutcome.denied => l10n.inboxOutcomeDenied,
      InboxOutcome.denyFailed => l10n.inboxOutcomeDenyFailed,
    };

/// Whether the snackbar carries the **Chat** action: only after a successful
/// approve (the chat exists then).
bool inboxActionHasChatAction(InboxAction action, Object? error) =>
    action == InboxAction.approve && error == null;
