/// Firestore-backed implementation of [MealRepository].
///
/// This file is the Firestore BOUNDARY for the `meal` feature — it is the
/// only place in `lib/features/meal/**` allowed to import `cloud_firestore`.
/// Domain code must go through [MealRepository], never `cloud_firestore`
/// directly.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  /// Max upcoming open meals one discovery listener downloads.
  static const discoverableLimit = 100;

  /// Streams UPCOMING open meals (`status == 'open'` and `dateTime` after now,
  /// soonest first, at most [discoverableLimit]) whose `geohash` starts with
  /// [geohashPrefix].
  ///
  /// Bounding by time on the server keeps the download from growing with
  /// every meal ever created (expired meals stay `open` forever — nothing
  /// closes them). The `status` equality + `dateTime` range/order uses the
  /// composite index in `firebase/firestore.indexes.json` (`status` ASC,
  /// `dateTime` ASC). The geohash prefix is filtered on the client: v1 is
  /// Paris-only (one cell), and Firestore can't combine a second range filter
  /// on `geohash` with this one without another index — revisit at the
  /// multi-city scale-up.
  ///
  /// `now` is fixed when the listener starts; the caller drops meals whose
  /// start time passes later (see `discoveryControllerProvider`).
  ///
  /// A doc that fails to parse (schema drift) surfaces as a
  /// [RepositoryParseException] error event on the stream, same as
  /// `UserRepositoryImpl`'s converter.
  @override
  Stream<List<Meal>> watchDiscoverable({required String geohashPrefix}) {
    return _firestore
        .collection('meals')
        .where('status', isEqualTo: 'open')
        .where('dateTime', isGreaterThan: Timestamp.now())
        .orderBy('dateTime')
        .limit(discoverableLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where(
                (doc) => ((doc.data()['geohash'] as String?) ?? '').startsWith(
                  geohashPrefix,
                ),
              )
              .map(_tryMealFromDoc)
              .whereType<Meal>()
              .toList(growable: false),
        );
  }

  /// Reads `meals/{id}` once, or `null` if it doesn't exist.
  @override
  Future<Meal?> getMeal(String id) async {
    final snapshot = await _firestore.collection('meals').doc(id).get();
    if (!snapshot.exists) return null;
    return _mealFromData(id, snapshot.data()!);
  }

  /// Streams `meals/{id}`; see [MealRepository.watchMeal].
  @override
  Stream<Meal?> watchMeal(String id) =>
      mapMealSnapshots(id, _firestore.collection('meals').doc(id).snapshots());

  /// Maps raw doc snapshots to meals. A missing doc emits `null`, and so does
  /// `permission-denied` / `not-found` (the meal was deleted or hidden by the
  /// rules); every other error propagates.
  @visibleForTesting
  static Stream<Meal?> mapMealSnapshots(
    String id,
    Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots,
  ) => snapshots.transform(
    StreamTransformer<
      DocumentSnapshot<Map<String, dynamic>>,
      Meal?
    >.fromHandlers(
      handleData: (snapshot, sink) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          sink.add(null);
          return;
        }
        try {
          sink.add(_mealFromData(id, data));
        } on RepositoryParseException catch (e, st) {
          sink.addError(e, st);
        }
      },
      handleError: (error, stackTrace, sink) {
        if (error is FirebaseException &&
            (error.code == 'permission-denied' || error.code == 'not-found')) {
          sink.add(null);
        } else {
          sink.addError(error, stackTrace);
        }
      },
    ),
  );

  /// A malformed document (schema drift or a hostile write) is skipped and
  /// logged, so one bad meal can never fail the whole feed for everyone.
  static Meal? _tryMealFromDoc(
    QueryDocumentSnapshot<Map<String, Object?>> doc,
  ) {
    try {
      return _mealFromDoc(doc);
    } on RepositoryParseException catch (e) {
      debugPrint('[meals] skipping unparseable meal ${doc.id}: ${e.cause}');
      return null;
    }
  }

  static Meal _mealFromDoc(QueryDocumentSnapshot<Map<String, Object?>> doc) =>
      _mealFromData(doc.id, doc.data());

  static Meal _mealFromData(String id, Map<String, Object?> raw) {
    try {
      final data = Map<String, Object?>.from(raw)..['id'] = id;

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
      throw RepositoryParseException('meals', id, e, st);
    }
  }
}
