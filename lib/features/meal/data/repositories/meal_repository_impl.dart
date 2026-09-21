/// Firestore-backed implementation of [MealRepository].
///
/// This file is the Firestore BOUNDARY for the `meal` feature — it is the
/// only place in `lib/features/meal/**` allowed to import `cloud_firestore`.
/// Domain code must go through [MealRepository], never `cloud_firestore`
/// directly.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/core/util/geohash.dart';
import 'package:not_eat_alone/features/meal/data/mappers/meal_mapper.dart';
import 'package:not_eat_alone/features/meal/domain/entities/meal.dart';
import 'package:not_eat_alone/features/meal/domain/repositories/meal_repository.dart';

/// Repository for creating `meals/{mealId}` documents.
///
/// Writes go through a raw (non-converter) map rather than `MealDto.toJson`
/// directly, because `dateTime`/`createdAt` are `DateTime`/nullable in the
/// model but must be Firestore `Timestamp`/`serverTimestamp()` on disk —
/// same pattern as `UserRepositoryImpl`.
class MealRepositoryImpl implements MealRepository {
  /// Creates a repository over [firestore], or the flavor-aware default
  /// Firestore instance ([db]) when omitted. Tests should inject a fake.
  MealRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? db;

  final FirebaseFirestore _firestore;

  /// Creates a new `meals/{mealId}` document for [meal], filling in a
  /// geohash from the restaurant's coordinates when [meal.geohash] is
  /// empty. Returns the new document's id.
  @override
  Future<String> createMeal(Meal meal) async {
    final geohash = meal.geohash.isEmpty
        ? encodeGeohash(meal.restaurant.lat, meal.restaurant.lng)
        : meal.geohash;

    final docRef = _firestore.collection('meals').doc();
    final newId = docRef.id;

    final dto = meal.copyWith(id: newId, geohash: geohash).toDto();
    final json = dto.toJson();
    // `MealDto.toJson()` uses json_serializable's default
    // `explicitToJson: false`, which leaves `restaurant` as a `RestaurantDto`
    // object reference rather than a plain map — Firestore's SDK can't
    // serialize that directly, so convert it explicitly here.
    json['restaurant'] = dto.restaurant.toJson();
    json['dateTime'] = Timestamp.fromDate(dto.dateTime);
    json['createdAt'] = FieldValue.serverTimestamp();

    try {
      await docRef.set(json);
    } catch (e, st) {
      throw RepositoryWriteException('meals', e, st);
    }

    return newId;
  }
}
