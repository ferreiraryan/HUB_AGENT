cat > README.md <<'EOF'
# Hub Agent

Agente de automação residencial / produtividade: um PC publica estado
(layout de atalhos, áudio, mídia) via MQTT, e um tablet kiosk renderiza
um dashboard touch. Um editor visual (Flutter) permite montar o layout.

## Estrutura
packages/agent_core/ — Dart puro (modelos, MQTT, áudio, mídia). Zero Flutter.
apps/cms_app/ — Editor visual Flutter (three-pane: páginas / preview / inspector).
tablet/ — Dashboard web (HTML/JS vanilla) + bridge WebSocket→MQTT.

## Contrato

O agente publica em `nodes/{deviceId}/...` com retain.
O tablet assina `nodes/+/...` (auto-discovery) e publica comandos em
`nodes/{deviceId}/cmd`.

Ver `packages/agent_core/test/contract_test.dart` para o contrato canônico.

## Como rodar

### Broker
```sh
sudo systemctl start mosquitto
# Config mínima:
#   listener 1883
#   allow_anonymous true
#   listener 9001
#   protocol websockets
#   allow_anonymous true
