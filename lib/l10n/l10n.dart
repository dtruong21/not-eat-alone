/// `context.l10n`: the generated [AppLocalizations] with an English fallback.
library;

import 'package:flutter/widgets.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations.dart';
import 'package:not_eat_alone/l10n/generated/app_localizations_en.dart';

export 'package:not_eat_alone/l10n/generated/app_localizations.dart';

/// Localised strings for the widget tree.
extension L10nContext on BuildContext {
  /// The active [AppLocalizations]. Falls back to English when the tree has no
  /// localisation delegates (bare `MaterialApp` in widget tests).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn();
}
