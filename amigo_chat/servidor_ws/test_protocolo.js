// Prueba rápida del protocolo: simula a Amigo y Amiga conectándose al servidor.
const WebSocket = require('ws');

const URL = 'ws://localhost:8080';
const results = [];
const ok = (name, cond) => { results.push([cond ? 'PASS' : 'FAIL', name]); };

function client(userId, name) {
  const ws = new WebSocket(URL);
  const inbox = [];
  ws.on('message', (d) => inbox.push(JSON.parse(d.toString())));
  return {
    ws, inbox,
    send: (obj) => ws.send(JSON.stringify(obj)),
    open: () => new Promise((r) => ws.on('open', r)),
    waitFor: async (type, ms = 2000) => {
      const start = Date.now();
      while (Date.now() - start < ms) {
        const found = inbox.find((m) => m.type === type);
        if (found) return found;
        await new Promise((r) => setTimeout(r, 25));
      }
      return null;
    },
  };
}

(async () => {
  const a = client('amigo', 'Amigo');
  const b = client('amiga', 'Amiga');
  await Promise.all([a.open(), b.open()]);

  // 1. join
  a.send({ type: 'join', userId: 'amigo', name: 'Amigo' });
  b.send({ type: 'join', userId: 'amiga', name: 'Amiga' });
  const joinedA = await a.waitFor('joined');
  const joinedB = await b.waitFor('joined');
  ok('amigo recibe joined', !!joinedA);
  ok('amiga recibe joined', !!joinedB);
  // El segundo en entrar ve al primero en peersOnline; el primero recibe user_joined.
  const peerKnownToA = joinedA?.peersOnline?.some((p) => p.userId === 'amiga')
    || !!await a.waitFor('user_joined');
  const peerKnownToB = joinedB?.peersOnline?.some((p) => p.userId === 'amigo')
    || !!await b.waitFor('user_joined');
  ok('amigo conoce a amiga', peerKnownToA);
  ok('amiga conoce a amigo', peerKnownToB);

  // 2. mensaje de amigo -> amiga
  a.send({ type: 'message', id: 'amigo-1', text: 'Hola Amiga!', timestamp: new Date().toISOString() });
  const msgB = await b.waitFor('message');
  ok('amiga recibe el mensaje', msgB?.text === 'Hola Amiga!' && msgB?.name === 'Amigo');
  const ackA = await a.waitFor('ack');
  ok('amigo recibe ack', ackA?.messageId === 'amigo-1' && ackA?.status === 'sent');

  // 3. amiga confirma lectura -> amigo marca read
  b.send({ type: 'read', messageId: 'amigo-1' });
  const readA = await a.waitFor('read');
  ok('amigo recibe read', readA?.messageId === 'amigo-1');

  // 4. respuesta de amiga -> amigo
  b.send({ type: 'message', id: 'amiga-1', text: 'Hola Amigo!!', timestamp: new Date().toISOString() });
  const msgA = await a.waitFor('message');
  ok('amigo recibe la respuesta', msgA?.text === 'Hola Amigo!!' && msgA?.name === 'Amiga');

  // 5. typing
  b.send({ type: 'typing' });
  const typingA = await a.waitFor('typing');
  ok('amigo ve que amiga escribe', typingA?.userId === 'amiga');
  b.send({ type: 'stop_typing' });
  const stopA = await a.waitFor('stop_typing');
  ok('amigo ve que amiga deja de escribir', !!stopA);

  // 6. desconexión -> user_left
  b.ws.close();
  const left = await a.waitFor('user_left');
  ok('amigo ve que amiga se desconecta', left?.userId === 'amiga' && left?.isOnline === false);

  a.ws.close();

  for (const [status, name] of results) console.log(`${status}  ${name}`);
  const failed = results.filter(([s]) => s === 'FAIL').length;
  console.log(failed === 0 ? '\nTODO OK' : `\n${failed} FALLOS`);
  process.exit(failed === 0 ? 0 : 1);
})();
