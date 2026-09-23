import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/safety/data/repositories/account_repository_impl.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/account_repository.dart';

/// The account boundary repository. Override in tests with a fake/mock.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepositoryImpl(),
);
