import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import '../../support/contrast.dart';

void main() {
  for (final b in Brightness.values) {
    group('container roles ($b)', () {
      final theme = buildTheme(b);
      final s = theme.colorScheme;
      final wp = theme.extension<WarmPlayfulExtensions>()!;
      final light = b == Brightness.light;

      final pairs = <String, (Color, Color)>{
        'primaryContainer': (s.onPrimaryContainer, s.primaryContainer),
        'secondaryContainer': (s.onSecondaryContainer, s.secondaryContainer),
        'tertiaryContainer': (s.onTertiaryContainer, s.tertiaryContainer),
        'errorContainer': (s.onErrorContainer, s.errorContainer),
        'inverseSurface': (s.onInverseSurface, s.inverseSurface),
        'badge (onError/error, default Badge colours)': (s.onError, s.error),
      };
      for (final e in pairs.entries) {
        test('${e.key} pair >= 4.5:1', () {
          expect(contrast(e.value.$1, e.value.$2), greaterThanOrEqualTo(4.5));
        });
      }

      test('container fills are the brief tokens', () {
        final c = light
            ? WarmPlayfulColorsLight.palettePeach
            : WarmPlayfulColorsDark.palettePeach;
        final sage = light
            ? WarmPlayfulColorsLight.paletteSage
            : WarmPlayfulColorsDark.paletteSage;
        expect(s.primaryContainer, c);
        expect(s.tertiaryContainer, sage);
        expect(s.secondaryContainer, s.surface);
        expect(
          s.errorContainer,
          light ? const Color(0xFFF9D9CF) : const Color(0xFF5A2E24),
        );
        expect(
          s.inverseSurface,
          light ? const Color(0xFF3D2E1F) : const Color(0xFFFAEBD7),
        );
        expect(
          s.onInverseSurface,
          light ? const Color(0xFFFAEBD7) : const Color(0xFF3D2E1F),
        );
      });

      test('snackBarTheme uses inverse colours, floating, readable action', () {
        final sb = theme.snackBarTheme;
        expect(sb.backgroundColor, s.inverseSurface);
        expect(sb.behavior, SnackBarBehavior.floating);
        expect(sb.contentTextStyle?.color, s.onInverseSurface);
        expect(sb.actionTextColor, isNotNull);
        expect(
          contrast(sb.actionTextColor!, s.inverseSurface),
          greaterThanOrEqualTo(4.5),
        );
        expect(sb.closeIconColor, s.onInverseSurface);
      });

      test('selected chip label is onAccent on accent', () {
        expect(theme.chipTheme.selectedColor, s.primary);
        expect(theme.chipTheme.secondaryLabelStyle?.color, wp.onAccent);
        expect(contrast(wp.onAccent, s.primary), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
