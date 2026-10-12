/// A compact row under the chat app bar naming the meal this chat is about:
/// "Pizzeria Popolare · Tue 6 Oct, 20:30". Tapping it opens the meal detail.
/// Renders nothing while the meal is loading or unavailable (no spinner).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/rating/application/match_meal_provider.dart';

class ChatMealHeader extends ConsumerWidget {
  const ChatMealHeader({required this.matchId, super.key});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meal = ref.watch(matchMealProvider(matchId)).value;
    if (meal == null) return const SizedBox.shrink();

    final wp = context.wp;
    return InkWell(
      key: const Key('chat_meal_header'),
      onTap: () => context.push('/meals/detail', extra: meal),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: WarmPlayfulSize.minTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WarmPlayfulSpacing.s4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${meal.restaurant.name} · '
                  '${formatMealDateTime(meal.dateTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: wp.muted),
                ),
              ),
              const SizedBox(width: WarmPlayfulSpacing.s2),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: WarmPlayfulSize.icon,
                  color: wp.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
