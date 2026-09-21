import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';

part 'join_request.freezed.dart';

@freezed
abstract class JoinRequest with _$JoinRequest {
  const factory JoinRequest({
    required String id,
    required String mealId,
    required String guestId,
    required String hostId,
    @Default(RequestStatus.pending) RequestStatus status,
    DateTime? createdAt,
  }) = _JoinRequest;
}
