import 'package:not_eat_alone/features/safety/data/dtos/block_dto.dart';
import 'package:not_eat_alone/features/safety/domain/entities/block.dart';

extension BlockDtoX on BlockDto {
  Block toEntity() => Block(
        id: id,
        blockerUid: blockerUid,
        blockedUid: blockedUid,
        pair: pair,
        createdAt: createdAt,
      );
}

extension BlockX on Block {
  BlockDto toDto() => BlockDto(
        id: id,
        blockerUid: blockerUid,
        blockedUid: blockedUid,
        pair: pair,
        createdAt: createdAt,
      );
}
