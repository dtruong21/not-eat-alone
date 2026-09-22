import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_read.freezed.dart';

@freezed
abstract class MessageRead with _$MessageRead {
  const factory MessageRead({
    required String uid,
    DateTime? lastReadAt,
  }) = _MessageRead;
}
