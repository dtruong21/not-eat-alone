/// True iff [input] looks like an E.164 number: `+` followed by 8-15 digits
/// (spaces ignored). Not a carrier check — just enough to avoid a round trip
/// for obvious typos.
bool isPlausiblePhone(String input) =>
    RegExp(r'^\+\d{8,15}$').hasMatch(input.replaceAll(' ', '').trim());

/// Display form of an E.164 number: French `+33612345678` becomes
/// `+33 6 12 34 56 78`; anything else is returned as is.
String formatPhoneDisplay(String e164) {
  final m = RegExp(r'^\+33(\d)(\d{2})(\d{2})(\d{2})(\d{2})$').firstMatch(e164);
  return m == null ? e164 : '+33 ${m[1]} ${m[2]} ${m[3]} ${m[4]} ${m[5]}';
}
