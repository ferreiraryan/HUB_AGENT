# CONTEXT.md — Hub Agent

Documento de contexto arquitetural e operacional para modelos de IA e desenvolvedores.
Atualizado e conferido contra o código real do repositório em 19/10/2026.
Leia também [AGENT.md](./AGENT.md) e [AGENTS.md](./AGENTS.md).

---

## 1. Visão Geral e Topologia

O **Hub Agent** é um ecossistema de controle e automação local distribuído baseado no padrão **Hub & Spoke** sobre **MQTT**, sem dependência de nuvem.

### Topologia do Sistema:
1. **Kiosk (Hub - Tablet Android com Termux):**
   - Executa o broker MQTT **Mosquitto** com suporte a TCP (porta `1883`) e WebSocket nativo (porta `9001`).
   - Serve os arquivos estáticos de **`dashboard_web/`** em HTTP (porta `8080`) via script `start-tablet.sh`.
   - Navegador kiosk ou WebView no tablet exibe a UI conectada via WebSocket ao Mosquitto local.
2. **Host (Spoke / Satélite - PC Windows ou Linux):**
   - Executa o **`apps/cms_app`** (Flutter Desktop) com suporte a inicialização oculta (`--hidden`), minimização para bandeja do sistema (tray) e autostart no boot.
   - Instancia o **`AgentRuntime`** (provido por **`packages/agent_core`**), que executa comandos do sistema (áudio, mídia, teclas, brilho, estatísticas de hardware, soundpad) e sincroniza estado via MQTT.

```text
+------------------------------------------------------------------------+
| TABLET ANDROID (Kiosk / Hub)                                           |
|   - Mosquitto Broker (TCP: 1883, WS: 9001)                             |
|   - HTTP Server (Porta 8080 via Termux: start-tablet.sh)              |
|   - Browser Kiosk: dashboard_web (conecta via ws://127.0.0.1:9001)     |
+------------------------------------------------------------------------+
                               ▲
                 MQTT via LAN  │ (TCP 1883)
                               ▼
+------------------------------------------------------------------------+
| COMPUTADOR HOST (Spoke - Windows / Linux)                              |
|   - apps/cms_app (Flutter Desktop: UI de edição de layout e tray)      |
|   - packages/agent_core (Dart puro: AgentRuntime, MqttService)         |
|   - Executores locais:                                                 |
|       * Windows: hub_audio_helper.exe (WASAPI), nircmd.exe, powershell |
|       * Linux: wpctl, pactl, playerctl, wtype (Wayland), xdotool, ydotool, ddcutil, paplay |
+------------------------------------------------------------------------+
```

---

## 2. Componentes do Monorepo

- **`packages/agent_core`**:
  - Pacote Dart puro (**proibido importar Flutter**).
  - Gerencia o modelo de domínio (`Layout`, `Tile`, `HubTheme`, `AudioState`, `MediaState`, `SoundPlaybackState`, `StatsSnapshot`).
  - `LayoutRepository`: lê e salva `layout.json` no disco local com debounce de 400 ms e sincronização em stream.
  - `MqttService`: comunicação com o broker Mosquitto; publica todas as telemetrias com flag `retain: true`.
  - `CommandDispatcher`: recebe comandos do MQTT e despacha para serviços locais protegidos por validação em memória.
  - Provedores de serviços: áudio, mídia, teclas (`KeySender`), brilho, mesa de sons (`SoundController`) e estatísticas de hardware.
- **`apps/cms_app`**:
  - Aplicação Flutter desktop (Windows e Linux).
  - Editor visual WYSIWYG de telas, botões, sliders, cards de estatística, temas e atalhos.
  - Gerenciamento de autostart e configurações do broker (`broker_settings_dialog.dart`).
  - Biblioteca gerenciada de sons (`SoundLibraryRepository`) em `<appSupport>/sounds`.
  - Recursos empacotados no runner Windows: `hub_audio_helper.exe` e `nircmd.exe` em `windows/runner/resources/`.
- **`dashboard_web`**:
  - Frontend SPA vanilla (HTML5, CSS3, JavaScript puro) leve e resiliente para o tablet Android.
  - Conecta diretamente ao Mosquitto via WebSocket usando `mqtt.min.js`.
  - Otimizado e compatível com WebViews legadas (Android 5/6 Lollipop/Marshmallow).

---

## 3. Contrato MQTT Canônico

O prefixo canônico de todos os tópicos de um nó é:
```text
nodes/{deviceId}/
```

### Publicações do Agente (Host -> Tablet):

| Tópico | Payload | QoS / Retain | Descrição |
| :--- | :--- | :--- | :--- |
| `status` | `{"online": bool, "os": "linux"\|"windows"}` | Retained / QoS 1 | Presença do agente (LWT envia `{"online": false}`). |
| `layout` | `{"deviceName": "...", "theme": {...}, "pages": [...]}` | Retained / QoS 1 | Estrutura de telas, temas e botões para o tablet. |
| `audio/volume` | `{"value": 0..100}` | Retained / QoS 0 | Volume master do sistema. |
| `audio/apps` | `[{"id": "...", "name": "...", "volume": 0..100}]` | Retained / QoS 0 | Mixer de apps (Linux e Windows). |
| `media` | `{"status": "Playing"\|"Paused"\|"Stopped", "title": "...", "artist": "..."}` | Retained / QoS 0 | Faixa em reprodução (status capitalizado). |
| `sound/state` | `{"current_sound_id": "id"\|null, "is_playing": bool, "playing": "id"\|null, "status": "playing"\|"idle"}` | Retained / QoS 0 | Estado em tempo real do Sound Pad. |
| `state/{sliderId}` | `{"value": int}` | Retained / QoS 0 | Estado atual de um slider (publicado para brilho). |
| `stats/cpu` | `{"load": int, "temp": int?, "freq_mhz": int?}` | Retained / QoS 0 | Estatísticas de CPU do PC. |
| `stats/ram` | `{"used_mb": int, "total_mb": int, "percent": int}` | Retained / QoS 0 | Uso de memória RAM. |
| `stats/disk` | `{"mount": "...", "used_gb": int, "total_gb": int, "percent": int}` | Retained / QoS 0 | Uso do disco principal. |

### Comandos Recebidos (Tablet -> Host):
Tópico de subscrição do agente: `nodes/{deviceId}/cmd`

O tablet dispara comandos em formato JSON. Formatos reconhecidos:
```json
{"action": "play_pause"}
{"action": "next"}
{"action": "prev"}
{"action": "set_volume", "value": 75}
{"action": "set_app_volume", "app_id": "spotify", "value": 50}
{"action": "set_slider", "id": "slider_id", "value": 40}
{"action": "play_sound", "sound_id": "sound_id"}
{"action": "stop_sound"}
{"action": "run_shortcut", "id": "shortcut_id"}
{"action": "<tile_id>"}
```
> [!NOTE]
> **Ação Direta por Tile ID:** O tablet envia `{"action": "<tile_id>"}` diretamente ao clicar em atalhos e sons. No despachante (`CommandDispatcher`), se a ação não for uma ação interna pré-definida, ele primeiro verifica se o ID corresponde a um `SoundTile` (acionando toggle de som) ou a um `ShortcutTile` (executando o binding associado no PC).

> [!IMPORTANT]
> **A Regra de Ouro da Segurança e o Golden Test:**
> - O layout publicado (`Layout.toPublishJson()`) contém **apenas** `deviceName`, `theme` e `pages`.
> - **NUNCA** inclua `bindings` (comandos shell, atalhos de teclado locais, `cmd` de slider custom) no payload MQTT. O tablet apenas envia o ID da ação; a resolução de comandos é feita exclusivamente em memória pelo `CommandDispatcher` no PC a partir do `toDiskJson()`.
> - Esse contrato é validado estritamente em `packages/agent_core/test/contract_test.dart` e `contract_extra_test.dart`.

---

## 4. Estado Funcional por Plataforma e Assimetrias

| Recurso | Linux | Windows |
| :--- | :--- | :--- |
| **Volume Master** | `wpctl` por evento (`pactl subscribe` com debounce de 60ms) | `hub_audio_helper.exe` (WASAPI nativo) com polling de 1000ms. Fallback `nircmd.exe`. |
| **Mixer por App** | `pactl -f json list sink-inputs` | `hub_audio_helper.exe` enumera sessões ativas WASAPI por PID e nome de processo. |
| **Controle de Mídia** | `playerctl` (MPRIS via D-Bus). | `nircmd.exe sendkeypress` (`0xB3`, `0xB0`, `0xB1`). |
| **Metadados de Mídia** | Lê título, artista e status real via `playerctl metadata`. | **Não publica metadados** (status permanece `Stopped`). |
| **Atalhos de Teclado** | `LinuxKeySender` via `wtype` (Wayland / Hyprland) com fallback para `ydotool` e `xdotool` (X11). | `WindowsKeySender` via `nircmd.exe sendkeypress`. |
| **Controle de Brilho**| `LinuxBrightnessController` via `ddcutil`. | Não suportado (`UnsupportedBrightnessController`). |
| **Estatísticas** | Leitura de `/proc/stat`, `/proc/meminfo`, `/proc/cpuinfo`, thermal zones e `df -B1 /`. | PowerShell CIM (`Win32_Processor`, `Win32_OperatingSystem`, `Win32_LogicalDisk`). Sem temp/freq. |
| **Sound Pad** | `paplay` (suporta `--volume` e `-d <sink>`). Enumera sinks via `pactl list sinks short`. | `hub_audio_helper.exe play-sound` (WASAPI + Media Foundation com controle de volume) e `list-devices`. |
| **Execução de Comandos** | Subprocessos com `runInShell: false`. | Subprocessos com `runInShell: true` nos bindings. |
| **Instância Única** | Socket TCP loopback em `127.0.0.1:45871`. | Lock de arquivo exclusivo `cms_app.lock` em `<appSupport>`. |

### Tablet Android (Dashboard Kiosk):
- O tablet roda versões antigas do Android (5/6 Lollipop/Marshmallow).
- Código em `dashboard_web/app.js` estritamente compatível: sem sintaxes ES modernas (`?.`, `??`, default params).
- Fonte `Noto Color Emoji` como fallback no `style.css` e conversão de nomes do Material Icons via `ICON_MAP`.
- Feedback em tempo real com realce (`accent-glow`), pulso e equalizador animado para o som em reprodução.
- Painel de debug na base da tela (`#debug-log`) ativado via `window.logMsg` e `window.onerror`.

---

## 5. Decisões Arquiteturais Inegociáveis

1. **Separação de Camadas**: `packages/agent_core` é agnóstico de UI e independente de Flutter.
2. **Processos Externos no Windows**: Manter `hub_audio_helper.exe` e `nircmd.exe` isolados como processos externos. FFI/COM direto no processo Dart causou corrupção de memória e use-after-free em finalizers.
3. **Segurança de Execução**: Comandos disparados pelo tablet devem ter correspondência prévia e explícita no `layout.json` local. Sliders customizados usam bindings locais indexados pelo ID do slider.
4. **Debounce de Layout**: Há debounce de 400 ms no editor do CMS e mais 400 ms no `LayoutRepository`.
5. **Autostart no Windows**: O CMS utiliza `launch_at_startup` com flag `--hidden` para iniciar na bandeja do sistema sem abrir a janela.

---

## 6. Ambiente de Execução e Desenvolvimento

### 1. Agent Core (Testes Unitários e de Contrato):
```bash
# Linux
cd packages/agent_core && dart test

# Windows (PowerShell)
cd packages/agent_core
& "C:\Users\ryck3\flutter-sdk\flutter\bin\dart.bat" test
```

### 2. CMS App (Desktop):
```bash
# Linux
cd apps/cms_app && flutter pub get && flutter run -d linux

# Windows (PowerShell)
cd apps/cms_app
& "C:\Users\ryck3\flutter-sdk\flutter\bin\flutter.bat" pub get
& "C:\Users\ryck3\flutter-sdk\flutter\bin\flutter.bat" run -d windows
```

### 3. Dashboard Web no Tablet (Produção via Termux):
O script `dashboard_web/start-tablet.sh` inicia o Mosquitto (portas TCP 1883 e WS 9001) e o servidor HTTP Python (porta 8080):
```bash
bash ~/start-tablet.sh
# Portas: 1883 (MQTT TCP), 9001 (MQTT WebSocket), 8080 (HTTP Dashboard)
```
O deploy de arquivos para o tablet é feito via SSH/SCP na porta `8022`:
```bash
scp -P 8022 dashboard_web/* u0_a85@192.168.100.244:~/dashboard/
```

---

## 7. Pendências Conhecidas

- **Brilho no Windows**: Alternativa estável para DDC/CI sem instabilidade de FFI.
- **Metadados de Mídia no Windows**: Captura de Now Playing no Windows via helper nativo ou IPC.
- **CI / Automação**: Pipeline de GitHub Actions para execução de `dart test`.
