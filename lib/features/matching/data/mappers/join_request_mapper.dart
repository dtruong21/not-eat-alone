import 'package:not_eat_alone/features/matching/data/dtos/join_request_dto.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/entities/request_status.dart';

extension JoinRequestDtoX on JoinRequestDto {
  JoinRequest toEntity() => JoinRequest(
        id: id,
        mealId: mealId,
        guestId: guestId,
        hostId: hostId,
        status: _statusFromString(status),
        createdAt: createdAt,
      );
}

extension JoinRequestX on JoinRequest {
  JoinRequestDto toDto() => JoinRequestDto(
        id: id,
        mealId: mealId,
        guestId: guestId,
        hostId: hostId,
        status: status.name,
        createdAt: createdAt,
      );
}

RequestStatus _statusFromString(String value) {
  try {
    return RequestStatus.values.byName(value);
  } on ArgumentError {
    return RequestStatus.pending;
  }
}
