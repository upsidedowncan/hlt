 import 'package:flutter/material.dart';
 import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/constants/app_ui_constants.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/user.dart' as app_user;
import '../../../shared/extensions/string_extensions.dart';
import '../../profile/widgets/profile_avatar.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final List<app_user.User> participants;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressForMite;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.participants,
    required this.onTap,
    this.onLongPress,
    this.onLongPressForMite,
  });

  @override
  Widget build(BuildContext context) {
    final otherParticipants = participants.where((p) => p.id != Supabase.instance.client.auth.currentUser?.id).toList();
    final displayName = _getDisplayName(otherParticipants);
    final avatarUrl = _getAvatarUrl(otherParticipants);
    final lastMessage = conversation.lastMessage ?? 'No messages yet';
    final time = conversation.lastMessageAt?.formatTime() ?? '';

    return GestureDetector(
      onLongPress: () {
        if (onLongPressForMite != null) {
          onLongPressForMite!();
        } else if (onLongPress != null) {
          onLongPress!();
        }
      },
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingMedium,
          vertical: AppSizes.paddingSmall,
        ),
      leading: ProfileAvatar(
        avatarUrl: avatarUrl,
        displayName: displayName,
        size: AppSizes.avatarLarge,
      ),
      title: Text(
        displayName,
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.verticalTiny,
          Text(
            lastMessage,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (time.isNotEmpty) ...[
            Text(
              time,
              style: AppTextStyles.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            AppSpacing.verticalTiny,
          ],
          if (conversation.isGroup) ...[
            Icon(
              Icons.group,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
      ),
    );
  }

  String _getDisplayName(List<app_user.User> participants) {
    // Use the conversation name which is now set correctly by the database
    if (conversation.name != null && conversation.name!.isNotEmpty) {
      return conversation.name!;
    }

    // For group chats without a name
    if (conversation.isGroup) {
      return 'Group Chat';
    }

    // For direct messages, show participant name
    if (participants.isNotEmpty) {
      final user = participants.first;
      return user.displayName ?? user.username ?? user.email;
    }

    // Fallback if no participants found
    return 'Unknown';
  }

  String? _getAvatarUrl(List<app_user.User> participants) {
    // Use the conversation avatar which is now set correctly by the database
    if (conversation.avatarUrl != null) {
      return conversation.avatarUrl;
    }

    // Fallback to participant's avatar
    if (participants.isNotEmpty) {
      return participants.first.avatarUrl;
    }

    return null;
  }
}