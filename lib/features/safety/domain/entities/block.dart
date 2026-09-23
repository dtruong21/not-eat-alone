import 'package:freezed_annotation/freezed_annotation.dart';

part 'block.freezed.dart';

@freezed
abstract class Block with _$Block {
  const factory Block({
    required String id,
    required String blockerUid,
    required String blockedUid,
    required List<String> pair,
    DateTime? createdAt,
  }) = _Block;
}
