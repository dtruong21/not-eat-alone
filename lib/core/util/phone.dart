/// True iff [input] looks like an E.164 number: `+` followed by 8-15 digits
/// (spaces ignored). Not a carrier check — just enough to avoid a round trip
/// for obvious typos.
bool isPlausiblePhone(String input) =>
    RegExp(r'^\+\d{8,15}$').hasMatch(input.replaceAll(' ', '').trim());
