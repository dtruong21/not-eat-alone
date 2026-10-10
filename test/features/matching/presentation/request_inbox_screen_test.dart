import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/features/matching/application/host_inbox_provider.dart';
import 'package:not_eat_alone/features/matching/application/request_meal_provider.dart';
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
    when(
      () => userRepository.watch('guest1'),
    ).thenAnswer((_) => Stream.value(_guest));
  });

  Future<void> pumpInbox(
    WidgetTester tester, {
    required AsyncValue<List<JoinRequest>> hostInboxState,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          requestMealProvider.overrideWith((ref, mealId) async => null),
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
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('empty inbox shows the empty state', (tester) async {
    await pumpInbox(tester, hostInboxState: const AsyncData([]));

    expect(find.text('No pending requests'), findsOneWidget);
  });

  testWidgets('one pending request shows the guest name + Approve + Deny', (
    tester,
  ) async {
    await pumpInbox(tester, hostInboxState: const AsyncData([_request]));

    expect(find.textContaining('Amélie'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);
  });

  testWidgets('loading shows a skeleton list, not a spinner', (tester) async {
    await pumpInbox(tester, hostInboxState: const AsyncLoading());

    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error state shows ErrorState with Try again', (tester) async {
    // A `StateError` (an `Error`, not an `Exception`) so Riverpod's default
    // provider-retry (`ProviderContainer.defaultRetry`) skips retrying and
    // the state lands on `AsyncError` deterministically, without waiting out
    // a real retry backoff timer in the test.
    await pumpInbox(
      tester,
      hostInboxState: AsyncError(StateError('boom'), StackTrace.empty),
    );

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Try again re-fetches: fails once, then shows the request', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(userRepository),
          requestMealProvider.overrideWith((ref, mealId) async => null),
          hostInboxProvider.overrideWith(
            (ref) => ++calls == 1
                ? Stream<List<JoinRequest>>.error(StateError('boom'))
                : Stream.value(const [_request]),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const RequestInboxScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(ErrorState), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(calls, 2);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.textContaining('Amélie'), findsOneWidget);
  });
}
