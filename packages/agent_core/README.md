# agent_core

Núcleo do Hub Agent. **Dart puro, zero Flutter.**

O `pubspec.yaml` não declara dependência do Flutter: o compilador garante que nenhum widget ou dependência de UI seja introduzida aqui.

## Protocolo MQTT

Prefixo canônico: `nodes/{deviceId}`

| Tópico                        | Retain | QoS | Direção          | Payload |
|-------------------------------|--------|-----|------------------|---------|
| `nodes/{id}/status`           | sim    | 1   | agente -> tablet | `{"online": bool, "os": "linux"\|"windows"}` (também o LWT, com `{"online": false}`) |
| `nodes/{id}/layout`           | sim    | 1   | agente -> tablet | `{"deviceName": "...", "theme": {...}, "pages": [...]}` |
| `nodes/{id}/audio/volume`     | sim    | 0   | agente -> tablet | `{"value": 0..100}` |
| `nodes/{id}/audio/apps`       | sim    | 0   | agente -> tablet | `[{"id": "...", "name": "...", "volume": 0..100}]` |
| `nodes/{id}/media`            | sim    | 0   | agente -> tablet | `{"status": "Playing"\|"Paused"\|"Stopped", "title": "...", "artist": "..."}` |
| `nodes/{id}/sound/state`      | sim    | 0   | agente -> tablet | `{"current_sound_id": "..."\|null, "is_playing": bool, ...}` |
| `nodes/{id}/state/{sliderId}` | sim    | 0   | agente -> tablet | `{"value": int}` |
| `nodes/{id}/stats/cpu`        | sim    | 0   | agente -> tablet | `{"load": int, "temp": int?, "freq_mhz": int?}` |
| `nodes/{id}/stats/ram`        | sim    | 0   | agente -> tablet | `{"used_mb": int, "total_mb": int, "percent": int}` |
| `nodes/{id}/stats/disk`       | sim    | 0   | agente -> tablet | `{"mount": "...", "used_gb": int, "total_gb": int, "percent": int}` |
| `nodes/{id}/cmd`              | não    | 1   | tablet -> agente | `{"action": "...", "value"?: int, "app_id"?: string}` |

## Bindings Locais e Segurança

O contrato canônico **não inclui comandos shell no payload do layout**:

- `toPublishJson()` -> Contrato público. Vai para o MQTT sem nenhuma chave de comando ou script.
- `toDiskJson()`    -> Representação local completa (`layout.json`) contendo os `bindings`.

`bindings` mapeia `tileId -> List<List<String>>` (argv). O `CommandDispatcher` resolve o ID recebido consultando esse mapa em memória.

## Testes

```bash
dart pub get
dart test
```
