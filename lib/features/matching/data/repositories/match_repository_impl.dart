import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/matching/data/dtos/match_dto.dart';
import 'package:not_eat_alone/features/matching/data/mappers/match_mapper.dart';
import 'package:not_eat_alone/features/matching/domain/entities/match.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/match_repository.dart';

class MatchRepositoryImpl implements MatchRepository {
  MatchRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? db;

  final FirebaseFirestore _firestore;

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
