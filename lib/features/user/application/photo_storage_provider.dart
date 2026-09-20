/// Provider wiring for [PhotoStorageDataSource] — the Storage boundary for
/// profile photos. Kept as its own file (rather than folded into
/// `user_providers.dart`) so application code depends on a narrow provider
/// rather than importing the datasource module directly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/user/data/datasources/photo_storage_datasource.dart';

final photoStorageDataSourceProvider =
    Provider<PhotoStorageDataSource>((ref) => PhotoStorageDataSource());
