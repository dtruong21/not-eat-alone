/// One row in the Chats tab — the other participant's photo/name, a
/// last-message preview, a relative timestamp, and an unread dot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:not_eat_alone/core/design/avatar_image.dart';
import 'package:not_eat_alone/core/design/theme.dart';
import 'package:not_eat_alone/core/design/tokens.dart';
import 'package:not_eat_alone/core/util/date_format.dart';
import 'package:not_eat_alone/features/auth/application/auth_providers.dart';
import 'package:not_eat_alone/features/chat/application/chat_list_provider.dart';
import 'package:not_eat_alone/features/chat/application/chat_messages_provider.dart';
import 'package:not_eat_alone/features/rating/application/match_meal_provider.dart';
import 'package:not_eat_alone/features/user/application/user_providers.dart';
import 'package:not_eat_alone/l10n/l10n.dart';

/// "1m" / "2h" / "3d" / falls back to a short date beyond a week — kept as a
/// small private helper rather than a shared util, since this is the only
/// place that needs it.
String _relativeTime(
  DateTime dateTime,
  AppLocalizations l10n, {
  DateTime? now,
  Locale locale = const Locale('en'),
}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(dateTime);
  if (diff.inMinutes < 1) return l10n.chatTimeNow;
  if (diff.inHours < 1) return l10n.chatTimeMinutes(diff.inMinutes);
  if (diff.inDays < 1) return l10n.chatTimeHours(diff.inHours);
  if (diff.inDays < 7) return l10n.chatTimeDays(diff.inDays);
  return formatMonthDay(dateTime, locale: locale);
}

/// A single chat row. Watches [userDocProvider] for the other participant's
/// photo/name (tolerates loading/null with a placeholder) and
/// [lastMessageProvider] (a `limit(1)` query) for the last-message preview + unread state.
///
/// Unread is derived simply: the last message exists and was sent by the
/// other participant — a full compare against the viewer's own `reads` doc
/// is deferred (optional per the chat spec) since this dot is a secondary
/// affordance, not the read-receipt system of record.
class ChatListTile extends ConsumerWidget {
  const ChatListTile({required this.item, super.key});

  final ChatListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final user = ref.watch(userDocProvider(item.otherUid)).value;
    final lastMessage = ref.watch(lastMessageProvider(item.match.id)).value;
    // Absent until loaded (or if the meal is gone): no spinner, no empty line.
    final meal = ref.watch(matchMealProvider(item.match.id)).value;
    final myUid = ref.watch(authStateProvider).value?.uid;

    final l10n = context.l10n;
    final preview = lastMessage?.text ?? l10n.chatSayHi;
    final unread =
        lastMessage != null && myUid != null && lastMessage.senderId != myUid;

    final locale = Localizations.localeOf(context);
    final photoUrl = (user?.photoUrls.isNotEmpty ?? false)
        ? user!.photoUrls.first
        : null;
    final name = user?.displayName ?? l10n.chatTitleFallback;

    return Material(
      color: colors.surface,
      elevation: WarmPlayfulElevation.card,
      shadowColor: context.wp.shadow,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
      child: InkWell(
        key: Key('chat_list_tile_${item.match.id}'),
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
        onTap: () => context.push('/chats/${item.match.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WarmPlayfulSpacing.s4,
            vertical: WarmPlayfulSpacing.s3,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: WarmPlayfulSpacing.s5,
                backgroundColor: colors.surfaceContainerHighest,
                backgroundImage: photoUrl != null
                    ? avatarImage(
                        context,
                        photoUrl,
                        radius: WarmPlayfulSpacing.s5,
                      )
                    : null,
                onBackgroundImageError: photoUrl != null
                    ? ignoreAvatarImageError
                    : null,
                child: photoUrl == null
                    ? Icon(Icons.person_rounded, color: context.wp.muted)
                    : null,
              ),
              const SizedBox(width: WarmPlayfulSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: WarmPlayfulType.h2Weight,
                      ),
                    ),
                    if (meal != null) ...[
                      const SizedBox(height: WarmPlayfulSpacing.s1),
                      Text(
                        '${meal.restaurant.name} · '
                        '${formatMealDateTime(meal.dateTime, locale: locale)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: context.wp.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: WarmPlayfulSpacing.s1),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.wp.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WarmPlayfulSpacing.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (lastMessage?.createdAt != null)
                    Text(
                      _relativeTime(
                        lastMessage!.createdAt!,
                        l10n,
                        locale: locale,
                      ),
                      style: textTheme.bodySmall?.copyWith(
                        color: context.wp.muted,
                      ),
                    ),
                  if (unread) ...[
                    const SizedBox(height: WarmPlayfulSpacing.s1),
                    Semantics(
                      label: l10n.chatUnreadSemantics,
                      child: Container(
                        key: Key('chat_list_tile_unread_${item.match.id}'),
                        width: WarmPlayfulSpacing.s2,
                        height: WarmPlayfulSpacing.s2,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
