import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/presentation/request_inbox_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

const _request = JoinRequest(
  id: 'm1_guest1',
  mealId: 'm1',
  guestId: 'guest1',
  hostId: 'host1',
);

final _guest = AppUser(
  uid: 'guest1',
  dob: DateTime(1995, 1, 1),
  displayName: 'Amélie',
);

void main() {
  late MockUserRepository userRepository;

  setUp(() {
    userRepository = MockUserRepository();
    when(() => userRepository.watch('guest1'))
        .thenAnswer((_) => Stream.value(_guest));
  });

  Future<void> pumpInbox(
    WidgetTester tester, {
    required AsyncValue<List<JoinRequest>> hostInboxState,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          hostInboxProvider.overrideWith(
            (ref) => switch (hostInboxState) {
              AsyncData(:final value) => Stream.value(value),
              AsyncError(:final error) => Stream.error(error),
              _ => const Stream.empty(),
            },
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const RequestInboxScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('empty inbox shows the empty state', (tester) async {
    await pumpInbox(
      tester,
      hostInboxState: const AsyncData([]),
    );

    expect(find.text('No pending requests'), findsOneWidget);
  });

  testWidgets('one pending request shows the guest name + Approve + Deny', (
    tester,
  ) async {
    await pumpInbox(
      tester,
      hostInboxState: const AsyncData([_request]),
    );

    expect(find.textContaining('Amélie'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);
  });

  testWidgets('error state renders an error message', (tester) async {
    // A `StateError` (an `Error`, not an `Exception`) so Riverpod's default
    // provider-retry (`ProviderContainer.defaultRetry`) skips retrying and
    // the state lands on `AsyncError` deterministically, without waiting out
    // a real retry backoff timer in the test.
    await pumpInbox(
      tester,
      hostInboxState: AsyncError(StateError('boom'), StackTrace.empty),
    );

    expect(
      find.text('Something went wrong — please try again.'),
      findsOneWidget,
    );
  });
}
