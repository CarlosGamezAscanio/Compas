import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amigo_chat/main.dart';
import 'package:amigo_chat/services/chat_socket.dart';

void main() {
  // Sin red en los tests: evita timers/sockets pendientes del WebSocket.
  ChatSocket.debugDisableConnection = true;

  testWidgets('Chat app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AmigoApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
