import 'package:freezed_annotation/freezed_annotation.dart';

part 'restaurant.freezed.dart';

@freezed
abstract class Restaurant with _$Restaurant {
  const factory Restaurant({
    required String placeId,
    required String name,
    required String address,
    required double lat,
    required double lng,
  }) = _Restaurant;
}
