import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/widgets/error_state.dart';
import 'package:not_eat_alone/core/design/widgets/skeleton_card.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/block_repository.dart';
import 'package:not_eat_alone/features/safety/presentation/blocked_people_screen.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';

class _MockBlocks extends Mock implements BlockRepository {}

class _MockUsers extends Mock implements UserRepository {}

class _MockAuth extends Mock implements AuthRepository {}

void main() {
  late _MockBlocks blocks;
  late _MockUsers users;
  late _MockAuth auth;
  late StreamController<Set<String>> ids;

  setUp(() {
    blocks = _MockBlocks();
    users = _MockUsers();
    auth = _MockAuth();
    ids = StreamController<Set<String>>();
    addTearDown(ids.close);
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'me'));
    when(() => blocks.watchBlockedByMe('me')).thenAnswer((_) => ids.stream);
    when(() => users.watch('a')).thenAnswer(
      (_) => Stream.value(const AppUser(uid: 'a', displayName: 'Bastien')),
    );
    when(() => users.watch('b')).thenAnswer(
      (_) => Stream.value(const AppUser(uid: 'b', displayName: 'Giulia')),
    );
    when(() => users.watch('gone')).thenAnswer((_) => Stream.value(null));
  });

  Future<void> pump(
    WidgetTester tester, {
    TextScaler scaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blockRepositoryProvider.overrideWithValue(blocks),
          userRepositoryProvider.overrideWithValue(users),
          authRepositoryProvider.overrideWithValue(auth),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'me')),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          ),
          home: const Scaffold(body: BlockedPeopleScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('loading: skeleton rows', (tester) async {
    await pump(tester);
    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.text('Blocked people'), findsOneWidget);
  });

  testWidgets('lists blocked people by name with an Unblock button', (
    tester,
  ) async {
    await pump(tester);
    ids.add({'a', 'b'});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Bastien'), findsOneWidget);
    expect(find.text('Giulia'), findsOneWidget);
    expect(find.text('Unblock'), findsNWidgets(2));
    expect(find.byType(SkeletonList), findsNothing);
  });

  testWidgets('each Unblock button is announced with the person\'s name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final gate = Completer<void>();
    when(() => blocks.unblock('me', 'a')).thenAnswer((_) => gate.future);
    await pump(tester);
    ids.add({'a', 'b'});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.bySemanticsLabel('Unblock Bastien'), findsOneWidget);
    expect(find.bySemanticsLabel('Unblock Giulia'), findsOneWidget);

    // In flight: one disabled node announcing the loading label, not both.
    await tester.tap(find.byKey(const Key('unblock_button_a')));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.bySemanticsLabel('Unblocking…'), findsWidgets);
    expect(find.bySemanticsLabel('Unblock Bastien'), findsNothing);
    gate.complete();
    await tester.pump(const Duration(milliseconds: 1));
    handle.dispose();
  });

  testWidgets('a profile that no longer exists is Unknown user', (
    tester,
  ) async {
    await pump(tester);
    ids.add({'gone'});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Unknown user'), findsOneWidget);
  });

  testWidgets('empty: explains and offers no action', (tester) async {
    await pump(tester);
    ids.add(<String>{});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text("You haven't blocked anyone"), findsOneWidget);
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('error shows Try again, which re-subscribes', (tester) async {
    await pump(tester);
    ids.addError(Exception('boom'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(ErrorState), findsOneWidget);
    clearInteractions(blocks);
    final second = StreamController<Set<String>>();
    addTearDown(second.close);
    when(() => blocks.watchBlockedByMe('me')).thenAnswer((_) => second.stream);
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 1));
    second.add({'a'});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    verify(() => blocks.watchBlockedByMe('me')).called(1);
    expect(find.text('Bastien'), findsOneWidget);
  });

  testWidgets('Unblock calls the repository once, the row leaves and a '
      'snackbar confirms', (tester) async {
    when(() => blocks.unblock('me', 'a')).thenAnswer((_) async {
      ids.add({'b'});
    });
    await pump(tester);
    ids.add({'a', 'b'});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byKey(const Key('unblock_button_a')));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    verify(() => blocks.unblock('me', 'a')).called(1);
    expect(find.text('Bastien'), findsNothing);
    expect(find.text('Giulia'), findsOneWidget);
    expect(find.text('Unblocked Bastien.'), findsOneWidget);
  });

  testWidgets('in flight: spinner only in that row', (tester) async {
    final gate = Completer<void>();
    when(() => blocks.unblock('me', 'a')).thenAnswer((_) => gate.future);
    await pump(tester);
    ids.add({'a', 'b'});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byKey(const Key('unblock_button_a')));
    await tester.pump(const Duration(milliseconds: 1));

    expect(
      find.descendant(
        of: find.byKey(const Key('blocked_row_a')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('blocked_row_b')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    // The other row stays tappable.
    await tester.tap(find.byKey(const Key('unblock_button_b')));
    verify(() => blocks.unblock('me', 'b')).called(1);
    gate.complete();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('failed unblock: snackbar and the button is usable again', (
    tester,
  ) async {
    when(
      () => blocks.unblock('me', 'a'),
    ).thenAnswer((_) async => throw Exception('nope'));
    await pump(tester);
    ids.add({'a'});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byKey(const Key('unblock_button_a')));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text("Couldn't unblock. Try again."), findsOneWidget);
    expect(find.text('Bastien'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('successful unblock whose row stays (lagging stream) stops '
      'spinning', (tester) async {
    when(() => blocks.unblock('me', 'a')).thenAnswer((_) async {});
    await pump(tester);
    ids.add({'a'});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byKey(const Key('unblock_button_a')));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Unblocked Bastien.'), findsOneWidget);
    expect(find.text('Bastien'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Unblock'), findsOneWidget);
  });

  testWidgets('no overflow at 320 px and 2.0x text', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, scaler: const TextScaler.linear(2));
    ids.add({'a', 'gone'});
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('unblock_button_a'))).height,
      greaterThanOrEqualTo(48),
    );
  });
}
