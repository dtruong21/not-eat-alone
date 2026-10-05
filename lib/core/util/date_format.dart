/// Pure date/time formatting shared across features.
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

/// Formats [value] as e.g. "January 5, 2027 at 7:30 PM" without pulling in
/// `intl` (not a direct dependency of this package).
///
/// Always renders in the viewer's local time: meal times come out of the data
/// layer as UTC `DateTime`s (Firestore `Timestamp` -> UTC ISO string), and a
/// local `DateTime`'s `toLocal()` is itself, so both kinds are handled.
String formatMealDateTime(DateTime value) {
  final dateTime = value.toLocal();
  final hour24 = dateTime.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '${_monthNames[dateTime.month - 1]} ${dateTime.day}, '
      '${dateTime.year} at $hour12:$minute $period';
}
