/// Firestore BOUNDARY for the `chat` feature — the only chat/** file importing
/// cloud_firestore. Messages live at matches/{matchId}/messages, read state at
/// matches/{matchId}/reads/{uid}.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/chat/data/dtos/chat_message_dto.dart';
import 'package:not_eat_alone/features/chat/data/dtos/message_read_dto.dart';
import 'package:not_eat_alone/features/chat/data/mappers/chat_message_mapper.dart';
import 'package:not_eat_alone/features/chat/data/mappers/message_read_mapper.dart';
import 'package:not_eat_alone/features/chat/domain/entities/chat_message.dart';
import 'package:not_eat_alone/features/chat/domain/entities/message_read.dart';
import 'package:not_eat_alone/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? db;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, Object?>> _messages(String matchId) =>
      _firestore
          .collection('matches')
          .doc(matchId)
          .collection('messages');

  DocumentReference<Map<String, Object?>> _read(
    String matchId,
    String uid,
  ) =>
      _firestore
          .collection('matches')
          .doc(matchId)
          .collection('reads')
          .doc(uid);

  @override
  Stream<List<ChatMessage>> watchMessages(String matchId) {
    return _messages(matchId)
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs
            .map((d) => _messageFromDoc(matchId, d.id, d.data()))
            .toList(growable: false));
  }

  @override
  Future<void> sendMessage({
    required String matchId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 2000) {
      throw ArgumentError('message text must be 1..2000 chars');
    }
    try {
      await _messages(matchId).add({
        'matchId': matchId,
        'senderId': senderId,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      throw RepositoryWriteException('messages', e, st);
    }
  }

  @override
  Future<void> markRead({required String matchId, required String uid}) async {
    try {
      await _read(matchId, uid).set({
        'uid': uid,
        'lastReadAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      throw RepositoryWriteException('reads', e, st);
    }
  }

  @override
  Stream<MessageRead?> watchRead({
    required String matchId,
    required String uid,
  }) {
    return _read(matchId, uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _readFromDoc(uid, doc.data()!);
    });
  }

  static ChatMessage _messageFromDoc(
      String matchId, String id, Map<String, Object?> raw) {
    try {
      final data = Map<String, Object?>.from(raw)
        ..['id'] = id
        ..['matchId'] = matchId;
      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        data['createdAt'] = createdAt.toDate().toUtc().toIso8601String();
      }
      return ChatMessageDto.fromJson(data).toEntity();
    } catch (e, st) {
      throw RepositoryParseException('messages', id, e, st);
    }
  }

  static MessageRead _readFromDoc(String uid, Map<String, Object?> raw) {
    try {
      final data = Map<String, Object?>.from(raw)..['uid'] = uid;
      final lastReadAt = data['lastReadAt'];
      if (lastReadAt is Timestamp) {
        data['lastReadAt'] = lastReadAt.toDate().toUtc().toIso8601String();
      }
      return MessageReadDto.fromJson(data).toEntity();
    } catch (e, st) {
      throw RepositoryParseException('reads', uid, e, st);
    }
  }
}
