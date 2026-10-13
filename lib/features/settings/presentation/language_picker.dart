/// The Settings language picker: System default / English / Français.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/core/locale/locale_controller.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

/// Native language names: the same in every language, never translated.
const _nativeNames = {'en': 'English', 'fr': 'Français'};

/// The row subtitle for the current choice (null = follow the device).
String languageLabel(BuildContext context, Locale? locale) =>
    _nativeNames[locale?.languageCode] ?? context.l10n.settingsLanguageSystem;

/// Opens the picker; choosing an option applies it at once and closes it.
Future<void> showLanguagePicker(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _LanguageDialog());

class _LanguageDialog extends ConsumerWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeControllerProvider);
    final options = <String?, String>{
      null: context.l10n.settingsLanguageSystem,
      ..._nativeNames,
    };
    return AlertDialog(
      key: const Key('language_picker'),
      title: Text(context.l10n.settingsLanguageTitle),
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        child: RadioGroup<String?>(
          groupValue: current?.languageCode,
          onChanged: (code) {
            unawaited(
              ref
                  .read(localeControllerProvider.notifier)
                  .setLocale(code == null ? null : Locale(code)),
            );
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options.entries)
                _tile(context, o, selected: o.key == current?.languageCode),
            ],
          ),
        ),
      ),
    );
  }

  /// A radio only reports a change, so tapping the option that is already
  /// selected would do nothing: close the dialog for that one instead.
  Widget _tile(
    BuildContext context,
    MapEntry<String?, String> o, {
    required bool selected,
  }) {
    final tile = RadioListTile<String?>(
      key: Key('language_option_${o.key ?? 'system'}'),
      value: o.key,
      selected: selected,
      title: Text(o.value),
    );
    if (!selected) return tile;
    return Stack(
      children: [
        tile,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
