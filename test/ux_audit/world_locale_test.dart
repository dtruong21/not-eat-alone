// The capture harness's seeded world has English and French free text. This
// checks the two stay parallel (same shape, different words). Dev tooling:
// `fvm flutter test test/ux_audit/world_locale_test.dart`.
import 'package:flutter_test/flutter_test.dart';

import '../../ux_audit/support/world.dart';

void main() {
  test('main chat: same count, senders and timing; French text differs', () {
    final en = uxMainChat('en');
    final fr = uxMainChat('fr');
    expect(fr.length, en.length);
    expect(en.length, 15);
    for (var i = 0; i < en.length; i++) {
      expect(fr[i].mine, en[i].mine, reason: 'sender of message $i');
      expect(fr[i].minutesAgo, en[i].minutesAgo, reason: 'time of $i');
      expect(fr[i].text, isNot(en[i].text), reason: 'text of $i');
    }
  });

  test('past chat: same count and senders; French text differs', () {
    final en = uxPastChat('en');
    final fr = uxPastChat('fr');
    expect(fr.length, en.length);
    for (var i = 0; i < en.length; i++) {
      expect(fr[i].mine, en[i].mine);
      expect(fr[i].text, isNot(en[i].text));
    }
  });

  test('notes, bios and the rating comment: same keys, French differs', () {
    for (final pair in [
      (uxNotes('en'), uxNotes('fr')),
      (uxBios('en'), uxBios('fr')),
    ]) {
      expect(pair.$2.keys.toSet(), pair.$1.keys.toSet());
      for (final k in pair.$1.keys) {
        expect(pair.$2[k], isNot(pair.$1[k]), reason: k);
      }
    }
    expect(uxRatingComment('fr'), isNot(uxRatingComment('en')));
  });

  test('French text: typographic apostrophes, NBSP before ! ? : ;', () {
    final fr = <String>[
      ...uxMainChat('fr').map((m) => m.text),
      ...uxPastChat('fr').map((m) => m.text),
      ...uxNotes('fr').values,
      ...uxBios('fr').values,
      uxRatingComment('fr'),
    ];
    final unspaced = RegExp('(?<! )[!?:;]');
    for (final t in fr) {
      expect(t, isNot(contains("'")), reason: t);
      expect(unspaced.hasMatch(t), isFalse, reason: t);
    }
  });

  test('an unknown locale is refused', () {
    expect(() => uxMainChat('de'), throwsArgumentError);
  });
}
