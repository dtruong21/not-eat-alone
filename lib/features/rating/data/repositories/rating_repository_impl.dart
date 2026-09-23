/// Firestore BOUNDARY for the `rating` feature — the only file in
/// `lib/features/rating/**` allowed to import `cloud_firestore`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/rating/data/dtos/rating_dto.dart';
import 'package:not_eat_alone/features/rating/data/mappers/rating_mapper.dart';
import 'package:not_eat_alone/features/rating/domain/entities/rating.dart';
import 'package:not_eat_alone/features/rating/domain/repositories/rating_repository.dart';

class RatingRepositoryImpl implements RatingRepository {
  RatingRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? db;

  final FirebaseFirestore _firestore;

  @override
  Future<void> submit(Rating rating) async {
    final json = rating.toDto().toJson()
      ..['createdAt'] = FieldValue.serverTimestamp();

    try {
      await _firestore.collection('ratings').doc(rating.id).set(json);
    } catch (e, st) {
      throw RepositoryWriteException('ratings', e, st);
    }
  }

  @override
  Stream<Rating?> watchMyRating(String matchId, String raterUid) {
    return _firestore
        .collection('ratings')
        .doc('${matchId}_$raterUid')
        .snapshots()
        .map((doc) => doc.exists ? _fromDoc(doc.id, doc.data()!) : null);
  }

  static Rating _fromDoc(String id, Map<String, Object?> raw) {
    try {
      final data = Map<String, Object?>.from(raw)..['id'] = id;
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        data['createdAt'] = createdAt.toDate().toUtc().toIso8601String();
      }
      return RatingDto.fromJson(data).toEntity();
    } catch (e, st) {
      throw RepositoryParseException('ratings', id, e, st);
    }
  }
}
