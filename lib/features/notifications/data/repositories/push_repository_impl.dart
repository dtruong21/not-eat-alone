/// Firestore + FCM BOUNDARY for notifications. The messaging calls are behind
/// injectable function seams so token I/O is unit-testable without the plugin.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:not_eat_alone/core/firebase/firebase_client.dart';
import 'package:not_eat_alone/core/firebase/repository_exception.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';

typedef TokenReader = Future<String?> Function();
typedef PermissionRequester = Future<bool> Function();

class PushRepositoryImpl implements PushRepository {
  PushRepositoryImpl({
    FirebaseFirestore? firestore,
    TokenReader? readToken,
    PermissionRequester? requestPermissionFn,
    String? platformName,
    Stream<String>? tokenRefreshStream,
  })  : _firestore = firestore ?? db,
        _readToken = readToken ?? _defaultReadToken,
        _requestPermission = requestPermissionFn ?? _defaultRequestPermission,
        _platform = platformName ?? _defaultPlatform(),
        _tokenRefreshStream = tokenRefreshStream;

  final FirebaseFirestore _firestore;
  final TokenReader _readToken;
  final PermissionRequester _requestPermission;
  final String _platform;
  final Stream<String>? _tokenRefreshStream;
  StreamSubscription<String>? _refreshSubscription;

  static Future<String?> _defaultReadToken() =>
      FirebaseMessaging.instance.getToken();

  static Future<bool> _defaultRequestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static String _defaultPlatform() =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  Stream<String>? _getRefreshStream() {
    if (_tokenRefreshStream != null) return _tokenRefreshStream;
    try {
      return FirebaseMessaging.instance.onTokenRefresh;
    } on Object {
      // FirebaseMessaging not available (e.g., in unit tests)
      return null;
    }
  }

  @override
  Future<bool> requestPermission() => _requestPermission();

  @override
  Future<void> registerToken(String uid) async {
    // Cancel any existing refresh subscription to avoid duplicates
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;

    // Register current token
    final token = await _readToken();
    if (token == null || token.isEmpty) return;
    try {
      await _tokenDoc(uid, token).set({
        'token': token,
        'platform': _platform,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      throw RepositoryWriteException('fcmTokens', e, st);
    }

    // Subscribe to refresh stream to keep token fresh on FCM rotation
    final refreshStream = _getRefreshStream();
    if (refreshStream != null) {
      _refreshSubscription = refreshStream.listen(
        (newToken) {
          if (newToken.isEmpty) return;
          _tokenDoc(uid, newToken)
              .set({
                'token': newToken,
                'platform': _platform,
                'updatedAt': FieldValue.serverTimestamp(),
              })
              .catchError((dynamic e, dynamic st) {
                // Best effort: ignore errors so they don't crash the app
              })
              .ignore();
        },
      );
    }
  }

  @override
  Future<void> unregisterCurrentToken(String uid) async {
    final token = await _readToken();
    if (token == null || token.isEmpty) return;
    try {
      await _tokenDoc(uid, token).delete();
    } catch (e, st) {
      throw RepositoryWriteException('fcmTokens', e, st);
    }
  }

  DocumentReference<Map<String, Object?>> _tokenDoc(String uid, String token) =>
      _firestore.collection('users').doc(uid).collection('fcmTokens').doc(token);
}
