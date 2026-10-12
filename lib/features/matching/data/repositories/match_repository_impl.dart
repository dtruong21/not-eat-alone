import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/matching/data/dtos/match_dto.dart';
import 'package:not_eat_alone/features/matching/data/mappers/match_mapper.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/match_repository.dart';

/// Invokes the `cancelMatchedMeal` callable with its request payload. A seam
/// so tests don't need the plugin (mirrors `AccountRepositoryImpl`).
typedef CancelMatchedMealCallable = Future<void> Function(
  Map<String, dynamic> data,
);

class MatchRepositoryImpl implements MatchRepository {
  MatchRepositoryImpl({
    FirebaseFirestore? firestore,
    CancelMatchedMealCallable? callCancel,
  })  : _firestore = firestore ?? db,
        _callCancel = callCancel ?? _defaultCallCancel;

  final FirebaseFirestore _firestore;
  final CancelMatchedMealCallable _callCancel;

  static Future<void> _defaultCallCancel(Map<String, dynamic> data) async {
    await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('cancelMatchedMeal')
        .call<void>(data);
  }

  @override
  Future<void> cancelMatchedMeal({required String mealId}) async {
    try {
      await _callCancel({
        'mealId': mealId,
        'databaseId': FlavorConfig.current.firestoreDatabaseId,
      });
    } on FirebaseFunctionsException catch (e, st) {
      throw RepositoryWriteException('cancelMatchedMeal', e, st);
    }
  }

  @override
  Stream<List<Match>> watchMatchesForUser(String uid) {
    return _firestore
        .collection('matches')
        .where('participants', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList(growable: false));
  }

  static Match _fromDoc(QueryDocumentSnapshot<Map<String, Object?>> doc) {
    try {
      final data = Map<String, Object?>.from(doc.data())..['id'] = doc.id;
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        data['createdAt'] = createdAt.toDate().toUtc().toIso8601String();
      }
      return MatchDto.fromJson(data).toEntity();
    } catch (e, st) {
      throw RepositoryParseException('matches', doc.id, e, st);
    }
  }
}
