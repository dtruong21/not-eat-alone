/// `cloud_functions` BOUNDARY for account deletion. The callable invocation
/// is behind an injectable function seam so the controller test doesn't need
/// the plugin — mirrors `PushRepositoryImpl`'s token-reader seam.
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'package:not_eat_alone/core/config/flavor.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/account_repository.dart';

/// Invokes the `deleteAccount` callable with its request payload.
typedef DeleteAccountCallable = Future<void> Function(
  Map<String, dynamic> data,
);

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({DeleteAccountCallable? callDeleteAccount})
    : _callDeleteAccount = callDeleteAccount ?? _defaultCallDeleteAccount;

  final DeleteAccountCallable _callDeleteAccount;

  static Future<void> _defaultCallDeleteAccount(
    Map<String, dynamic> data,
  ) async {
    await FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('deleteAccount').call<void>(data);
  }

  @override
  Future<void> deleteAccount() {
    return _callDeleteAccount({
      'databaseId': FlavorConfig.current.firestoreDatabaseId,
    });
  }
}
