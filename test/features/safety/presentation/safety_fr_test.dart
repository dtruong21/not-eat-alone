import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/auth/domain/entities/auth_user.dart';
import 'package:not_eat_alone/features/auth/domain/repositories/auth_repository.dart';
import 'package:not_eat_alone/features/safety/application/block_providers.dart';
import 'package:not_eat_alone/features/safety/application/report_providers.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/block_repository.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/report_repository.dart';
import 'package:not_eat_alone/features/safety/presentation/blocked_people_screen.dart';
import 'package:not_eat_alone/features/safety/presentation/report_sheet.dart';
import 'package:not_eat_alone/features/safety/presentation/safety_tips_screen.dart';
import 'package:not_eat_alone/features/safety/presentation/widgets/safety_actions.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/features/user/domain/entities/app_user.dart';
import 'package:not_eat_alone/features/user/domain/repositories/user_repository.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';

import '../../../helpers/load_app_fonts.dart';
import '../../../support/pump_localized.dart';

class _MockBlocks extends Mock implements BlockRepository {}

class _MockUsers extends Mock implements UserRepository {}

class _MockAuth extends Mock implements AuthRepository {}

class _MockReports extends Mock implements ReportRepository {}

const _longName = "Marie-Charlotte d'Aubigné-O'Brien de Castelnau-Montalembert";

/// French copy for safety (menu, block dialog, report sheet, blocked people,
/// tips screen): strings, ICU placeholders with apostrophe names, 320 px / 2x.
void main() {
  setUpAll(loadAppFonts);

  late _MockBlocks blocks;
  late _MockUsers users;
  late _MockAuth auth;
  late _MockReports reports;

  setUp(() {
    blocks = _MockBlocks();
    users = _MockUsers();
    auth = _MockAuth();
    reports = _MockReports();
    when(() => auth.currentUser).thenReturn(const AuthUser(uid: 'me'));
    when(() => blocks.block('me', 'them')).thenAnswer((_) async {});
    when(
      () => reports.report(
        reporterId: any(named: 'reporterId'),
        targetType: any(named: 'targetType'),
        targetId: any(named: 'targetId'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
  });

  void narrow(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Localised app with the providers ABOVE the navigator, so modal routes
  /// (dialogs, sheets) see them too.
  Widget scope(Widget child, {String? name, double textScale = 1}) =>
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'me')),
          ),
          blockRepositoryProvider.overrideWithValue(blocks),
          userRepositoryProvider.overrideWithValue(users),
          reportRepositoryProvider.overrideWithValue(reports),
          userDocProvider('them').overrideWith(
            (ref) => Stream.value(
              name == null ? null : AppUser(uid: 'them', displayName: name),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: c!,
          ),
          home: Scaffold(body: child),
        ),
      );

  group('safety menu and block dialog', () {
    Future<void> pumpMenu(
      WidgetTester tester, {
      String? name,
      bool isNarrow = false,
      double textScale = 1,
    }) async {
      if (isNarrow) narrow(tester);
      await tester.pumpWidget(
        scope(
          const Align(
            alignment: Alignment.topRight,
            child: SafetyActions(
              reportTargetType: 'user',
              reportTargetId: 'them',
              blockUid: 'them',
            ),
          ),
          name: name,
          textScale: textScale,
        ),
      );
      await tester.pump();
    }

    Future<void> choose(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(const Key('safety_actions_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('menu items are French', (tester) async {
      await pumpMenu(tester);
      await tester.tap(find.byKey(const Key('safety_actions_menu')));
      await tester.pumpAndSettle();
      expect(find.text('Signaler'), findsOneWidget);
      expect(find.text('Bloquer'), findsOneWidget);
      expect(find.text('Report'), findsNothing);
      expect(find.text('Block'), findsNothing);
    });

    testWidgets('block dialog names an apostrophe name', (tester) async {
      await pumpMenu(tester, name: "Jean d'Arc");
      await choose(tester, 'safety_actions_block_item');
      expect(find.text("Bloquer Jean d'Arc ?"), findsOneWidget);
      expect(
        find.text(
          'Tu ne verras plus cette personne sur Convyve, '
          'et elle ne te verra plus.',
        ),
        findsOneWidget,
      );
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Bloquer'), findsOneWidget);
      for (final en in ['Cancel', 'Block', "You won't see each other"]) {
        expect(find.textContaining(en), findsNothing);
      }
    });

    testWidgets('block dialog falls back to "cette personne"', (tester) async {
      await pumpMenu(tester);
      await choose(tester, 'safety_actions_block_item');
      expect(find.text('Bloquer cette personne ?'), findsOneWidget);
    });

    testWidgets('confirming shows the French snackbar', (tester) async {
      await pumpMenu(tester, name: 'Bastien');
      await choose(tester, 'safety_actions_block_item');
      await tester.tap(find.byKey(const Key('safety_actions_block_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Personne bloquée.'), findsOneWidget);
      expect(find.text('Blocked.'), findsNothing);
    });

    testWidgets('a failed block shows the French error', (tester) async {
      when(() => blocks.block('me', 'them')).thenThrow(StateError('boom'));
      await pumpMenu(tester, name: 'Bastien');
      await choose(tester, 'safety_actions_block_item');
      await tester.tap(find.byKey(const Key('safety_actions_block_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Impossible de bloquer. Réessaie.'), findsOneWidget);
    });

    testWidgets('no overflow: long name dialog at 320 px and 2.0x', (
      tester,
    ) async {
      await pumpMenu(tester, name: _longName, isNarrow: true, textScale: 2);
      await choose(tester, 'safety_actions_block_item');
      expect(find.text('Bloquer $_longName ?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('report sheet', () {
    Future<void> openSheet(
      WidgetTester tester, {
      String targetType = 'user',
      String? name,
      bool isNarrow = false,
      double textScale = 1,
    }) async {
      if (isNarrow) narrow(tester);
      await tester.pumpWidget(
        scope(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showReportSheet(
                context,
                targetType: targetType,
                targetId: 'them',
                targetName: name,
              ),
              child: const Text('open'),
            ),
          ),
          textScale: textScale,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('title, reasons, hint and Submit are French', (tester) async {
      await openSheet(tester, name: "Jean d'Arc");
      expect(find.text("Signaler Jean d'Arc"), findsOneWidget);
      for (final fr in [
        'Contenu inapproprié',
        'Spam',
        'Harcèlement',
        'Faux profil',
        'Autre',
        'Envoyer',
      ]) {
        expect(find.text(fr), findsOneWidget);
      }
      expect(find.text('Ajoute une note (facultatif)'), findsOneWidget);
      for (final en in [
        'Inappropriate content',
        'Harassment',
        'Fake profile',
        'Other',
        'Submit',
        'Add a note (optional)',
      ]) {
        expect(find.text(en), findsNothing);
      }
    });

    testWidgets('meal and unnamed titles', (tester) async {
      await openSheet(tester, targetType: 'meal');
      expect(find.text('Signaler ce repas'), findsOneWidget);
    });

    testWidgets('submitting sends the English literal, thanks in French', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('report_reason_chip_harassment')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report_submit_button')));
      await tester.pumpAndSettle();
      verify(
        () => reports.report(
          reporterId: 'me',
          targetType: 'user',
          targetId: 'them',
          reason: 'harassment',
        ),
      ).called(1);
      expect(find.text('Merci, on va examiner ça.'), findsOneWidget);
    });

    testWidgets('a failed report shows the French error', (tester) async {
      when(
        () => reports.report(
          reporterId: any(named: 'reporterId'),
          targetType: any(named: 'targetType'),
          targetId: any(named: 'targetId'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(StateError('boom'));
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('report_reason_chip_spam')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report_submit_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Impossible d’envoyer ton signalement. Réessaie.'),
        findsOneWidget,
      );
    });

    testWidgets('no overflow: every reason, long name, 320 px and 2.0x', (
      tester,
    ) async {
      await openSheet(tester, name: _longName, isNarrow: true, textScale: 2);
      expect(find.text('Signaler $_longName'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('blocked people', () {
    late StreamController<Set<String>> ids;

    setUp(() {
      ids = StreamController<Set<String>>();
      addTearDown(ids.close);
      when(() => blocks.watchBlockedByMe('me')).thenAnswer((_) => ids.stream);
      when(() => users.watch('a')).thenAnswer(
        (_) => Stream.value(const AppUser(uid: 'a', displayName: "D'Artagnan")),
      );
      when(() => users.watch('gone')).thenAnswer((_) => Stream.value(null));
    });

    Future<void> pumpBlocked(
      WidgetTester tester, {
      Set<String>? blocked,
      bool isNarrow = false,
      double textScale = 1,
    }) async {
      if (isNarrow) narrow(tester);
      await tester.pumpWidget(
        scope(const BlockedPeopleScreen(), textScale: textScale),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      if (blocked != null) ids.add(blocked);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets('rows, fallback name and Unblock semantics are French', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBlocked(tester, blocked: {'a', 'gone'});
      expect(find.text('Personnes bloquées'), findsOneWidget);
      expect(find.text('Débloquer'), findsNWidgets(2));
      expect(find.text('Utilisateur inconnu'), findsOneWidget);
      expect(find.bySemanticsLabel("Débloquer D'Artagnan"), findsOneWidget);
      expect(find.text('Unblock'), findsNothing);
      expect(find.text('Blocked people'), findsNothing);
      semantics.dispose();
    });

    testWidgets('empty state is French', (tester) async {
      await pumpBlocked(tester, blocked: <String>{});
      expect(find.text('Tu n’as bloqué personne'), findsOneWidget);
      expect(
        find.text(
          'Les personnes que tu bloques sont masquées de tes repas '
          'et de tes discussions.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('unblock snackbars are French (apostrophe name)', (
      tester,
    ) async {
      when(() => blocks.unblock('me', 'a')).thenAnswer((_) async {});
      await pumpBlocked(tester, blocked: {'a'});
      await tester.tap(find.byKey(const Key('unblock_button_a')));
      await tester.pump();
      await tester.pump();
      expect(find.text("Tu as débloqué D'Artagnan."), findsOneWidget);

      when(() => blocks.unblock('me', 'a')).thenThrow(StateError('boom'));
      await tester.tap(find.byKey(const Key('unblock_button_a')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Impossible de débloquer. Réessaie.'), findsOneWidget);
    });

    testWidgets('no overflow at 320 px and 2.0x', (tester) async {
      when(() => users.watch('a')).thenAnswer(
        (_) => Stream.value(const AppUser(uid: 'a', displayName: _longName)),
      );
      await pumpBlocked(tester, blocked: {'a'}, isNarrow: true, textScale: 2);
      expect(find.text(_longName), findsOneWidget);
      expect(find.text('Débloquer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('safety tips screen title and heading are French', (
    tester,
  ) async {
    narrow(tester);
    await pumpLocalized(tester, const SafetyTipsScreen(), textScale: 2);
    expect(find.text('Conseils de sécurité'), findsOneWidget);
    expect(find.text('Meeting up? Stay safe'), findsNothing);
    expect(find.text('Safety tips'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
