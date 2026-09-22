import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/report_repository.dart';

/// Firestore-backed [ReportRepository]. Write-only: reports are stored at
/// `reports/{autoId}` and never read back by the client — rules deny
/// `read`/`update`/`delete`, so no DTO round-trip is needed.
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? db;
  final FirebaseFirestore _firestore;

  @override
  Future<void> report({
    required String reporterId,
    required String targetType,
    required String targetId,
    String? reason,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterId': reporterId,
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      throw RepositoryWriteException('reports', e, st);
    }
  }
}
