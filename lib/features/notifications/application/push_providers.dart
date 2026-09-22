import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/notifications/data/repositories/push_repository_impl.dart';
import 'package:not_eat_alone/features/notifications/domain/repositories/push_repository.dart';

final pushRepositoryProvider =
    Provider<PushRepository>((ref) => PushRepositoryImpl());
