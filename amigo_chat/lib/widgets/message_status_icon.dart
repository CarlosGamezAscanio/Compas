import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/message_model.dart';

/// Widget that displays the message status icon (✓ ✓✓ etc.)
class MessageStatusIcon extends StatelessWidget {
  final MessageStatus status;
  final Color color;

  const MessageStatusIcon({
    super.key,
    required this.status,
    this.color = AppColors.sent,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: color,
          ),
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: color);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 14, color: AppColors.read);
      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: Colors.red);
    }
  }
}
