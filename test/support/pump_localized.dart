import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';

/// Pumps [child] in a localised `MaterialApp` (French by default).
Future<void> pumpLocalized(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('fr'),
  Size? size,
  double? textScale,
  Brightness brightness = Brightness.light,
}) async {
  Widget home = Scaffold(body: child);
  if (size != null || textScale != null) {
    home = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: textScale == null ? null : TextScaler.linear(textScale),
        ),
        child: home,
      ),
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(brightness),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}
