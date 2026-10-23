import 'dart:async';

import 'package:amigo_chat/services/chat_socket.dart';

/// Prueba de humo de la capa WebSocket real:
/// conecta dos instancias de [ChatSocket] (Amigo y Amiga) contra el
/// servidor puente y verifica el flujo de mensajes.
///
/// Requiere el servidor corriendo: `cd amigo_chat/servidor_ws && npm start`
/// Ejecutar con: `dart run tool/ws_probe.dart`
// ignore_for_file: avoid_print
Future<void> main() async {
  final failures = <String>[];
  void check(String name, bool cond) {
    print('${cond ? 'PASS' : 'FAIL'}  $name');
    if (!cond) failures.add(name);
  }

  Future<ChatEvent> nextEvent(ChatSocket s, String type) {
    final completer = Completer<ChatEvent>();
    final sub = s.events.listen((e) {
      if (e.type == type && !completer.isCompleted) completer.complete(e);
    });
    return completer.future
        .timeout(const Duration(seconds: 3), onTimeout: () => throw TimeoutException(type))
        .whenComplete(sub.cancel);
  }

  Future<void> untilConnected(ChatSocket s) {
    if (s.status == SocketStatus.connected) return Future.value();
    return s.onStatusChanged.firstWhere((st) => st == SocketStatus.connected)
        .timeout(const Duration(seconds: 5));
  }

  final amigo = ChatSocket(userId: 'amigo', name: 'Amigo');
  final amiga = ChatSocket(userId: 'amiga', name: 'Amiga');

  final amigoJoined = nextEvent(amigo, 'joined');
  final amigaJoined = nextEvent(amiga, 'joined');

  amigo.connect();
  amiga.connect();

  try {
    await Future.wait([untilConnected(amigo), untilConnected(amiga)]);
    check('ambas apps conectadas al servidor', true);

    await Future.wait([amigoJoined, amigaJoined]);
    check('ambas apps se unen a la sala (join)', true);

    // Amigo escribe -> Amiga lo recibe + ack de vuelta.
    final incoming = nextEvent(amiga, 'message');
    final ack = nextEvent(amigo, 'ack');
    amigo.send({
      'type': 'message',
      'id': 'amigo-probe-1',
      'text': 'Hola Amiga, ¿me recibes?',
      'timestamp': DateTime.now().toIso8601String(),
    });
    final received = await incoming;
    check('Amiga recibe el mensaje de Amigo', received.data['text'] == 'Hola Amiga, ¿me recibes?');
    check('el mensaje lleva el nombre del emisor', received.data['name'] == 'Amigo');
    check('Amigo recibe el ack', (await ack).data['messageId'] == 'amigo-probe-1');

    // Amiga confirma lectura -> Amigo marca leído.
    final read = nextEvent(amigo, 'read');
    amiga.send({'type': 'read', 'messageId': 'amigo-probe-1'});
    check('Amigo recibe la confirmación de lectura', (await read).data['messageId'] == 'amigo-probe-1');

    // Amiga responde.
    final answer = nextEvent(amigo, 'message');
    amiga.send({
      'type': 'message',
      'id': 'amiga-probe-1',
      'text': '¡Te recibo perfecto!',
      'timestamp': DateTime.now().toIso8601String(),
    });
    check('Amigo recibe la respuesta', (await answer).data['name'] == 'Amiga');

    // Indicador de escritura.
    final typing = nextEvent(amigo, 'typing');
    amiga.send({'type': 'typing'});
    await typing;
    check('Amigo ve "escribiendo..."', true);
  } on Object catch (e) {
    check('flujo general: $e', false);
  } finally {
    amigo.dispose();
    amiga.dispose();
  }

  print(failures.isEmpty ? '\nTODO OK' : '\n${failures.length} FALLOS');
  // Dar tiempo a que cierren los sockets antes de salir.
  await Future<void>.delayed(const Duration(milliseconds: 200));
  if (failures.isNotEmpty) throw StateError('Fallos: $failures');
}
