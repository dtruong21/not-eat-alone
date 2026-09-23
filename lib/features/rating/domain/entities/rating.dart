import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating.freezed.dart';

/// A rating given by one match participant to another.
@freezed
abstract class Rating with _$Rating {
  /// Creates a new rating.
  const factory Rating({
    required String id,
    required String matchId,
    required String raterUid,
    required String targetUid,
    required int stars,
    required bool showedUp,
    String? comment,
    DateTime? createdAt,
  }) = _Rating;
}
