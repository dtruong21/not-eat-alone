/// Pure date/time formatting shared across features.
///
/// Locale-aware through `intl` (24-hour clock, abbreviated weekday/month);
/// English is the default so callers without a locale keep today's output.
/// "Today"/"Tomorrow"/"Yesterday" come from a small table below because this
/// util stays context-free (no `AppLocalizations`). `main_common.dart` calls
/// `initializeDateFormatting` for `en` and `fr`; tests must do the same.
library;

import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

const Map<String, ({String today, String tomorrow, String yesterday})>
_relativeWords = {
  'en': (today: 'Today', tomorrow: 'Tomorrow', yesterday: 'Yesterday'),
  'fr': (today: 'Aujourd’hui', tomorrow: 'Demain', yesterday: 'Hier'),
};

/// The language [locale] is formatted in; unsupported ones fall back to
/// English.
String _lang(Locale locale) => _relativeWords.containsKey(locale.languageCode)
    ? locale.languageCode
    : 'en';

String _clock(DateTime local, Locale locale) =>
    DateFormat.Hm(_lang(locale)).format(local);

/// "Sat 10 Oct", or "Sat 10 Oct 2027" when [local] is not in [today]'s year.
String _weekdayDate(DateTime local, DateTime today, Locale locale) =>
    DateFormat(
      local.year == today.year ? 'EEE d MMM' : 'EEE d MMM y',
      _lang(locale),
    ).format(local);

/// Formats [value] for a meal: "Today 20:30", "Tomorrow 12:30", otherwise
/// "Sat 10 Oct, 20:00" (with the year, "Sat 10 Oct 2027, 20:00", only when it
/// differs from [now]'s year). Past dates use the absolute form.
///
/// Always renders in the viewer's local time: meal times come out of the data
/// layer as UTC `DateTime`s, and a local `DateTime`'s `toLocal()` is itself,
/// so both kinds are handled. "Today"/"Tomorrow" compare local calendar days;
/// [now] defaults to `DateTime.now()` and exists for tests.
String formatMealDateTime(
  DateTime value, {
  DateTime? now,
  Locale locale = const Locale('en'),
}) {
  final local = value.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  // UTC midnights so a DST change never makes a day 23 or 25 hours long.
  final dayDelta = DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  final words = _relativeWords[_lang(locale)]!;
  final clock = _clock(local, locale);
  if (dayDelta == 0) return '${words.today} $clock';
  if (dayDelta == 1) return '${words.tomorrow} $clock';
  return '${_weekdayDate(local, today, locale)}, $clock';
}

/// Labels the calendar day of [value] for a chat's day separator: "Today",
/// "Yesterday", otherwise "Mon 5 Oct" (with the year, "Wed 31 Dec 2025", only
/// when it differs from [now]'s year).
///
/// Local calendar days, compared on UTC midnights so a DST change never makes
/// a day 23 or 25 hours long. A day at or after [now]'s (clock skew on a
/// message that was just sent) reads "Today". [now] defaults to
/// `DateTime.now()` and exists for tests.
String formatDayLabel(
  DateTime value, {
  DateTime? now,
  Locale locale = const Locale('en'),
}) {
  final local = value.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final dayDelta = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
  final words = _relativeWords[_lang(locale)]!;
  if (dayDelta <= 0) return words.today;
  if (dayDelta == 1) return words.yesterday;
  return _weekdayDate(local, today, locale);
}

/// Formats [value] as a 24-hour clock time, e.g. "20:30", in the viewer's
/// local time (chat timestamps come out of the data layer as UTC
/// `DateTime`s; a local value's `toLocal()` is itself).
String formatClockTime(DateTime value, {Locale locale = const Locale('en')}) =>
    _clock(value.toLocal(), locale);

/// Formats [value] as a short "D Mon" date, e.g. "5 Jan", in the viewer's
/// local time.
String formatMonthDay(DateTime value, {Locale locale = const Locale('en')}) =>
    DateFormat('d MMM', _lang(locale)).format(value.toLocal());

/// Formats [value] as e.g. "5 January 2027", in the viewer's local time.
///
/// Pass a local calendar date: a UTC-midnight date-only value would show the
/// previous day for viewers behind UTC.
String formatLongDate(DateTime value, {Locale locale = const Locale('en')}) =>
    DateFormat('d MMMM y', _lang(locale)).format(value.toLocal());
