/// Firestore BOUNDARY for the `matching` feature — the only file in
/// `lib/features/matching/**` allowed to import `cloud_firestore`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/matching/data/dtos/join_request_dto.dart';
import 'package:not_eat_alone/features/matching/data/mappers/join_request_mapper.dart';
import 'package:not_eat_alone/features/matching/domain/entities/join_request.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/request_repository.dart';

class RequestRepositoryImpl implements RequestRepository {
  RequestRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? db;

  final FirebaseFirestore _firestore;

  String _requestId(String mealId, String guestId) => '${mealId}_$guestId';

  @override
  Future<void> createRequest({
    required String mealId,
    required String guestId,
    required String hostId,
  }) async {
    final id = _requestId(mealId, guestId);
    try {
      await _firestore.collection('requests').doc(id).set({
        'id': id,
        'mealId': mealId,
        'guestId': guestId,
        'hostId': hostId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      throw RepositoryWriteException('requests', e, st);
    }
  }

  @override
  Stream<JoinRequest?> watchRequest({
    required String mealId,
    required String guestId,
  }) {
    return _firestore
        .collection('requests')
        .doc(_requestId(mealId, guestId))
        .snapshots()
        .map((doc) => doc.exists ? _fromDoc(doc.id, doc.data()!) : null);
  }

  @override
  Stream<List<JoinRequest>> watchPendingForHost(String hostId) {
    return _firestore
        .collection('requests')
        .where('hostId', isEqualTo: hostId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => _fromDoc(d.id, d.data()))
            .toList(growable: false));
  }

  @override
  Future<void> deny(JoinRequest request) async {
    try {
      await _firestore
          .collection('requests')
          .doc(request.id)
          .update({'status': 'denied'});
    } catch (e, st) {
      throw RepositoryWriteException('requests', e, st);
    }
  }

  @override
  Future<void> approve(JoinRequest request) {
    throw UnimplementedError('approve lands in Task 4');
  }

  static JoinRequest _fromDoc(String id, Map<String, Object?> raw) {
    try {
      final data = Map<String, Object?>.from(raw)..['id'] = id;
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        data['createdAt'] = createdAt.toDate().toUtc().toIso8601String();
      }
      return JoinRequestDto.fromJson(data).toEntity();
    } catch (e, st) {
      throw RepositoryParseException('requests', id, e, st);
    }
  }
}
