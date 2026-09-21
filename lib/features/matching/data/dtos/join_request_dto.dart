import 'package:freezed_annotation/freezed_annotation.dart';

part 'join_request_dto.freezed.dart';
part 'join_request_dto.g.dart';

@freezed
abstract class JoinRequestDto with _$JoinRequestDto {
  const factory JoinRequestDto({
    required String id,
    required String mealId,
    required String guestId,
    required String hostId,
    required String status,
    DateTime? createdAt,
  }) = _JoinRequestDto;

  factory JoinRequestDto.fromJson(Map<String, Object?> json) =>
      _$JoinRequestDtoFromJson(json);
}
