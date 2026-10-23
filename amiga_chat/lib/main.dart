import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/message_model.dart';
import 'models/chat_user_model.dart';
import 'screens/chat_screen.dart';
import 'services/chat_socket.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const AmigaApp());
}

class AmigaApp extends StatelessWidget {
  const AmigaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amiga Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const ChatDemoWrapper(),
    );
  }
}

/// Chat conectado por WebSocket al servidor puente (`amigo_chat/servidor_ws/server.js`).
/// Esta app entra como **Amiga** y habla con **Amigo**.
class ChatDemoWrapper extends StatefulWidget {
  const ChatDemoWrapper({super.key});

  @override
  State<ChatDemoWrapper> createState() => _ChatDemoWrapperState();
}

class _ChatDemoWrapperState extends State<ChatDemoWrapper> {
  // ──────────────────────────────────────────────────────────────────────────
  // Identidades (deben coincidir con las del otro lado del puente)
  // ──────────────────────────────────────────────────────────────────────────
  static const ChatUser _me = ChatUser(
    id: 'amiga',
    name: 'Amiga',
    isOnline: true,
  );

  ChatUser _remote = const ChatUser(
    id: 'amigo',
    name: 'Amigo',
    isOnline: false,
    statusMessage: 'Conectando...',
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Capa WebSocket
  // ──────────────────────────────────────────────────────────────────────────
  late final ChatSocket _socket;

  SocketStatus _socketStatus = SocketStatus.connecting;

  // ──────────────────────────────────────────────────────────────────────────
  // Estado de la UI
  // ──────────────────────────────────────────────────────────────────────────
  final List<Message> _messages = [];
  bool _isRemoteTyping = false;

  Timer? _remoteTypingTimer;
  Timer? _stopTypingTimer;
  DateTime? _lastTypingSent;

  @override
  void initState() {
    super.initState();
    _socket = ChatSocket(userId: _me.id, name: _me.name);
    _socket.onStatusChanged.listen(_onStatusChanged);
    _socket.events.listen(_onEvent);
    _socket.connect();
  }

  @override
  void dispose() {
    _remoteTypingTimer?.cancel();
    _stopTypingTimer?.cancel();
    _socket.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Conexión
  // ──────────────────────────────────────────────────────────────────────────
  void _onStatusChanged(SocketStatus status) {
    if (!mounted) return;
    setState(() {
      _socketStatus = status;
      if (status != SocketStatus.connected) {
        _isRemoteTyping = false;
        _remote = _remote.copyWith(isOnline: false, lastSeen: DateTime.now());
      }
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Eventos entrantes del servidor
  // ──────────────────────────────────────────────────────────────────────────
  void _onEvent(ChatEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case 'joined':
        final peers = (event.data['peersOnline'] as List?) ?? const [];
        final online =
            peers.any((p) => p is Map && p['userId'] == _remote.id);
        setState(() => _remote = _remote.copyWith(isOnline: online));
        break;

      case 'user_joined':
        if (event.data['userId'] == _remote.id) {
          setState(() {
            _remote = _remote.copyWith(
              name: (event.data['name'] as String?) ?? _remote.name,
              isOnline: true,
            );
          });
        }
        break;

      case 'user_left':
        if (event.data['userId'] == _remote.id) {
          setState(() {
            _remote = _remote.copyWith(
              isOnline: false,
              lastSeen: DateTime.now(),
            );
          });
        }
        break;

      case 'message':
        _onIncomingMessage(event.data);
        break;

      case 'ack':
        _updateStatus(event.data['messageId'], MessageStatus.sent);
        break;

      case 'read':
        _updateStatus(event.data['messageId'], MessageStatus.read);
        break;

      case 'typing':
        if (event.data['userId'] == _remote.id) _showRemoteTyping();
        break;

      case 'stop_typing':
        if (event.data['userId'] == _remote.id) _hideRemoteTyping();
        break;
    }
  }

  void _onIncomingMessage(Map<String, dynamic> data) {
    final text = data['text'];
    if (text is! String || text.isEmpty) return;

    final incoming = Message(
      id: (data['id'] as String?) ?? 'msg-${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      isMe: false,
      timestamp: DateTime.tryParse((data['timestamp'] as String?) ?? '') ??
          DateTime.now(),
      status: MessageStatus.delivered,
      senderName: (data['name'] as String?) ?? _remote.name,
    );

    setState(() {
      _messages.add(incoming);
      _isRemoteTyping = false;
    });
    _remoteTypingTimer?.cancel();

    // Confirmamos lectura: el servidor se lo notifica al que escribió.
    _socket.send({'type': 'read', 'messageId': incoming.id});
  }

  void _updateStatus(Object? messageId, MessageStatus status) {
    if (messageId is! String) return;
    var changed = false;
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.id == messageId && m.status != status) {
        _messages[i] = m.copyWith(status: status);
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Indicador "escribiendo..."
  // ──────────────────────────────────────────────────────────────────────────
  void _showRemoteTyping() {
    _remoteTypingTimer?.cancel();
    if (!_isRemoteTyping) setState(() => _isRemoteTyping = true);
    _remoteTypingTimer = Timer(const Duration(seconds: 3), _hideRemoteTyping);
  }

  void _hideRemoteTyping() {
    _remoteTypingTimer?.cancel();
    _remoteTypingTimer = null;
    if (_isRemoteTyping && mounted) setState(() => _isRemoteTyping = false);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Salidas
  // ──────────────────────────────────────────────────────────────────────────
  void _handleSend(String text) {
    final now = DateTime.now();
    final newMsg = Message(
      id: '${_me.id}-${now.microsecondsSinceEpoch}',
      text: text,
      isMe: true,
      timestamp: now,
      status: _socketStatus == SocketStatus.connected
          ? MessageStatus.sending
          : MessageStatus.failed,
    );

    setState(() {
      _messages.add(newMsg);
      _isRemoteTyping = false;
    });
    _remoteTypingTimer?.cancel();

    _sendStopTyping();

    if (_socketStatus != SocketStatus.connected) return;

    _socket.send({
      'type': 'message',
      'id': newMsg.id,
      'text': text,
      'timestamp': now.toIso8601String(),
    });
  }

  void _handleTyping() {
    final now = DateTime.now();
    final last = _lastTypingSent;
    if (last == null || now.difference(last) > const Duration(seconds: 1)) {
      _lastTypingSent = now;
      _socket.send({'type': 'typing'});
    }
    _stopTypingTimer?.cancel();
    _stopTypingTimer = Timer(const Duration(seconds: 2), _sendStopTyping);
  }

  void _sendStopTyping() {
    _stopTypingTimer?.cancel();
    _stopTypingTimer = null;
    _lastTypingSent = null;
    _socket.send({'type': 'stop_typing'});
  }

  // ──────────────────────────────────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ChatScreen(
      messages: _messages,
      currentUser: _me,
      remoteUser: _remote,
      isRemoteTyping: _isRemoteTyping,
      onSendMessage: _handleSend,
      onTyping: _handleTyping,
      connectionBanner:
          _socketStatus == SocketStatus.connected ? null : _buildBanner(),
    );
  }

  Widget _buildBanner() {
    final connecting = _socketStatus == SocketStatus.connecting;
    return Material(
      color: AppColors.primaryLight.withAlpha(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (connecting) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              const SizedBox(width: 8),
            ] else ...[
              const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.red),
              const SizedBox(width: 8),
            ],
            Text(
              connecting
                  ? 'Conectando con el servidor...'
                  : 'Sin conexión — reintentando...',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
