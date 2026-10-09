import 'package:flutter/material.dart';
import 'package:not_eat_alone/core/design/tokens.dart';

/// Which Material button [AppButton] builds.
enum AppButtonVariant { primary, tonal, outlined, text }

/// The one button for the app: themed Material button with a visible,
/// size-stable loading state.
///
/// While [isLoading] the enabled colours are kept (not the grey disabled
/// fill), taps are ignored, and a spinner in the foreground colour shows
/// beside [loadingLabel] (default [label]). Idle and loading content sit in an
/// `IndexedStack`, so the button never changes size between the two.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.loadingLabel,
    this.icon,
    this.expand = true,
    super.key,
  });

  /// Button text.
  final String label;

  /// Tap handler; null disables the button.
  final VoidCallback? onPressed;

  /// Which Material button to build.
  final AppButtonVariant variant;

  /// Swaps the content for a spinner + [loadingLabel] and ignores taps.
  final bool isLoading;

  /// Text shown (and announced) while loading; defaults to [label].
  final String? loadingLabel;

  /// Optional leading widget, replaced by the spinner while loading.
  final Widget? icon;

  /// Full width. Height is `actionHeight` for primary/tonal, `minTap` otherwise.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final big =
        variant == AppButtonVariant.primary ||
        variant == AppButtonVariant.tonal;
    final minimumSize = Size(
      expand ? double.infinity : 0,
      big ? WarmPlayfulSize.actionHeight : WarmPlayfulSize.minTap,
    );

    // Keep the enabled look while loading (the button is disabled to swallow
    // taps, which would otherwise grey it out and hide the spinner).
    final (fill, foreground) = switch (variant) {
      AppButtonVariant.primary => (scheme.primary, scheme.onPrimary),
      AppButtonVariant.tonal => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      AppButtonVariant.outlined ||
      AppButtonVariant.text => (Colors.transparent, scheme.onSurface),
    };
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(minimumSize),
      // Only set while loading so the theme's disabled colours still apply
      // to a plainly disabled button.
      backgroundColor: isLoading && big ? WidgetStatePropertyAll(fill) : null,
      foregroundColor: isLoading ? WidgetStatePropertyAll(foreground) : null,
    );

    final text = Text(
      label,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
    final child = IndexedStack(
      alignment: Alignment.center,
      index: isLoading ? 1 : 0,
      children: [
        _Content(icon: icon, text: text),
        _Content(
          // A sized stand-in while idle: an offstage spinner would keep animating
          // and stop pumpAndSettle from settling.
          icon: isLoading
              ? _Spinner(color: foreground)
              : const SizedBox.square(dimension: WarmPlayfulSize.spinner),
          text: Text(
            loadingLabel ?? label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final handler = isLoading ? null : onPressed;
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: handler,
        style: style,
        child: child,
      ),
      AppButtonVariant.tonal => FilledButton.tonal(
        onPressed: handler,
        style: style,
        child: child,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: handler,
        style: style,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: handler,
        style: style,
        child: child,
      ),
    };
    // Loading: one disabled-button node that announces the loading label.
    // Always wrapped so toggling isLoading does not remount the button.
    return Semantics(
      container: isLoading,
      button: isLoading ? true : null,
      enabled: isLoading ? false : null,
      liveRegion: isLoading,
      label: isLoading ? (loadingLabel ?? label) : null,
      excludeSemantics: isLoading,
      child: button,
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.icon, required this.text});

  final Widget? icon;
  final Widget text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (icon != null) ...[
        icon!,
        const SizedBox(width: WarmPlayfulSpacing.s2),
      ],
      Flexible(child: text),
    ],
  );
}

/// Spinner in the button's foreground colour.
class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: WarmPlayfulSize.spinner,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    ),
  );
}
