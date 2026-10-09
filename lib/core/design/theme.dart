/// Material 3 theme for the Warm Playful design system.
///
/// Builds [ThemeData] from a seed color via [ColorScheme.fromSeed], then
/// overrides cream/peach surfaces and warm brown text/borders to match the
/// hand-picked tokens. The 5-color category palette is exposed through a
/// [ThemeExtension] so widgets can do:
///
/// ```dart
/// final palette = Theme.of(context).extension<WarmPlayfulExtensions>()!;
/// Container(color: palette.peach);
/// ```
///
/// Typography is Nunito, bundled as an asset (no runtime download). Heavier
/// weights (700/800) are used for titles — Nunito carries weight well.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:not_eat_alone/core/design/tokens.dart';

/// Builds the Warm Playful [ThemeData] for the given [brightness].
ThemeData buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  final bg = isLight ? WarmPlayfulColorsLight.bg : WarmPlayfulColorsDark.bg;
  final surface = isLight
      ? WarmPlayfulColorsLight.surface
      : WarmPlayfulColorsDark.surface;
  final border = isLight
      ? WarmPlayfulColorsLight.border
      : WarmPlayfulColorsDark.border;
  final divider = isLight
      ? WarmPlayfulColorsLight.divider
      : WarmPlayfulColorsDark.divider;
  final text = isLight
      ? WarmPlayfulColorsLight.text
      : WarmPlayfulColorsDark.text;
  final muted = isLight
      ? WarmPlayfulColorsLight.muted
      : WarmPlayfulColorsDark.muted;
  final subtle = isLight
      ? WarmPlayfulColorsLight.subtle
      : WarmPlayfulColorsDark.subtle;
  final accent = isLight
      ? WarmPlayfulColorsLight.accent
      : WarmPlayfulColorsDark.accent;
  final success = isLight
      ? WarmPlayfulColorsLight.success
      : WarmPlayfulColorsDark.success;
  final danger = isLight
      ? WarmPlayfulColorsLight.danger
      : WarmPlayfulColorsDark.danger;
  final warning = isLight
      ? WarmPlayfulColorsLight.warning
      : WarmPlayfulColorsDark.warning;
  final dangerText = isLight
      ? WarmPlayfulColorsLight.dangerText
      : WarmPlayfulColorsDark.dangerText;
  final onAccent = isLight
      ? WarmPlayfulColorsLight.onAccent
      : WarmPlayfulColorsDark.onAccent;
  final shadow = isLight
      ? WarmPlayfulColorsLight.shadow
      : WarmPlayfulColorsDark.shadow;

  final palettePeach = isLight
      ? WarmPlayfulColorsLight.palettePeach
      : WarmPlayfulColorsDark.palettePeach;
  final paletteSage = isLight
      ? WarmPlayfulColorsLight.paletteSage
      : WarmPlayfulColorsDark.paletteSage;
  const lightText = WarmPlayfulColorsLight.text;
  // Snackbars invert the page: brown on light, cream on dark.
  final inverse = isLight
      ? WarmPlayfulColorsLight.text
      : WarmPlayfulColorsDark.text;
  final onInverse = isLight
      ? WarmPlayfulColorsDark.text
      : WarmPlayfulColorsLight.text;

  // Dark-mode snackbar is cream, where the coral accent is only ~1.9:1; use
  // the AA-checked error-text terracotta instead.
  const snackActionDark = WarmPlayfulColorsLight.dangerText;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: WarmPlayfulTokens.seed,
        brightness: brightness,
        // Pin the variant explicitly — Material 3 may change defaults.
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ).copyWith(
        primary: accent,
        onPrimary: onAccent,
        onSurfaceVariant: muted,
        // Container roles: pastel mid-tones take the light brown label in both
        // modes (>= 4.5:1, see container_roles_test). secondaryContainer is
        // surface so FilledButton.tonal reads as a quiet card-coloured button.
        primaryContainer: palettePeach,
        onPrimaryContainer: lightText,
        secondaryContainer: surface,
        onSecondaryContainer: text,
        tertiaryContainer: paletteSage,
        onTertiaryContainer: lightText,
        errorContainer: isLight
            ? WarmPlayfulColorsLight.errorContainer
            : WarmPlayfulColorsDark.errorContainer,
        onErrorContainer: text,
        inverseSurface: inverse,
        onInverseSurface: onInverse,
        surface: surface,
        onSurface: text,
        surfaceContainerLowest: bg,
        surfaceContainerLow: bg,
        surfaceContainer: surface,
        surfaceContainerHigh: surface,
        surfaceContainerHighest: surface,
        outline: border,
        outlineVariant: divider,
        error: dangerText,
        onError: bg,
        tertiary: success,
      );

  // Nunito (bundled asset). Every style below carries the family explicitly.
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    dividerColor: divider,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    fontFamily: WarmPlayfulFonts.body,
  );

  final textTheme = base.textTheme
      .apply(fontFamily: WarmPlayfulFonts.body)
      .copyWith(
    displayLarge: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.displaySize,
      height: WarmPlayfulType.displayHeight,
      fontWeight: WarmPlayfulType.displayWeight,
      color: text,
    ),
    displayMedium: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.displaySize,
      height: WarmPlayfulType.displayHeight,
      fontWeight: WarmPlayfulType.displayWeight,
      color: text,
    ),
    headlineLarge: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.h1Size,
      height: WarmPlayfulType.h1Height,
      fontWeight: WarmPlayfulType.h1Weight,
      color: text,
    ),
    headlineMedium: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.h1Size,
      height: WarmPlayfulType.h1Height,
      fontWeight: WarmPlayfulType.h1Weight,
      color: text,
    ),
    titleLarge: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.h2Size,
      height: WarmPlayfulType.h2Height,
      fontWeight: WarmPlayfulType.h2Weight,
      color: text,
    ),
    titleMedium: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.h2Size,
      height: WarmPlayfulType.h2Height,
      fontWeight: WarmPlayfulType.h2Weight,
      color: text,
    ),
    bodyLarge: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.bodySize,
      height: WarmPlayfulType.bodyHeight,
      fontWeight: WarmPlayfulType.bodyWeight,
      color: text,
    ),
    bodyMedium: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.bodySize,
      height: WarmPlayfulType.bodyHeight,
      fontWeight: WarmPlayfulType.bodyWeight,
      color: text,
    ),
    bodySmall: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.captionSize,
      height: WarmPlayfulType.captionHeight,
      fontWeight: WarmPlayfulType.captionWeight,
      color: muted,
    ),
    labelLarge: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.bodySize,
      height: WarmPlayfulType.bodyHeight,
      fontWeight: FontWeight.w700, // buttons get weight
      color: text,
    ),
    labelMedium: TextStyle(
      fontFamily: WarmPlayfulFonts.body,
      fontSize: WarmPlayfulType.captionSize,
      height: WarmPlayfulType.captionHeight,
      fontWeight: WarmPlayfulType.captionWeight,
      color: muted,
    ),
  );

  const buttonPadding = EdgeInsets.symmetric(
    horizontal: WarmPlayfulSpacing.s5,
    vertical: WarmPlayfulSpacing.s3,
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: WarmPlayfulElevation.card,
      shadowColor: shadow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 0,
        minimumSize: const Size(0, WarmPlayfulSize.minTap),
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: textTheme.labelLarge?.copyWith(color: onAccent),
      ),
    ),
    // FilledButton.tonal shares this theme in Flutter, so fills/labels are left
    // to the scheme: primary/onPrimary (coral/brown) and
    // secondaryContainer/onSecondaryContainer (surface/text).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        disabledBackgroundColor: border,
        disabledForegroundColor: subtle,
        minimumSize: const Size(0, WarmPlayfulSize.minTap),
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    // secondaryContainer is surface-coloured (tonal buttons), so the
    // components that selected with it use the accent explicitly.
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: accent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected) ? onAccent : muted,
        ),
      ),
    ),
    // Off state: muted thumb and outline (>= 3:1 on the surface track) instead
    // of the border colour; selected: onAccent thumb on the coral track.
    // Disabled falls back to the Material defaults (null).
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        return states.contains(WidgetState.selected) ? onAccent : muted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        return states.contains(WidgetState.selected) ? accent : surface;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        return states.contains(WidgetState.selected)
            ? Colors.transparent
            : muted;
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: muted)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onAccent : text,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        disabledForegroundColor: subtle,
        side: BorderSide(color: muted, width: 1.5),
        minimumSize: const Size(0, WarmPlayfulSize.minTap),
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: onAccent,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: text,
        minimumSize: const Size(0, WarmPlayfulSize.minTap),
        padding: const EdgeInsets.symmetric(
          horizontal: WarmPlayfulSpacing.s4,
          vertical: WarmPlayfulSpacing.s3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: WarmPlayfulSpacing.s4,
        vertical: WarmPlayfulSpacing.s3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
      labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: accent,
      labelStyle: textTheme.bodySmall?.copyWith(color: text),
      secondaryLabelStyle: textTheme.bodySmall?.copyWith(color: onAccent),
      checkmarkColor: onAccent,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.pill),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: WarmPlayfulSpacing.s3,
        vertical: WarmPlayfulSpacing.s1,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: isLight ? palettePeach : snackActionDark,
      closeIconColor: scheme.onInverseSurface,
      shape: buttonShape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WarmPlayfulRadius.xl),
        ),
      ),
      showDragHandle: true,
      dragHandleColor: border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: text, size: 24),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    extensions: <ThemeExtension<dynamic>>[
      WarmPlayfulExtensions(
        // Category palette
        peach: isLight
            ? WarmPlayfulColorsLight.palettePeach
            : WarmPlayfulColorsDark.palettePeach,
        sage: isLight
            ? WarmPlayfulColorsLight.paletteSage
            : WarmPlayfulColorsDark.paletteSage,
        butter: isLight
            ? WarmPlayfulColorsLight.paletteButter
            : WarmPlayfulColorsDark.paletteButter,
        lavender: isLight
            ? WarmPlayfulColorsLight.paletteLavender
            : WarmPlayfulColorsDark.paletteLavender,
        sky: isLight
            ? WarmPlayfulColorsLight.paletteSky
            : WarmPlayfulColorsDark.paletteSky,
        // Semantic extras not in ColorScheme
        success: success,
        warning: warning,
        danger: danger,
        dangerText: dangerText,
        onAccent: onAccent,
        shadow: shadow,
        // Surfaces + text shades not cleanly mapped to ColorScheme
        muted: muted,
        subtle: subtle,
        border: border,
        divider: divider,
      ),
    ],
  );
}

/// Theme extension carrying the Warm Playful 5-color category palette and a
/// handful of semantic colors that don't cleanly map to Material's
/// [ColorScheme] (muted text, divider, success/warning scales).
///
/// Access via:
/// ```dart
/// final wp = Theme.of(context).extension<WarmPlayfulExtensions>()!;
/// Container(color: wp.peach);
/// Text('...', style: TextStyle(color: wp.muted));
/// ```
@immutable
class WarmPlayfulExtensions extends ThemeExtension<WarmPlayfulExtensions> {
  const WarmPlayfulExtensions({
    required this.peach,
    required this.sage,
    required this.butter,
    required this.lavender,
    required this.sky,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerText,
    required this.onAccent,
    required this.shadow,
    required this.muted,
    required this.subtle,
    required this.border,
    required this.divider,
  });

  // Category palette — the signature 5.
  final Color peach;
  final Color sage;
  final Color butter;
  final Color lavender;
  final Color sky;

  // Semantic colors not in ColorScheme.
  final Color success;
  final Color warning;
  final Color danger;

  /// Error text/icon colour readable (>= 4.5:1) on page and cards.
  final Color dangerText;

  /// Label colour on coral accent fills.
  final Color onAccent;

  /// Card/elevation shadow colour.
  final Color shadow;

  // Surface/text shades not in ColorScheme.
  final Color muted;
  final Color subtle;
  final Color border;
  final Color divider;

  /// Convenient ordered list of the 5 category colors, e.g. for assigning
  /// a habit category color by index.
  List<Color> get categoryPalette => <Color>[
    peach,
    sage,
    butter,
    lavender,
    sky,
  ];

  @override
  WarmPlayfulExtensions copyWith({
    Color? peach,
    Color? sage,
    Color? butter,
    Color? lavender,
    Color? sky,
    Color? success,
    Color? warning,
    Color? danger,
    Color? dangerText,
    Color? onAccent,
    Color? shadow,
    Color? muted,
    Color? subtle,
    Color? border,
    Color? divider,
  }) {
    return WarmPlayfulExtensions(
      peach: peach ?? this.peach,
      sage: sage ?? this.sage,
      butter: butter ?? this.butter,
      lavender: lavender ?? this.lavender,
      sky: sky ?? this.sky,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      dangerText: dangerText ?? this.dangerText,
      onAccent: onAccent ?? this.onAccent,
      shadow: shadow ?? this.shadow,
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      border: border ?? this.border,
      divider: divider ?? this.divider,
    );
  }

  @override
  WarmPlayfulExtensions lerp(
    ThemeExtension<WarmPlayfulExtensions>? other,
    double t,
  ) {
    if (other is! WarmPlayfulExtensions) return this;
    return WarmPlayfulExtensions(
      peach: Color.lerp(peach, other.peach, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      butter: Color.lerp(butter, other.butter, t)!,
      lavender: Color.lerp(lavender, other.lavender, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

/// `context.wp` shortcut for the Warm Playful theme extension.
extension WarmPlayfulContext on BuildContext {
  WarmPlayfulExtensions get wp =>
      Theme.of(this).extension<WarmPlayfulExtensions>()!;
}
