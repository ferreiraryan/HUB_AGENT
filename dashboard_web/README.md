# Hub Agent — Tablet (Dashboard)

Dashboard kiosk vanilla (HTML5, CSS3, JavaScript puro) que consome o estado publicado pelo agente em `nodes/+/...` via MQTT sobre WebSocket. Otimizado para tablets com versões legadas do Android (Android 5/6).

## Como Executar no Tablet (Termux)

### Pré-requisitos
```bash
pkg install mosquitto python
```

### Inicialização
Copie os arquivos para a pasta `~/dashboard/` e execute:
```bash
bash ~/start-tablet.sh
```

O script inicia o Mosquitto (portas 1883 TCP e 9001 WebSocket) e o servidor HTTP em background na porta 8080. Em seguida, acesse no navegador:
```text
http://127.0.0.1:8080
```

## Tópicos MQTT Consumidos

### Assina:
- `nodes/+/status`
- `nodes/+/layout`
- `nodes/+/audio/volume`
- `nodes/+/audio/apps`
- `nodes/+/media`
- `nodes/+/sound/state`
- `nodes/+/state/+`
- `nodes/+/stats/cpu`
- `nodes/+/stats/ram`
- `nodes/+/stats/disk`

### Publica:
- `nodes/{deviceId}/cmd`
