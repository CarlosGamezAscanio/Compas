# Compas
# COMPAS — Chat Amigo ⇄ Amiga por WebSocket

Dos apps Flutter (`amigo_chat` y `amiga_chat`) que chatean entre sí a través de
un servidor WebSocket puente.

```
COMPAS/
├── amigo_chat/                 ← app "Amigo"
│   ├── lib/
│   │   ├── services/chat_socket.dart   ← cliente WebSocket (compartido)
│   │   ├── main.dart                   ← identidad: amigo / amiga
│   │   └── screens/chat_screen.dart
│   ├── tool/ws_probe.dart              ← prueba de humo de la capa WS
│   └── servidor_ws/                    ← servidor puente (Node.js)
│       ├── server.js
│       ├── test_protocolo.js
│       └── package.json
└── amiga_chat/                 ← app "Amiga"
    ├── lib/services/chat_socket.dart
    └── lib/main.dart                   ← identidad: amiga / amigo
```

## Cómo levantarlo

**1. Servidor (una sola vez, queda corriendo):**

```powershell
cd C:\Users\PC\Desktop\COMPAS\amigo_chat\servidor_ws
npm install     # solo la primera vez
npm start       # escucha en ws://localhost:8080
```

**2. Las dos apps (dos terminales distintas):**

```powershell
# Terminal 1
cd C:\Users\PC\Desktop\COMPAS\amigo_chat
flutter run -d windows

# Terminal 2
cd C:\Users\PC\Desktop\COMPAS\amiga_chat
flutter run -d windows
```

Escribe en una ventana y aparece al instante en la otra. Se muestran el
indicador *escribiendo...*, los ticks ✓ / ✓✓ / ✓ azules (enviado / entregado /
leído) y el estado *En línea / Visto hace...*.

> Si arrancas las dos apps **antes** que el servidor, no pasa nada: cada app
> reintenta la conexión sola (1s, 2s, 4s... tope 10s). En pantalla verás el
> banner *Conectando con el servidor...* hasta que se establezca.

## Otras formas de correr

| Escenario | Comando |
|---|---|
| Emulador Android (misma máquina) | `flutter run` y servidor en `localhost` → la app usa `ws://localhost:8080`; si el emulador es el cliente, añade `--dart-define=WS_URL=ws://10.0.2.2:8080` |
| Dos móviles/PCs en la misma red | Arranca el servidor en una máquina y pasa la IP: `flutter run --dart-define=WS_URL=ws://192.168.1.50:8080` |
| Navegador web | `flutter run -d chrome` |

En Windows, si otra máquina debe conectarse, abre el puerto en el firewall:

```powershell
New-NetFirewallRule -DisplayName "COMPAS WebSocket" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
```

## Pruebas

```powershell
# Protocolo end-to-end contra el servidor (Node)
cd amigo_chat\servidor_ws
node test_protocolo.js

# Capa WebSocket real de Dart (dos clientes en un proceso)
cd amigo_chat
dart run tool/ws_probe.dart

# Tests y análisis de las dos apps
flutter analyze
flutter test
```

## Protocolo JSON

| Evento | Dirección | Payload |
|---|---|---|
| `join` | app → servidor | `{ userId, name }` |
| `joined` | servidor → app | `{ userId, name, peersOnline: [...] }` |
| `message` | app → servidor → la otra app | `{ id, text, timestamp }` (+ `userId`, `name` al reenviar) |
| `ack` | servidor → emisor | `{ messageId, status: 'sent' }` |
| `typing` / `stop_typing` | app → servidor → la otra app | `{ userId, name }` |
| `read` | app → servidor → la otra app | `{ messageId }` |
| `user_joined` / `user_left` | servidor → apps | `{ userId, name, isOnline }` |

Identidades fijas: `amigo` (app **Amigo**) y `amiga` (app **Amiga**).
