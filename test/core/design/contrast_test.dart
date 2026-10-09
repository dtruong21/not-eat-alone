import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final brightness in Brightness.values) {
    group('contrast ($brightness)', () {
      final theme = buildTheme(brightness);
      final scheme = theme.colorScheme;
      final wp = theme.extension<WarmPlayfulExtensions>()!;
      final bg = theme.scaffoldBackgroundColor;

      test('body text on page and cards >= 4.5', () {
        expect(contrast(scheme.onSurface, bg), greaterThanOrEqualTo(4.5));
        expect(
          contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      });
      test('secondary text (wp.muted, onSurfaceVariant) on page and cards '
          '>= 4.5', () {
        expect(contrast(wp.muted, bg), greaterThanOrEqualTo(4.5));
        expect(contrast(wp.muted, scheme.surface), greaterThanOrEqualTo(4.5));
        expect(scheme.onSurfaceVariant, wp.muted);
      });
      test('error text on page and cards >= 4.5', () {
        expect(scheme.error, wp.dangerText);
        expect(contrast(scheme.error, bg), greaterThanOrEqualTo(4.5));
        expect(
          contrast(scheme.error, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      });
      test('label on primary (coral) >= 4.5, onError on error >= 4.5', () {
        expect(
          contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onError, scheme.error),
          greaterThanOrEqualTo(4.5),
        );
      });
      test('muted icons/borders used as UI parts >= 3.0 against bg', () {
        expect(contrast(wp.muted, bg), greaterThanOrEqualTo(3));
      });
    });
  }

  test('light card vs page stays visibly separated by token choice', () {
    // Documented, not a WCAG rule: the deeper surface plus shadow (Task 6).
    final t = buildTheme(Brightness.light);
    expect(t.colorScheme.surface, const Color(0xFFFBE8D8));
  });
}
