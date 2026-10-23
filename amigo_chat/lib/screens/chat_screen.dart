import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/message_model.dart';
import '../models/chat_user_model.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/date_separator.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/message_input_bar.dart';
import '../widgets/chat_app_bar.dart';

/// The main chat screen.
///
/// [messages]       — list of messages to display (managed externally via WebSocket)
/// [currentUser]    — the logged-in user
/// [remoteUser]     — the remote chat participant
/// [isRemoteTyping] — set to true when the remote user is typing (from WS event)
/// [onSendMessage]  — called when the user taps send; plug your WS send here
/// [onTyping]       — called when the local user types; send WS "typing" event here
class ChatScreen extends StatefulWidget {
  final List<Message> messages;
  final ChatUser currentUser;
  final ChatUser remoteUser;
  final bool isRemoteTyping;
  final ValueChanged<String> onSendMessage;
  final VoidCallback? onTyping;

  /// Optional banner (e.g. "connecting to server") shown above the input bar.
  final Widget? connectionBanner;

  const ChatScreen({
    super.key,
    required this.messages,
    required this.currentUser,
    required this.remoteUser,
    this.isRemoteTyping = false,
    required this.onSendMessage,
    this.onTyping,
    this.connectionBanner,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll when new messages arrive
    if (widget.messages.length != oldWidget.messages.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ChatAppBar(
        user: widget.remoteUser,
        isTyping: widget.isRemoteTyping,
        onVideoCall: () => _showFeatureSnack(context, 'Videollamada'),
        onVoiceCall: () => _showFeatureSnack(context, 'Llamada de voz'),
        onMoreOptions: () => _showOptionsSheet(context),
      ),
      body: Column(
        children: [
          // ─── Messages list ───────────────────────────────────────
          Expanded(
            child: widget.messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(),
          ),

          // ─── Typing indicator ────────────────────────────────────
          if (widget.isRemoteTyping)
            TypingIndicator(userName: widget.remoteUser.name),

          // ─── Connection banner (offline / connecting) ───────────
          if (widget.connectionBanner != null) widget.connectionBanner!,

          // ─── Input bar ───────────────────────────────────────────
          MessageInputBar(
            onSendMessage: widget.onSendMessage,
            onTyping: widget.onTyping,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    // Build items: insert DateSeparator between messages of different days
    final items = <Widget>[];
    DateTime? lastDate;

    for (int i = 0; i < widget.messages.length; i++) {
      final msg = widget.messages[i];
      final msgDate = DateTime(
        msg.timestamp.year,
        msg.timestamp.month,
        msg.timestamp.day,
      );

      if (lastDate == null || lastDate != msgDate) {
        items.add(DateSeparator(date: msg.timestamp));
        lastDate = msgDate;
      }

      // Determine if avatar should be shown (first message in a streak)
      final bool isLastInStreak = i == widget.messages.length - 1 ||
          widget.messages[i + 1].isMe != msg.isMe;

      items.add(
        ChatBubble(
          message: msg,
          showAvatar: isLastInStreak && !msg.isMe,
          onLongPress: () => _showMessageOptions(context, msg),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: items.length,
      itemBuilder: (_, index) => items[index],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '¡Di hola a ${widget.remoteUser.name}!',
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Empieza la conversación',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showFeatureSnack(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — próximamente 🚀'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _OptionTile(icon: Icons.search_rounded, label: 'Buscar mensajes'),
            _OptionTile(icon: Icons.notifications_off_rounded, label: 'Silenciar'),
            _OptionTile(icon: Icons.block_rounded, label: 'Bloquear usuario'),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Limpiar chat',
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _OptionTile(icon: Icons.reply_rounded, label: 'Responder'),
            _OptionTile(icon: Icons.copy_rounded, label: 'Copiar'),
            _OptionTile(icon: Icons.forward_rounded, label: 'Reenviar'),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Eliminar',
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple option tile for bottom sheets.
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _OptionTile({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: tileColor),
      title: Text(label, style: TextStyle(color: tileColor)),
      onTap: () => Navigator.pop(context),
    );
  }
}
