import 'package:flutter/material.dart';
import 'package:not_eat_alone/core/design/widgets/app_button.dart';
import 'package:not_eat_alone/core/design/widgets/empty_state.dart';

/// "Couldn't load" block with a Try again button for failed feed loads.
class ErrorState extends StatelessWidget {
  /// Creates an error state whose button calls [onRetry].
  const ErrorState({
    required this.onRetry,
    this.title = "Couldn't load this",
    this.message = 'Check your connection and try again.',
    super.key,
  });

  /// Called when the user taps Try again.
  final VoidCallback onRetry;

  /// Headline.
  final String title;

  /// Supporting text under [title].
  final String message;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_rounded,
    title: title,
    message: message,
    mutedTitle: false,
    announce: true,
    action: AppButton(
      label: 'Try again',
      variant: AppButtonVariant.tonal,
      expand: false,
      onPressed: onRetry,
    ),
  );
}
