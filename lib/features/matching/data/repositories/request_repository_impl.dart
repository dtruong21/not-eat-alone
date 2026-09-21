/// Firestore BOUNDARY for the `matching` feature — the only file in
/// `lib/features/matching/**` allowed to import `cloud_firestore`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/matching/data/dtos/join_request_dto.dart';
import 'package:not_eat_alone/features/matching/data/mappers/join_request_mapper.dart';
import 'package:not_eat_alone/features/matching/data/repositories/meal_no_longer_open_exception.dart';
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
  Future<void> approve(JoinRequest request) async {
    final mealRef = _firestore.collection('meals').doc(request.mealId);
    final reqRef = _firestore.collection('requests').doc(request.id);
    final matchRef = _firestore.collection('matches').doc(request.mealId);

    try {
      await _firestore.runTransaction((txn) async {
        final mealSnap = await txn.get(mealRef);
        if (!mealSnap.exists || mealSnap.data()!['status'] != 'open') {
          throw MealNoLongerOpenException(request.mealId);
        }
        txn.update(mealRef, {'status': 'matched', 'guestId': request.guestId});
        txn.update(reqRef, {'status': 'approved'});
        txn.set(matchRef, {
          'id': request.mealId,
          'mealId': request.mealId,
          'hostId': request.hostId,
          'guestId': request.guestId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on MealNoLongerOpenException {
      rethrow;
    } catch (e, st) {
      throw RepositoryWriteException('matches', e, st);
    }

    // Post-commit: deny the losing pending requests. Firestore transactions
    // cannot run queries, so this is a follow-up batch. The meal is already
    // `matched`, so rules block any new pending request from appearing.
    final siblings = await _firestore
        .collection('requests')
        .where('mealId', isEqualTo: request.mealId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (siblings.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in siblings.docs) {
      batch.update(doc.reference, {'status': 'denied'});
    }
    try {
      await batch.commit();
    } catch (e, st) {
      throw RepositoryWriteException('requests', e, st);
    }
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
