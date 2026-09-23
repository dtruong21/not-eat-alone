import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/block_repository.dart';

/// Firestore-backed [BlockRepository]. Blocks are stored one-way at
/// `blocks/{blockerUid}_{blockedUid}` with a `pair` array so a single query
/// finds every block involving a uid regardless of direction.
class BlockRepositoryImpl implements BlockRepository {
  BlockRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? db;
  final FirebaseFirestore _firestore;

  String _id(String a, String b) => '${a}_$b';

  @override
  Future<void> block(String blockerUid, String blockedUid) async {
    try {
      await _firestore
          .collection('blocks')
          .doc(_id(blockerUid, blockedUid))
          .set({
            'id': _id(blockerUid, blockedUid),
            'blockerUid': blockerUid,
            'blockedUid': blockedUid,
            'pair': [blockerUid, blockedUid],
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e, st) {
      throw RepositoryWriteException('blocks', e, st);
    }
  }

  @override
  Future<void> unblock(String blockerUid, String blockedUid) async {
    try {
      await _firestore
          .collection('blocks')
          .doc(_id(blockerUid, blockedUid))
          .delete();
    } catch (e, st) {
      throw RepositoryWriteException('blocks', e, st);
    }
  }

  @override
  Stream<Set<String>> watchBlockedUserIds(String uid) {
    return _firestore
        .collection('blocks')
        .where('pair', arrayContains: uid)
        .snapshots()
        .map((s) {
          final ids = <String>{};
          for (final d in s.docs) {
            final data = d.data();
            final blocker = data['blockerUid'] as String?;
            final blocked = data['blockedUid'] as String?;
            if (blocker != null && blocker != uid) ids.add(blocker);
            if (blocked != null && blocked != uid) ids.add(blocked);
          }
          return ids;
        });
  }
}
