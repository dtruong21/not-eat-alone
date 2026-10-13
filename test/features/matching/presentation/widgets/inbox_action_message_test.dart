import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/matching/presentation/widgets/inbox_action_message.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations_en.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations_fr.dart';

void main() {
  // The mapping returns a typed outcome; the text comes from l10n. Each row
  // asserts the outcome AND the (unchanged) English wording.
  final en = AppLocalizationsEn();
  final fr = AppLocalizationsFr();
  String english(InboxAction a, Object? e) =>
      localizeInboxOutcome(en, inboxOutcome(a, e));

  group('inboxOutcome', () {
    test('approve success', () {
      expect(inboxOutcome(InboxAction.approve, null), InboxOutcome.approved);
      expect(english(InboxAction.approve, null), 'Approved. You can chat now.');
    });

    test('approve MealNoLongerOpenException', () {
      final error = MealNoLongerOpenException('m1');
      expect(
        inboxOutcome(InboxAction.approve, error),
        InboxOutcome.mealNoLongerOpen,
      );
      expect(
        english(InboxAction.approve, error),
        'This meal is no longer open.',
      );
    });

    test('approve any other error', () {
      final error = StateError('boom');
      expect(
        inboxOutcome(InboxAction.approve, error),
        InboxOutcome.approveFailed,
      );
      expect(
        english(InboxAction.approve, error),
        "Couldn't approve this request. It may already have been handled.",
      );
    });

    test('deny success', () {
      expect(inboxOutcome(InboxAction.deny, null), InboxOutcome.denied);
      expect(english(InboxAction.deny, null), 'Request denied.');
    });

    test('deny any error', () {
      final error = StateError('boom');
      expect(inboxOutcome(InboxAction.deny, error), InboxOutcome.denyFailed);
      expect(
        english(InboxAction.deny, error),
        "Couldn't deny this request. It may already have been handled.",
      );
    });

    test('deny with MealNoLongerOpenException uses the generic deny error', () {
      expect(
        inboxOutcome(InboxAction.deny, MealNoLongerOpenException('m1')),
        InboxOutcome.denyFailed,
      );
    });
  });

  group('localizeInboxOutcome (French)', () {
    test('every outcome has a French text, none equal to the English', () {
      for (final outcome in InboxOutcome.values) {
        final french = localizeInboxOutcome(fr, outcome);
        expect(french, isNotEmpty);
        expect(french, isNot(localizeInboxOutcome(en, outcome)));
      }
      expect(
        localizeInboxOutcome(fr, InboxOutcome.approved),
        'Demande acceptée. Tu peux discuter maintenant.',
      );
      expect(
        localizeInboxOutcome(fr, InboxOutcome.denyFailed),
        'Impossible de refuser cette demande. '
        'Elle a peut-être déjà été traitée.',
      );
    });
  });

  group('inboxActionHasChatAction', () {
    test('true only for approve success', () {
      expect(inboxActionHasChatAction(InboxAction.approve, null), isTrue);
    });

    test('false for approve failures', () {
      expect(
        inboxActionHasChatAction(
          InboxAction.approve,
          MealNoLongerOpenException('m1'),
        ),
        isFalse,
      );
      expect(
        inboxActionHasChatAction(InboxAction.approve, StateError('x')),
        isFalse,
      );
    });

    test('false for deny, success or failure', () {
      expect(inboxActionHasChatAction(InboxAction.deny, null), isFalse);
      expect(
        inboxActionHasChatAction(InboxAction.deny, StateError('x')),
        isFalse,
      );
    });
  });
}
