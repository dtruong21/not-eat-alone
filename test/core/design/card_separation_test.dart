import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import '../../support/contrast.dart';

/// Card builds that are not `Card` widgets (Material/Container surfaces) must
/// carry the elevation + shadow themselves; CardTheme does not reach them.
const _materialCardFiles = <String>[
  'lib/features/meal/presentation/discovery_screen.dart',
  'lib/features/chat/presentation/widgets/chat_list_tile.dart',
  'lib/features/meal/presentation/restaurant_search_screen.dart',
  'lib/features/meal/presentation/meal_detail_screen.dart',
  'lib/features/meal/presentation/create_meal_screen.dart',
  'lib/features/matching/presentation/widgets/request_inbox_tile.dart',
];

/// `Card` widgets: must inherit the CardTheme shadow (no `elevation: 0`).
const _cardWidgetFiles = <String>[
  'lib/features/rating/presentation/widgets/post_meal_card.dart',
  'lib/features/meal/presentation/widgets/paris_notice.dart',
];

void main() {
  // Light surface vs bg is ~1.15:1 (deeper peach after Task 1), so the soft
  // shadow does the separating work. Recorded here, not asserted.
  for (final b in Brightness.values) {
    group('card separation ($b)', () {
      final theme = buildTheme(b);
      final wp = theme.extension<WarmPlayfulExtensions>()!;

      test('cardTheme carries elevation, shadow, no tint', () {
        final c = theme.cardTheme;
        expect(c.elevation, WarmPlayfulElevation.card);
        expect(c.shadowColor, wp.shadow);
        expect(c.surfaceTintColor, Colors.transparent);
      });
    });
  }

  test('Material/Container card builds set elevation and shadow', () {
    for (final path in _materialCardFiles) {
      final src = File(path).readAsStringSync();
      expect(
        src,
        contains('elevation: WarmPlayfulElevation.card'),
        reason: path,
      );
      expect(src, contains('shadowColor: context.wp.shadow'), reason: path);
      expect(
        src,
        contains('surfaceTintColor: Colors.transparent'),
        reason: path,
      );
    }
  });

  test('Card widgets do not opt out of the CardTheme shadow', () {
    for (final path in _cardWidgetFiles) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('elevation: 0')),
        reason: path,
      );
    }
  });

  test('light border token stays visible on the deeper surface (>= 1.1:1)', () {
    expect(
      contrast(WarmPlayfulColorsLight.border, WarmPlayfulColorsLight.surface),
      greaterThanOrEqualTo(1.1),
    );
  });
}
