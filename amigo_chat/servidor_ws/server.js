const { WebSocketServer } = require('ws');
const PORT = 8080;
const wss = new WebSocketServer({ port: PORT });
const clients = new Map(); // userId => { ws, name }

console.log(`Servidor WebSocket iniciado en ws://localhost:${PORT}`);

wss.on('connection', (ws) => {
  
  let currentUserId = null;
  let currentUserName = null;

  ws.on('message', (rawData) => {
    let data;
    try {
      data = JSON.parse(rawData.toString());
    } catch (e) {
      ws.send(JSON.stringify({ type: 'error', message: 'JSON invalido' }));
      return;
    }

    switch (data.type) {
      case 'join': {
        currentUserId = data.userId;
        currentUserName = data.name ?? data.userId;
        clients.set(currentUserId, { ws, name: currentUserName });
        console.log(`[+] ${currentUserName} (${currentUserId}) conectado`);
        broadcast(currentUserId, {
          type: 'user_joined',
          userId: currentUserId,
          name: currentUserName,
          isOnline: true,
        });
        ws.send(JSON.stringify({
          type: 'joined',
          userId: currentUserId,
          name: currentUserName,
          peersOnline: getPeersStatus(currentUserId),
        }));
        break;
      }

      case 'message': {
        if (!currentUserId) {
          ws.send(JSON.stringify({ type: 'error', message: 'Envia join primero' }));
          return;
        }
        const msg = {
          type: 'message',
          userId: currentUserId,
          name: currentUserName,
          text: data.text,
          id: data.id ?? `${currentUserId}-${Date.now()}`,
          timestamp: data.timestamp ?? new Date().toISOString(),
        };
        console.log(`[msg] ${currentUserName}: ${data.text}`);
        broadcast(currentUserId, msg);
        ws.send(JSON.stringify({ type: 'ack', messageId: msg.id, status: 'sent' }));
        break;
      }
    


      case 'typing':
        broadcast(currentUserId, { type: 'typing', userId: currentUserId, name: currentUserName });
        break;

      case 'stop_typing':
        broadcast(currentUserId, { type: 'stop_typing', userId: currentUserId });
        break;

      case 'read':
        broadcast(currentUserId, { type: 'read', userId: currentUserId, messageId: data.messageId });
        break;

      default:
        ws.send(JSON.stringify({ type: 'error', message: `Tipo desconocido: ${data.type}` }));
    }
  });




  ws.on('close', () => {
    if (currentUserId) {
      clients.delete(currentUserId);
      console.log(`[-] ${currentUserName} (${currentUserId}) desconectado`);
      broadcast(currentUserId, {
        type: 'user_left',
        userId: currentUserId,
        name: currentUserName,
        isOnline: false,
      });
    }
  });

  ws.on('error', (err) => {
    console.error(`Error [${currentUserId}]:`, err.message);
  });
});

function broadcast(senderId, payload) {
  const json = JSON.stringify(payload);
  for (const [id, { ws }] of clients) {
    if (id !== senderId && ws.readyState === 1 /* OPEN */) {
      ws.send(json);
    }
  }
}

function getPeersStatus(requesterId) {
  return [...clients.entries()]
    .filter(([id]) => id !== requesterId)
    .map(([id, { name }]) => ({ userId: id, name, isOnline: true }));
}
