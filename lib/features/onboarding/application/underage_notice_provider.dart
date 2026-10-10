import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the sign-in screen shows the "must be 18 or older" banner.
///
/// Set by the age gate before it signs the user out; cleared when the banner
/// is dismissed or a sign-in starts. Not auto-disposed: it must survive the
/// gap between the age gate and the sign-in screen having listeners.
class UnderageNotice extends Notifier<bool> {
  @override
  bool build() => false;

  /// Shows or hides the banner.
  // ignore: use_setters_to_change_properties
  void set({required bool value}) => state = value;
}

/// See [UnderageNotice].
final underageNoticeProvider = NotifierProvider<UnderageNotice, bool>(
  UnderageNotice.new,
);
