import 'package:flutter/material.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

/// "Couldn't load" block with a Try again button for failed feed loads.
class ErrorState extends StatelessWidget {
  /// Creates an error state whose button calls [onRetry].
  const ErrorState({
    required this.onRetry,
    this.title,
    this.message,
    super.key,
  });

  /// Called when the user taps Try again.
  final VoidCallback onRetry;

  /// Headline; defaults to the localised "Couldn't load this".
  final String? title;

  /// Supporting text under [title]; defaults to the localised connection hint.
  final String? message;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_rounded,
    title: title ?? context.l10n.errorStateTitle,
    message: message ?? context.l10n.errorStateMessage,
    mutedTitle: false,
    announce: true,
    action: AppButton(
      label: context.l10n.commonTryAgain,
      variant: AppButtonVariant.tonal,
      expand: false,
      onPressed: onRetry,
    ),
  );
}
