import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:not_eat_alone/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:not_eat_alone/features/chat/domain/repositories/chat_repository.dart';

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepositoryImpl());
