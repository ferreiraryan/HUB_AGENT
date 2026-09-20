# Hub Agent — Tablet (Dashboard)

Dashboard kiosk em HTML/JS vanilla que consome o estado publicado pelo
agente em `nodes/+/...` via MQTT sobre WebSocket.

## Como rodar (Termux / Linux)

Pré-requisitos:
  - Node.js (>= 18)
  - Mosquitto rodando com WebSocket nativo em `listener 9001`

Passos:
  1. npm install
  2. Ajuste o IP do mosquitto em `bridge.js` (constante MQTT_HOST)
  3. npm start
  4. Abra `http://localhost:8080` no navegador do tablet

## Contrato MQTT (resumo)

Assina:
  - nodes/+/status          → { online }
  - nodes/+/layout          → { deviceName, theme, pages }
  - nodes/+/audio/volume    → { value: 0..100 }
  - nodes/+/audio/apps      → [ { id, name, volume } ]
  - nodes/+/media           → { status, title, artist }

Publica:
  - nodes/{deviceId}/cmd    → { action, value?, app_id? }

O contrato completo está em `../packages/agent_core/test/fixtures/layout_golden.json`
e em `../README.md`.
