/// Pure date/time formatting shared across features.
///
/// English, 24-hour, day-before-month, dependency-free: `intl` and French
/// arrive with the localisation plan (19), which replaces these internals.
library;

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdayAbbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _monthAbbreviation(int month) => _monthNames[month - 1].substring(0, 3);

String _clock(DateTime local) =>
    '${local.hour.toString().padLeft(2, '0')}:'
    '${local.minute.toString().padLeft(2, '0')}';

/// Formats [value] for a meal: "Today 20:30", "Tomorrow 12:30", otherwise
/// "Sat 10 Oct, 20:00" (with the year, "Sat 10 Oct 2027, 20:00", only when it
/// differs from [now]'s year). Past dates use the absolute form.
///
/// Always renders in the viewer's local time: meal times come out of the data
/// layer as UTC `DateTime`s, and a local `DateTime`'s `toLocal()` is itself,
/// so both kinds are handled. "Today"/"Tomorrow" compare local calendar days;
/// [now] defaults to `DateTime.now()` and exists for tests.
String formatMealDateTime(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  // UTC midnights so a DST change never makes a day 23 or 25 hours long.
  final dayDelta = DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (dayDelta == 0) return 'Today ${_clock(local)}';
  if (dayDelta == 1) return 'Tomorrow ${_clock(local)}';
  final year = local.year == today.year ? '' : ' ${local.year}';
  return '${_weekdayAbbreviations[local.weekday - 1]} ${local.day} '
      '${_monthAbbreviation(local.month)}$year, ${_clock(local)}';
}

/// Formats [value] as a 24-hour clock time, e.g. "20:30", in the viewer's
/// local time (chat timestamps come out of the data layer as UTC
/// `DateTime`s; a local value's `toLocal()` is itself).
String formatClockTime(DateTime value) => _clock(value.toLocal());

/// Formats [value] as a short "D Mon" date, e.g. "5 Jan", in the viewer's
/// local time.
String formatMonthDay(DateTime value) {
  final local = value.toLocal();
  return '${local.day} ${_monthAbbreviation(local.month)}';
}

/// Formats [value] as e.g. "5 January 2027", in the viewer's local time.
///
/// Pass a local calendar date: a UTC-midnight date-only value would show the
/// previous day for viewers behind UTC.
String formatLongDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day} ${_monthNames[local.month - 1]} ${local.year}';
}
