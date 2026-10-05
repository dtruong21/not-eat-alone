import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/features/matching/domain/meal_no_longer_open_exception.dart';
import 'package:not_eat_alone/features/matching/presentation/widgets/inbox_action_message.dart';

void main() {
  group('inboxActionMessage', () {
    test('approve success', () {
      expect(
        inboxActionMessage(InboxAction.approve, null),
        'Approved. You can chat now.',
      );
    });

    test('approve MealNoLongerOpenException', () {
      expect(
        inboxActionMessage(
          InboxAction.approve,
          MealNoLongerOpenException('m1'),
        ),
        'This meal is no longer open.',
      );
    });

    test('approve any other error', () {
      expect(
        inboxActionMessage(InboxAction.approve, StateError('boom')),
        "Couldn't approve this request. It may already have been handled.",
      );
    });

    test('deny success', () {
      expect(inboxActionMessage(InboxAction.deny, null), 'Request denied.');
    });

    test('deny any error', () {
      expect(
        inboxActionMessage(InboxAction.deny, StateError('boom')),
        "Couldn't deny this request. It may already have been handled.",
      );
    });

    test('deny with MealNoLongerOpenException uses the generic deny error',
        () {
      expect(
        inboxActionMessage(
          InboxAction.deny,
          MealNoLongerOpenException('m1'),
        ),
        "Couldn't deny this request. It may already have been handled.",
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
