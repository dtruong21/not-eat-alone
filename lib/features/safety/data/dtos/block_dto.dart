import 'package:freezed_annotation/freezed_annotation.dart';

part 'block_dto.freezed.dart';
part 'block_dto.g.dart';

@freezed
abstract class BlockDto with _$BlockDto {
  const factory BlockDto({
    required String id,
    required String blockerUid,
    required String blockedUid,
    required List<String> pair,
    DateTime? createdAt,
  }) = _BlockDto;

  factory BlockDto.fromJson(Map<String, Object?> json) => _$BlockDtoFromJson(json);
}
