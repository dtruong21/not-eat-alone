import 'package:not_eat_alone/features/notifications/domain/entities/push_route.dart';

/// Pure mapping from an FCM data payload to a navigation target. Returns null
/// for unknown/missing types (caller ignores). No side effects.
PushRoute? mapPushData(Map<String, String?> data) {
  switch (data['type']) {
    case 'message':
      final matchId = data['matchId'];
      return matchId == null ? null : PushRoute('/chats/$matchId');
    case 'rate':
      // The post-meal rating prompt (`PostMealCard`) lives at the top of the
      // match chat, so the rate push lands there.
      final matchId = data['matchId'];
      return matchId == null || matchId.isEmpty
          ? null
          : PushRoute('/chats/$matchId');
    case 'meal_reminder':
      final mealId = data['mealId'];
      return mealId == null || mealId.isEmpty
          ? null
          : PushRoute('/chats/$mealId');
    case 'request':
      return const PushRoute('/requests');
    case 'request_update':
      if (data['status'] == 'approved' && data['mealId'] != null) {
        return PushRoute('/chats/${data['mealId']}');
      }
      return const PushRoute('/discover');
    default:
      return null;
  }
}
