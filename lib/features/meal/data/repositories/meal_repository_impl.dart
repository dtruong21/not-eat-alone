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
import 'package:not_eat_alone/features/meal/data/dtos/meal_dto.dart';
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

  /// Streams `meals` documents with `status == 'open'` whose `geohash`
  /// starts with [geohashPrefix].
  ///
  /// `'~'` (0x7E) sorts after every base-32 geohash character, so bounding
  /// the range with `geohash < '$geohashPrefix~'` selects exactly the docs
  /// whose geohash starts with [geohashPrefix]. The equality + range filter
  /// needs the composite index declared in
  /// `firebase/firestore.indexes.json` (`status` ASC, `geohash` ASC).
  ///
  /// A doc that fails to parse (schema drift) surfaces as a
  /// [RepositoryParseException] error event on the stream, same as
  /// `UserRepositoryImpl`'s converter.
  @override
  Stream<List<Meal>> watchDiscoverable({required String geohashPrefix}) {
    return _firestore
        .collection('meals')
        .where('status', isEqualTo: 'open')
        .where('geohash', isGreaterThanOrEqualTo: geohashPrefix)
        .where('geohash', isLessThan: '$geohashPrefix~')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_mealFromDoc).toList(growable: false),
        );
  }

  static Meal _mealFromDoc(QueryDocumentSnapshot<Map<String, Object?>> doc) {
    try {
      final data = Map<String, Object?>.from(doc.data())..['id'] = doc.id;

      // Same Timestamp→ISO-DateTime translation as
      // `UserRepositoryImpl._fromFirestore` — `dateTime`/`createdAt` are
      // `DateTime`/nullable-`DateTime` in the model but `Timestamp` on disk.
      final dateTime = data['dateTime'];
      if (dateTime is Timestamp) {
        data['dateTime'] = dateTime.toDate().toUtc().toIso8601String();
      }

      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        data['createdAt'] = createdAt.toDate().toUtc().toIso8601String();
      }

      return MealDto.fromJson(data).toEntity();
    } catch (e, st) {
      throw RepositoryParseException('meals', doc.id, e, st);
    }
  }
}
