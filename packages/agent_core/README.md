# agent_core

Nucleo do Hub Agent. **Dart puro, zero Flutter.**

O `pubspec.yaml` nao declara `flutter` de proposito: e o compilador que impede
alguem de importar um widget aqui. Esse e o unico motivo de o pacote existir
separado.

## Protocolo (canonico — o dashboard manda)

Prefixo: `nodes/{deviceId}`

| Topico                        | Retain | QoS | Direcao          | Payload |
|-------------------------------|--------|-----|------------------|---------|
| `nodes/{id}/status`           | sim    | 1   | agente -> tablet | `{online, os}` (tambem o LWT, com `{online:false}`) |
| `nodes/{id}/layout`           | sim    | 1   | agente -> tablet | `{deviceName, theme, pages}` |
| `nodes/{id}/audio/volume`     | sim    | 0   | agente -> tablet | `{value: 0-100}` int |
| `nodes/{id}/audio/apps`       | sim    | 0   | agente -> tablet | `[{id, name, volume}]` |
| `nodes/{id}/media`            | sim    | 0   | agente -> tablet | `{status, title, artist}` |
| `nodes/{id}/cmd`              | nao    | 1   | tablet -> agente | `{action, value?, app_id?}` |

## A decisao do `cmd`: bindings locais

O contrato canonico **nao tem campo `cmd` no tile** — o tablet so publica
`{action: <id>}`. Entao `Layout` tem duas serializacoes:

- `toPublishJson()` -> exatamente o contrato. Vai para o MQTT.
- `toDiskJson()`    -> contrato + `bindings`. Fica so no disco.

`bindings` mapeia `id de shortcut -> argv`. O `CommandDispatcher` resolve o id
recebido consultando esse mapa. Consequencia de seguranca: **uma mensagem MQTT
forjada nao consegue executar comando arbitrario**, so disparar ids que o
usuario ja autorizou no CMS. Se o `cmd` viajasse no layout, qualquer coisa com
acesso ao broker teria execucao remota no PC.

## Roteamento de acoes

```
action == play_pause | next | prev        -> MediaService (playerctl)
action == set_volume                      -> AudioController.setMasterVolume
action == set_app_volume (app_id, value)  -> AudioController.setAppVolume
action == run_shortcut (id)               -> binding[id] via Process.start
qualquer outra action                     -> tratada como id de shortcut
```

## Guarda de eco

`set_volume` vindo do tablet arma uma janela de 200ms em que o evento local do
`AudioController` e descartado. Sem isso: tablet manda 40 -> PC aplica -> PC
publica 40 -> tablet redesenha no meio do arrasto -> slider treme.

## Uso a partir do Flutter

```dart
final dir = await getApplicationSupportDirectory();
final runtime = AgentRuntime(
  repository: LayoutRepository(file: File('${dir.path}/layout.json')),
  mqtt: MqttService(host: '192.168.0.10', deviceId: 'meu-pc'),
);
await runtime.start(fallbackDeviceName: 'Meu PC');
```

No daemon, troque `path_provider` por `XDG_CONFIG_HOME`/`APPDATA`. Resto igual.

## Dependencias de sistema (Linux)

- `wpctl` + `pactl` (PipeWire / pipewire-pulse) — `pactl >= 16` para `-f json`
- `playerctl` — opcional; sem ele o modulo de media se desativa sozinho

## Testes

```
dart pub get
dart test
```

`test/contract_test.dart` trava o formato contra
`test/fixtures/layout_golden.json` (o payload real do seu `mosquitto_pub`).
Mudou o contrato? Mude o golden **primeiro**, e o dashboard junto.
