import 'package:freezed_annotation/freezed_annotation.dart';

part 'match.freezed.dart';

@freezed
abstract class Match with _$Match {
  const factory Match({
    required String id,
    required String mealId,
    required String hostId,
    required String guestId,
    DateTime? createdAt,
  }) = _Match;
}
