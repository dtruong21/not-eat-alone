/// The E.164 form of what the user typed, or null when it is not plausible:
/// spaces and hyphens are dropped, and the trunk 0 a French number is written
/// with (`+33 06 12 …`) is not dialled, so it is removed. Valid means `+`
/// followed by 8-15 digits, and exactly 9 after `+33`. Other countries keep
/// their leading 0 (`+39 06 …`). Not a carrier check — just enough to avoid a
/// round trip for obvious typos.
String? toE164(String input) {
  final e164 = input
      .replaceAll(RegExp(r'[\s-]'), '')
      .replaceFirst(RegExp(r'^\+330'), '+33');
  final plausible =
      RegExp(r'^\+\d{8,15}$').hasMatch(e164) &&
      (!e164.startsWith('+33') || RegExp(r'^\+33\d{9}$').hasMatch(e164));
  return plausible ? e164 : null;
}

/// Whether [toE164] accepts [input].
bool isPlausiblePhone(String input) => toE164(input) != null;

/// Display form of an E.164 number: French `+33612345678` becomes
/// `+33 6 12 34 56 78`; anything else is returned as is.
String formatPhoneDisplay(String e164) {
  final m = RegExp(r'^\+33(\d)(\d{2})(\d{2})(\d{2})(\d{2})$').firstMatch(e164);
  return m == null ? e164 : '+33 ${m[1]} ${m[2]} ${m[3]} ${m[4]} ${m[5]}';
}
