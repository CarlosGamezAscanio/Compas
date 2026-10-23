import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/message_model.dart';
import 'message_status_icon.dart';

/// A single chat bubble widget, supporting both sent and received messages.
class ChatBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final bool showSenderName;
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.message,
    this.showAvatar = false,
    this.showSenderName = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: message.isMe ? 60 : 8,
          right: message.isMe ? 8 : 60,
          top: 2,
          bottom: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar for received messages
            if (!message.isMe && showAvatar) ...[
              _buildAvatar(),
              const SizedBox(width: 6),
            ] else if (!message.isMe && !showAvatar) ...[
              const SizedBox(width: 32),
            ],

            // Bubble
            Flexible(
              child: GestureDetector(
                onLongPress: onLongPress,
                child: _buildBubble(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.primaryLight,
      backgroundImage: message.senderAvatar != null
          ? NetworkImage(message.senderAvatar!)
          : null,
      child: message.senderAvatar == null
          ? Text(
              (message.senderName ?? 'U').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildBubble(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: message.isMe ? AppColors.myBubble : AppColors.otherBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(message.isMe ? 18 : 4),
          bottomRight: Radius.circular(message.isMe ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender name (group chats)
            if (showSenderName && !message.isMe && message.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),

            // Message text
            Text(
              message.text,
              style: message.isMe
                  ? AppTextStyles.messageMy
                  : AppTextStyles.messageOther,
            ),

            const SizedBox(height: 4),

            // Timestamp + status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: message.isMe
                        ? Colors.white.withAlpha(179)
                        : AppColors.textHint,
                  ),
                ),
                if (message.isMe) ...[
                  const SizedBox(width: 4),
                  MessageStatusIcon(
                    status: message.status,
                    color: Colors.white.withAlpha(179),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
