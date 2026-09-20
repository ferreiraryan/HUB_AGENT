const http = require('http');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');
const net = require('net');

// --- 1. SERVIDOR HTTP ESTÁTICO (Porta 8080) ---
const HTTP_PORT = 8080;
// Assume que bridge.js está na home (~) e os arquivos em ~/dashboard
const PUBLIC_DIR = path.join(__dirname, 'dashboard');

const mimeTypes = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.ico': 'image/x-icon',
  '.json': 'application/json'
};

const server = http.createServer((req, res) => {
  let filePath = path.join(PUBLIC_DIR, req.url === '/' ? 'index.html' : req.url);
  let extname = String(path.extname(filePath)).toLowerCase();
  let contentType = mimeTypes[extname] || 'application/octet-stream';

  fs.readFile(filePath, (error, content) => {
    if (error) {
      if (error.code == 'ENOENT') {
        res.writeHead(404);
        res.end('Arquivo não encontrado: ' + req.url);
      } else {
        res.writeHead(500);
        res.end('Erro interno: ' + error.code);
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content, 'utf-8');
    }
  });
});

server.listen(HTTP_PORT, () => {
  console.log(`[+] Servidor HTTP servindo '${PUBLIC_DIR}' na porta ${HTTP_PORT}`);
});

// --- 2. WEBSOCKET BRIDGE (Porta 9001 -> 1883) ---
const WS_PORT = 9001;
const MQTT_PORT = 1883;

const wss = new WebSocket.Server({ port: WS_PORT });

wss.on('connection', function connection(ws, req) {
  const clientIp = req.socket.remoteAddress;
  console.log(`[*] Novo cliente WebSocket conectado de ${clientIp}`);

  const tcp = net.connect({ port: MQTT_PORT, host: '127.0.0.1' }, () => {
    console.log('[*] Tunel TCP com Mosquitto estabelecido');
  });

  ws.on('message', function incoming(message) {
    tcp.write(message);
  });

  tcp.on('data', function(data) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(data);
    }
  });

  ws.on('close', function() {
    console.log('[-] WebSocket desconectado');
    tcp.end();
  });

  tcp.on('close', function() {
    console.log('[-] Socket TCP fechado');
    if (ws.readyState === WebSocket.OPEN) {
      ws.close();
    }
  });

  ws.on('error', (err) => console.error('[!] Erro no WS:', err));
  tcp.on('error', (err) => console.error('[!] Erro no TCP:', err));
});

console.log(`[+] WebSocket Bridge ativo na porta ${WS_PORT} -> TCP ${MQTT_PORT}`);
