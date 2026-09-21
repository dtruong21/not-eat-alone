import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_dto.freezed.dart';
part 'match_dto.g.dart';

@freezed
abstract class MatchDto with _$MatchDto {
  const factory MatchDto({
    required String id,
    required String mealId,
    required String hostId,
    required String guestId,
    DateTime? createdAt,
  }) = _MatchDto;

  factory MatchDto.fromJson(Map<String, Object?> json) =>
      _$MatchDtoFromJson(json);
}
