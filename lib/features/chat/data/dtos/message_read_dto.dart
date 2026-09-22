import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_read_dto.freezed.dart';
part 'message_read_dto.g.dart';

@freezed
abstract class MessageReadDto with _$MessageReadDto {
  const factory MessageReadDto({
    required String uid,
    DateTime? lastReadAt,
  }) = _MessageReadDto;

  factory MessageReadDto.fromJson(Map<String, Object?> json) =>
      _$MessageReadDtoFromJson(json);
}
