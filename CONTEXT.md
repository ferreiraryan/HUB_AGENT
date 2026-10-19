# CONTEXT.md — Hub Agent

Documento de contexto arquitetural e operacional para modelos de IA e desenvolvedores.
Atualizado e conferido contra o estado do repositório em 18/10/2026.
Leia também [AGENT.md](./AGENT.md) e [AGENTS.md](./AGENTS.md).

---

## 1. Visão Geral e Topologia

O **Hub Agent** é um sistema de automação e controle local para periféricos e computadores na LAN, sem qualquer dependência de nuvem.

### Topologia do Sistema:
1. **Host (Spoke - PC Windows / Linux):**
   - Executa o **`apps/cms_app`** (Flutter Desktop) com suporte a inicialização oculta (`--hidden`), minimização para bandeja do sistema (tray) e autostart no boot.
   - O aplicativo desktop instancia o **`AgentRuntime`** (provido por **`packages/agent_core`**), que executa comandos do sistema (áudio, mídia, teclas, brilho, estatísticas) e sincroniza estado via MQTT.
2. **Kiosk (Hub - Tablet Android com Termux):**
   - Roda o broker MQTT **Mosquitto** com suporte a TCP (porta `1883`) e WebSocket (porta `9001`).
   - Serve os arquivos estáticos de **`dashboard_web/`** em HTTP (porta `8080`) via script `start-tablet.sh`.
   - O navegador ou app kiosk no tablet exibe o dashboard web conectado via WebSocket ao Mosquitto local.

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
|   - Executores locais: nircmd (Windows), wpctl/pactl/playerctl (Linux) |
+------------------------------------------------------------------------+
```

---

## 2. Componentes do Monorepo

- **`packages/agent_core`**:
  - Pacote Dart puro (**proibido importar Flutter**).
  - Gerencia o modelo de domínio (`Layout`, `Tile`, `HubTheme`, `AudioState`, `MediaState`).
  - `LayoutRepository`: lê e salva `layout.json` no disco local com debounce e sincronização em stream.
  - `MqttService`: comunicação com o broker Mosquitto.
  - `CommandDispatcher`: recebe comandos do MQTT e despacha para serviços locais protegidos.
  - Provedores de serviços: áudio, mídia, teclas (`KeySender`), brilho e estatísticas de hardware.
- **`apps/cms_app`**:
  - Aplicação Flutter desktop (Windows e Linux).
  - Editor visual WYSIWYG de telas, botões, sliders, cards de estatística, temas e atalhos.
  - Diálogo de configuração do broker MQTT e autostart (`broker_settings_dialog.dart`).
  - Recursos empacotados: `nircmd.exe` para Windows em `windows/runner/resources/nircmd.exe`.
- **`dashboard_web`**:
  - Frontend SPA vanilla (HTML5, CSS3, JavaScript puro) leve e resiliente para o tablet Android.
  - Conecta diretamente ao Mosquitto via WebSocket usando `mqtt.min.js`.
  - Projetado para rodar em WebViews legadas (Android 5/6 Lollipop/Marshmallow).

---

## 3. Contrato MQTT Canônico

O prefixo canônico de todos os tópicos de um nó é:
```text
nodes/{deviceId}/
```

### Publicações do Agente (Host -> Tablet):

| Tópico | Payload | QoS / Retain | Descrição |
| :--- | :--- | :--- | :--- |
| `status` | `{"online": bool, "os": "linux"\|"windows"}` | Retained / QoS 1 | Presença do agente. |
| `layout` | `{"deviceName": "...", "theme": {...}, "pages": [...]}` | Retained / QoS 1 | Estrutura de telas e botões para o tablet. |
| `audio/volume` | `{"value": 0..100}` | Sem retain / QoS 0 | Volume master do sistema. |
| `audio/apps` | `[{"id": "...", "name": "...", "volume": 0..100}]` | Sem retain / QoS 0 | Mixer de apps (suportado em Linux e Windows). |
| `media` | `{"status": "playing"\|"paused"\|"stopped", "title": "...", "artist": "..."}` | Sem retain / QoS 0 | Faixa em reprodução. |
| `sound/state` | `{"current_sound_id": "id"\|null, "is_playing": bool, "playing": "id"\|null, "status": "playing"\|"idle"}` | Sem retain / QoS 0 | Estado em tempo real do Sound Pad (campos canônicos e legados unificados). |
| `state/{sliderId}` | `{"value": int}` | Sem retain / QoS 0 | Estado atual de um slider genérico. |
| `stats/cpu` | `{"load": int, "temp": int?, "freq_mhz": int?}` | Sem retain / QoS 0 | Estatísticas de CPU do PC. |
| `stats/ram` | `{"used_mb": int, "total_mb": int, "percent": int}` | Sem retain / QoS 0 | Uso de memória RAM. |
| `stats/disk` | `{"mount": "...", "used_gb": int, "total_gb": int, "percent": int}` | Sem retain / QoS 0 | Uso do disco principal. |

### Comandos Recebidos (Tablet -> Host):
Tópico de subscrição do agente: `nodes/{deviceId}/cmd`

```json
{"action": "play_pause"}
{"action": "next"}
{"action": "prev"}
{"action": "set_volume", "value": 75}
{"action": "set_app_volume", "app_id": "spotify", "value": 50}
{"action": "run_shortcut", "id": "shortcut_id"}
{"action": "set_slider", "id": "slider_id", "value": 40}
{"action": "play_sound", "sound_id": "sound_id"}
{"action": "stop_sound"}
```

> [!IMPORTANT]
> **A Regra de Ouro da Segurança e o Golden Test:**
> - O layout publicado (`Layout.toPublishJson()`) contém **apenas** `deviceName`, `theme` e `pages`.
> - **NUNCA** inclua `bindings` (comandos shell, atalhos de teclado locais) no payload MQTT. O tablet apenas envia o ID da ação; a resolução de comandos é feita exclusivamente em memória pelo `CommandDispatcher` no PC a partir do `toDiskJson()`.
> - Esse contrato é validado estritamente em `packages/agent_core/test/contract_test.dart` contra `layout_golden.json`.

---

## 4. Estado Funcional por Plataforma

### Windows:
- **Áudio Master e Apps**: Controlado nativamente via `hub_audio_helper.exe` (WASAPI / Core Audio em C++, com fallback para `nircmd.exe`). Enumera sessões de áudio ativas (`IAudioSessionEnumerator`), lê o volume master e individual com precisão e ajusta o volume de aplicativos multiprocesso (`Spotify.exe`, `chrome.exe`, `Discord.exe` ou PIDs). Polling de estado e sincronização via MQTT a cada 1000 ms.
- **Sound Pad (Mesa de Sons)**: `SystemSoundController` integrado com `hub_audio_helper.exe play-sound` (WASAPI + Media Foundation com resample dinâmico) e `list-devices` (enumeração de endpoints). Suporta envio para Cabo Virtual (Discord/OBS/Meet) ou saída padrão, biblioteca gerenciada em `%APPDATA%/sounds/` isolada de pastas externas, interrupção por reclique (toggle) e cancelamento automático de som anterior ("um som por vez").
- **Controle de Mídia**: `WindowsMediaService` via `nircmd.exe sendkeypress` com VK codes em hex (`0xB3` play/pause, `0xB0` next, `0xB1` prev). **Nunca usar `sendkey`** (abre diálogo de help no NirCmd).
- **Atalhos / Teclado**: `WindowsKeySender` via `nircmd.exe sendkeypress`.
- **Estatísticas**: `WindowsStatsProvider` executa PowerShell (`Get-CimInstance Win32_Processor`, `Win32_OperatingSystem`, `Win32_LogicalDisk`). O comando legado `wmic` foi expressamente removido por não existir mais no Windows 11.
- **Brilho**: Não implementado nativamente ainda (`UnsupportedBrightnessController`).

### Linux:
- **Áudio Master e Apps**: `wpctl` para master e `pactl` para mixer individual de apps.
- **Controle de Mídia**: `playerctl` (MPRIS via D-Bus).
- **Atalhos / Teclado**: `LinuxKeySender` com `xdotool` para ambientes X11. Suporte a Wayland via `ydotool` permanece como pendência futura.
- **Brilho**: `ddcutil`.
- **Estatísticas**: Leitura direta de `/proc/stat`, `/proc/meminfo` e `df -k /`.

### Tablet Android (Dashboard Kiosk):
- **Compatibilidade Legada**: O tablet roda versões antigas do Android (5/6).
  - O código em `dashboard_web/app.js` evita intencionalmente sintaxes ES modernas não suportadas pelo WebView antigo (ex: **não** usar `?.` nem `??`).
  - Concatenação simples com `+` é adotada em trechos de renderização.
  - A fonte `Noto Color Emoji` é importada via Google Fonts e configurada como fallback no `style.css` para garantir visualização consistente de ícones.
  - O `ICON_MAP` em `app.js` converte nomes do Material Icons em caracteres Unicode/emojis.
  - Existe um painel de debug na base da tela (`#debug-log`) ativado via `window.logMsg` e `window.onerror`.

---

## 5. Decisões Arquiteturais Inegociáveis

1. **Separação de Camadas**: `packages/agent_core` é agnóstico de UI e independente de Flutter.
2. **NirCmd vs COM/Win32 no Windows**: Manter `nircmd.exe` para áudio, mídia e teclas. Tentativas anteriores com FFI/COM direto via Dart causaram vazamento de memória e use-after-free em finalizers.
3. **Segurança de Execução**: Comandos disparados pelo tablet devem ter correspondência prévia e explícita no `layout.json` local.
4. **Debounce de Layout**: Há debounce de 400 ms no editor do CMS e mais 400 ms no `LayoutRepository`. Não alterar sem validação ampla de concorrência.
5. **Autostart no Windows**: O CMS utiliza `launch_at_startup` com flag `--hidden` para iniciar na bandeja do sistema sem abrir a janela.

---

## 6. Ambiente de Execução e Desenvolvimento

No ambiente Windows padrão deste repositório, o Flutter SDK está localizado em:
`C:\Users\ryck3\flutter-sdk\flutter\bin`

### 1. Agent Core (Testes Unitários e de Contrato):
```powershell
cd packages/agent_core
& "C:\Users\ryck3\flutter-sdk\flutter\bin\dart.bat" test
```

### 2. CMS App (Desktop):
```powershell
cd apps/cms_app
& "C:\Users\ryck3\flutter-sdk\flutter\bin\flutter.bat" pub get
& "C:\Users\ryck3\flutter-sdk\flutter\bin\flutter.bat" run -d windows
```

### 3. Dashboard Web no Tablet (Produção via Termux):
O script `dashboard_web/start-tablet.sh` inicia o Mosquitto e o servidor HTTP no Termux:
```bash
bash ~/start-tablet.sh
# Portas: 1883 (MQTT TCP), 9001 (MQTT WebSocket), 8080 (HTTP Dashboard)
```

---

## 7. Pendências Conhecidas

- **`ydotool` no Linux**: Suporte a Wayland para envio de teclas.
- **Brilho no Windows**: Investigar alternativas estáveis para controle DDC/CI no Windows sem instabilidade de FFI (o mixer de áudio foi solucionado com `hub_audio_helper.exe`).
- **CI / Automação**: Configurar pipeline de GitHub Actions para execução automática de `dart test`.
- **Limpeza de dependências**: Conferir periodicamente se `packages/agent_core/pubspec.yaml` possui versões de dependências sem caracteres acidentais.
