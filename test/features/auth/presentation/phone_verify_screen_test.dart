import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/auth/presentation/phone_verify_args.dart';
import 'package:not_eat_alone/features/auth/presentation/phone_verify_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _args = PhoneVerifyArgs(
  verificationId: 'verif-1',
  phoneE164: '+33612345678',
);
const _wrongCode = "That code didn't work. Check it or resend.";
const _generic = 'Something went wrong — please try again.';
final Finder _codeField = find.byKey(const Key('phone_verify_code_field'));

void main() {
  late MockAuthRepository repo;
  late GoRouter router;

  setUp(() => repo = MockAuthRepository());

  /// Pumps a '/' page and pushes the code screen on top of it (as the real
  /// flow does), so the AppBar has a back button.
  Future<void> pumpScreen(
    WidgetTester tester, {
    double width = 800,
    double height = 900,
    double textScale = 1,
  }) async {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('sign in page')),
        ),
        GoRoute(
          path: '/code',
          builder: (_, _) => const PhoneVerifyScreen(args: _args),
        ),
      ],
    );
    tester.view
      ..physicalSize = Size(width, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push('/code'));
    await tester.pumpAndSettle();
  }

  // Tears the screen down so its countdown timer does not outlive the test.
  Future<void> leave(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  void stubConfirm([Future<void> Function()? body]) {
    when(
      () => repo.confirmSmsCode(
        verificationId: any(named: 'verificationId'),
        smsCode: any(named: 'smsCode'),
      ),
    ).thenAnswer((_) => body?.call() ?? Future<void>.value());
  }

  void stubVerifyPhone(
    void Function(void Function(String) codeSent, void Function(String) onError)
    body,
  ) {
    when(
      () => repo.verifyPhone(
        phoneE164: any(named: 'phoneE164'),
        codeSent: any(named: 'codeSent'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((i) async {
      body(
        i.namedArguments[#codeSent] as void Function(String),
        i.namedArguments[#onError] as void Function(String),
      );
    });
  }

  void verifyConfirmCalls(String id, String code, int times) => verify(
    () => repo.confirmSmsCode(verificationId: id, smsCode: code),
  ).called(times);

  group('layout', () {
    testWidgets('at 320 px and 2.0x text with the keyboard up the screen '
        'scrolls and Verify is reachable', (tester) async {
      await pumpScreen(tester, width: 320, height: 568, textScale: 2);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final verify = find.text('Verify');
      await tester.ensureVisible(verify);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(verify).dy,
        lessThanOrEqualTo(568 - 260),
        reason: 'Verify must sit above the keyboard',
      );
      await leave(tester);
    });
  });

  group('keyboard', () {
    // 320 x 568 with a 300 px keyboard leaves 268 px. At 2.0x text the error
    // alone takes most of that, so Verify can only be asserted at 1.0x (it is
    // not needed there: the 6th digit submits).
    for (final (scale, verifyAbove) in [(1.0, true), (2.0, false)]) {
      testWidgets('after a wrong code at ${scale}x text the error '
          '${verifyAbove ? 'and Verify stay' : 'stays'} above the keyboard', (
        tester,
      ) async {
        stubConfirm(() => Future.error(const InvalidSmsCodeException()));
        await pumpScreen(tester, width: 320, height: 568, textScale: scale);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();

        await tester.enterText(_codeField, '123456');
        await tester.pumpAndSettle();

        const visibleBottom = 568 - 300;
        expect(find.text(_wrongCode), findsOneWidget);
        expect(
          tester.getBottomLeft(find.text(_wrongCode)).dy,
          lessThanOrEqualTo(visibleBottom),
        );
        if (verifyAbove) {
          expect(
            tester.getBottomLeft(find.text('Verify')).dy,
            lessThanOrEqualTo(visibleBottom),
          );
        }
        await leave(tester);
      });
    }
  });

  group('header', () {
    testWidgets('has a back button, the number being texted, and a Change '
        'button that pops', (tester) async {
      await pumpScreen(tester);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('Sent to +33 6 12 34 56 78'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Change'));
      await tester.pumpAndSettle();
      expect(find.text('sign in page'), findsOneWidget);
      expect(find.byType(PhoneVerifyScreen), findsNothing);
    });

    testWidgets('the back button pops too', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('sign in page'), findsOneWidget);
    });
  });

  group('verify', () {
    testWidgets('the 6th digit submits once, also when the keyboard action '
        'fires too', (tester) async {
      final done = Completer<void>();
      stubConfirm(() => done.future);
      await pumpScreen(tester);

      await tester.enterText(_codeField, '12345');
      await tester.pump();
      verifyNever(
        () => repo.confirmSmsCode(
          verificationId: any(named: 'verificationId'),
          smsCode: any(named: 'smsCode'),
        ),
      );

      await tester.enterText(_codeField, '123456');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      verifyConfirmCalls('verif-1', '123456', 1);
      done.complete();
      await tester.pump();
      await leave(tester);
    });

    testWidgets('tapping Verify submits the typed code', (tester) async {
      stubConfirm();
      await pumpScreen(tester);
      await tester.enterText(_codeField, '1234');
      await tester.tap(find.text('Verify'));
      await tester.pump();
      verifyConfirmCalls('verif-1', '1234', 1);
      await leave(tester);
    });

    testWidgets('the keyboard action is Done', (tester) async {
      await pumpScreen(tester);
      expect(
        tester.widget<TextField>(_codeField).textInputAction,
        TextInputAction.done,
      );
      await leave(tester);
    });

    testWidgets('while verifying the label is Verifying… and the button '
        'keeps its size', (tester) async {
      final done = Completer<void>();
      stubConfirm(() => done.future);
      await pumpScreen(tester);
      final before = tester.getSize(find.byType(FilledButton));

      await tester.enterText(_codeField, '123456');
      await tester.pump();
      expect(find.text('Verifying…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)), before);

      done.complete();
      await tester.pump();
      await tester.pump();
      // Success: the router leaves the screen. Until it does, Verify must not
      // become live again with the used code still in the field.
      expect(find.text('Verifying…'), findsOneWidget);
      await tester.tap(find.text('Verifying…'), warnIfMissed: false);
      await tester.pump();
      verifyConfirmCalls('verif-1', '123456', 1);
      await leave(tester);
    });

    testWidgets('a wrong code shows the specific message on the field in '
        'dangerText, clears the field and refocuses it', (tester) async {
      final done = Completer<void>();
      stubConfirm(() => done.future);
      await pumpScreen(tester);

      await tester.enterText(_codeField, '123456');
      await tester.pump();
      // Drop focus while the request is in flight, so the assertion below
      // only passes if the screen refocuses the field itself.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
      done.completeError(const InvalidSmsCodeException());
      await tester.pump();
      await tester.pump();

      final field = tester.widget<TextField>(_codeField);
      expect(field.decoration?.errorText, _wrongCode);
      expect(
        field.decoration?.errorStyle?.color,
        WarmPlayfulColorsLight.dangerText,
      );
      expect(field.controller?.text, isEmpty);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(find.text(_generic), findsNothing);

      // Typing again clears the message and a second code can be submitted.
      await tester.enterText(_codeField, '1');
      await tester.pump();
      expect(
        tester.widget<TextField>(_codeField).decoration?.errorText,
        isNull,
      );
      await leave(tester);
    });

    testWidgets('any other error shows the generic sentence in a live region '
        'and keeps the typed code', (tester) async {
      final handle = tester.ensureSemantics();
      stubConfirm(() async => throw Exception('network-request-failed'));
      await pumpScreen(tester);

      await tester.enterText(_codeField, '123456');
      await tester.pump();
      await tester.pump();

      final field = tester.widget<TextField>(_codeField);
      expect(field.decoration?.errorText, isNull);
      expect(field.controller?.text, '123456');
      expect(find.text(_wrongCode), findsNothing);
      expect(
        tester.getSemantics(find.text(_generic)),
        matchesSemantics(label: _generic, isLiveRegion: true),
      );
      // Verify is usable again for a retry.
      await tester.tap(find.text('Verify'));
      await tester.pump();
      verifyConfirmCalls('verif-1', '123456', 2);
      handle.dispose();
      await leave(tester);
    });

    testWidgets('Change has a descriptive label and the length counter is '
        'not announced', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);
      expect(find.bySemanticsLabel('Change phone number'), findsOneWidget);
      expect(
        tester.widget<TextField>(_codeField).decoration?.counterText,
        isEmpty,
      );
      handle.dispose();
      await leave(tester);
    });
  });

  group('resend', () {
    testWidgets('is disabled and counts down 30 s, then enabled', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('Resend code in 30 s'), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text('Resend code in 30 s'),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Resend code in 24 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 24));
      expect(find.text('Resend code'), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text('Resend code'),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      await leave(tester);
    });

    testWidgets('re-sends to the same number, swaps the verification id, '
        'confirms, and restarts the countdown', (tester) async {
      late void Function(String) fire;
      stubVerifyPhone((codeSent, _) => fire = codeSent);
      stubConfirm();
      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 30));

      await tester.tap(find.text('Resend code'));
      await tester.pump();
      verify(
        () => repo.verifyPhone(
          phoneE164: '+33612345678',
          codeSent: any(named: 'codeSent'),
          onError: any(named: 'onError'),
        ),
      ).called(1);

      fire('verif-2');
      await tester.pump();
      expect(find.text('Code sent again'), findsOneWidget);
      expect(find.text('Resend code in 30 s'), findsOneWidget);

      await tester.enterText(_codeField, '654321');
      await tester.pump();
      verifyConfirmCalls('verif-2', '654321', 1);
      await leave(tester);
    });

    testWidgets('a failed re-send shows the generic error in a live region '
        'and leaves Resend available', (tester) async {
      final handle = tester.ensureSemantics();
      late void Function(String) fail;
      stubVerifyPhone((_, onError) => fail = onError);
      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 30));

      await tester.tap(find.text('Resend code'));
      await tester.pump();
      fail('boom');
      await tester.pump();

      expect(
        tester.getSemantics(find.text(_generic)),
        matchesSemantics(label: _generic, isLiveRegion: true),
      );
      expect(find.text('Code sent again'), findsNothing);
      expect(find.text('Resend code'), findsOneWidget);
      handle.dispose();
      await leave(tester);
    });

    testWidgets('a re-send that never answers gives up after 60 s, and its '
        'late codeSent is ignored', (tester) async {
      late void Function(String) fire;
      stubVerifyPhone((codeSent, _) => fire = codeSent);
      await pumpScreen(tester);
      await tester.pump(const Duration(seconds: 30));

      await tester.tap(find.text('Resend code'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Sending code…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Sending code…'), findsNothing);
      expect(find.text('Resend code'), findsOneWidget);
      expect(find.text(_generic), findsOneWidget);

      fire('stale');
      await tester.pump();
      expect(find.text('Code sent again'), findsNothing);
      await leave(tester);
    });

    testWidgets('the countdown follows the clock, not the tick count (the '
        'app may be suspended while the user reads the SMS)', (tester) async {
      await pumpScreen(tester);
      (tester.binding as AutomatedTestWidgetsFlutterBinding).elapseBlocking(
        const Duration(seconds: 20),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend code in 9 s'), findsOneWidget);
      await leave(tester);
    });
  });
}
