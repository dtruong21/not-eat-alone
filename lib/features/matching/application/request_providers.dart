import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/matching/data/repositories/request_repository_impl.dart';
import 'package:not_eat_alone/features/matching/domain/repositories/request_repository.dart';

final requestRepositoryProvider =
    Provider<RequestRepository>((ref) => RequestRepositoryImpl());
