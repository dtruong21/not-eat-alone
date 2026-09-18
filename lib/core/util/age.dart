/// True iff someone born on [dob] is at least 18 years old at [now]
/// (defaults to DateTime.now()).
bool isAdult(DateTime dob, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - dob.year;
  final hadBirthday = (today.month > dob.month) ||
      (today.month == dob.month && today.day >= dob.day);
  if (!hadBirthday) age -= 1;
  return age >= 18;
}
