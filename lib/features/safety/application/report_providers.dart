import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:not_eat_alone/features/safety/data/repositories/report_repository_impl.dart';
import 'package:not_eat_alone/features/safety/domain/repositories/report_repository.dart';

/// The report boundary repository. Override in tests with a fake/mock.
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepositoryImpl(),
);
