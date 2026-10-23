import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Estado de la conexión con el servidor WebSocket puente.
enum SocketStatus { disconnected, connecting, connected }

/// Evento JSON recibido del servidor (`{ type: ..., ...resto }`).
class ChatEvent {
  const ChatEvent(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;
}

/// Cliente WebSocket que conecta esta app con `servidor_ws/server.js`
/// para que Amigo y Amiga chateen entre sí.
///
/// Uso:
/// ```dart
/// final socket = ChatSocket(userId: 'amigo', name: 'Amigo');
/// socket.onStatusChanged.listen((s) => print(s));
/// socket.events.listen((e) => print(e.type));
/// socket.connect();
/// socket.send({'type': 'message', 'text': 'Hola'});
/// socket.dispose();
/// ```
class ChatSocket {
  ChatSocket({
    required this.userId,
    required this.name,
    String? serverUrl,
  }) : serverUrl = serverUrl ?? defaultServerUrl;

  /// Para tests: si es `true`, [connect] no abre conexión alguna
  /// (evita timers/red pendientes en los widget tests).
  static bool debugDisableConnection = false;

  /// URL del servidor. Se cambia en tiempo de compilación con:
  /// `flutter run --dart-define=WS_URL=ws://192.168.1.50:8080`
  static const String defaultServerUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8080',
  );

  final String userId;
  final String name;
  final String serverUrl;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _retryAttempt = 0;
  bool _disposed = false;
  SocketStatus _status = SocketStatus.disconnected;

  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();
  final StreamController<SocketStatus> _statusController =
      StreamController<SocketStatus>.broadcast();

  /// Eventos entrantes: message, typing, stop_typing, read, ack,
  /// user_joined, user_left, joined, error.
  Stream<ChatEvent> get events => _events.stream;

  /// Cambios de estado de la conexión.
  Stream<SocketStatus> get onStatusChanged => _statusController.stream;

  /// Estado actual de la conexión.
  SocketStatus get status => _status;

  /// Abre la conexión y se une a la sala. Reintenta solo si se cae.
  void connect() {
    if (_disposed || debugDisableConnection) return;
    _reconnectTimer?.cancel();
    _setStatus(SocketStatus.connecting);

    final channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    _channel = channel;

    _subscription = channel.stream.listen(
      _onMessage,
      onDone: () => _handleDisconnect(channel),
      onError: (_) => _handleDisconnect(channel),
      cancelOnError: true,
    );

    channel.ready.then((_) {
      if (_disposed || _channel != channel) return;
      _retryAttempt = 0;
      _setStatus(SocketStatus.connected);
      // El servidor necesita saber quién es este cliente.
      _send({'type': 'join', 'userId': userId, 'name': name});
    }).catchError((_) => _handleDisconnect(channel));
  }

  /// Envía un payload JSON al servidor. No hace nada si no está conectado.
  void send(Map<String, dynamic> payload) => _send(payload);

  void _send(Map<String, dynamic> payload) {
    if (_disposed || _status != SocketStatus.connected) return;
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(payload));
    } catch (_) {
      // El reconnect se encarga del resto.
    }
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map<String, dynamic>) return;
      data = decoded;
    } catch (_) {
      return;
    }
    final type = data['type'];
    if (type is! String) return;
    _events.add(ChatEvent(type, data));
  }

  void _handleDisconnect(WebSocketChannel channel) {
    if (_disposed || _channel != channel) return;
    _channel = null;
    _subscription?.cancel();
    _subscription = null;
    _setStatus(SocketStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    // 1s, 2s, 4s, 8s... tope 10s.
    final seconds = [1, 2, 4, 8, 10][_retryAttempt.clamp(0, 4)];
    _retryAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), connect);
  }

  void _setStatus(SocketStatus next) {
    if (_disposed || _status == next) return;
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  /// Cierra la conexión y libera los recursos. No se reconecta más.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    try {
      channel?.sink.close();
    } catch (_) {}
    if (!_statusController.isClosed) _statusController.close();
    if (!_events.isClosed) _events.close();
  }
}
