import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/chat_user_model.dart';

/// AppBar for the chat screen showing user info, online status and actions.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ChatUser user;
  final bool isTyping;
  final VoidCallback? onVideoCall;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onMoreOptions;

  const ChatAppBar({
    super.key,
    required this.user,
    this.isTyping = false,
    this.onVideoCall,
    this.onVoiceCall,
    this.onMoreOptions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withAlpha(26),
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppColors.textPrimary,
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Row(
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              if (user.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.online,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 10),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isTyping
                      ? const Text(
                          'escribiendo...',
                          key: ValueKey('typing'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Text(
                          user.isOnline ? 'En línea' : _lastSeenText(),
                          key: const ValueKey('status'),
                          style: TextStyle(
                            fontSize: 12,
                            color: user.isOnline
                                ? AppColors.online
                                : AppColors.textSecondary,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_rounded),
          color: AppColors.primary,
          onPressed: onVideoCall,
          tooltip: 'Videollamada',
        ),
        IconButton(
          icon: const Icon(Icons.call_rounded),
          color: AppColors.primary,
          onPressed: onVoiceCall,
          tooltip: 'Llamada',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          color: AppColors.textSecondary,
          onPressed: onMoreOptions,
          tooltip: 'Más opciones',
        ),
      ],
    );
  }

  String _lastSeenText() {
    if (user.lastSeen == null) return 'Desconectado';
    final diff = DateTime.now().difference(user.lastSeen!);
    if (diff.inMinutes < 1) return 'Visto hace un momento';
    if (diff.inMinutes < 60) return 'Visto hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Visto hace ${diff.inHours} h';
    return 'Visto hace ${diff.inDays} días';
  }
}
