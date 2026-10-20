# Hub Agent 🚀

Um ecossistema modular e local de automação e controle distribuído baseado na arquitetura **Hub & Spoke** via **MQTT**. O sistema transforma um tablet Android legado em um painel touch kiosk responsivo com baixíssima latência, enquanto gerencia comandos, áudio, mídia, mesa de sons (Sound Pad) e estatísticas de computadores (Linux e Windows) controlados por um CMS visual desktop em Flutter.

---

## 📌 Visão Geral do Sistema

```
 ┌────────────────────────────────────────────────────────┐
 │                   TABLET (Hub Central)                 │
 │                                                        │
 │   Mosquitto Broker (TCP :1883 + WS :9001)              │
 │             ▲                                          │
 │   Web Dashboard (:8080 via Python HTTP Server)         │
 │   (Vanilla JS / Fully Kiosk Browser)                   │
 └─────────────────────────┬──────────────────────────────┘
                           │
                   MQTT TCP (:1883)
                           │
 ┌─────────────────────────┴──────────────────────────────┐
 │                    PC (Spoke / Satélite)               │
 │                                                        │
 │   [apps/cms_app]                                       │
 │   Flutter Desktop (Editor Visual 3-pane + Tray)        │
 │             │                                          │
 │   [packages/agent_core]                                │
 │   Dart Puro (MQTT Engine, Audio Mixer, Sound Pad, IPC) │
 └────────────────────────────────────────────────────────┘
```

- **Tablet (O Hub):** Fica fixo na bancada rodando o broker MQTT Mosquitto com suporte nativo a WebSocket e servindo a interface web estática sobre o Termux.
- **PC Satélite (O Spoke):** Executa o aplicativo desktop que publica layouts, áudio, som e telemetria, além de escutar e executar comandos locais (scripts, launchers, mesa de som e atalhos).
- **Zero Cloud:** Toda a comunicação opera estritamente na rede local (LAN).

---

## 📂 Estrutura do Monorepo

```text
hub_agent/
├── .gitignore
├── README.md                      # Documentação central do projeto
├── CONTEXT.md                     # Documento arquitetural detalhado para desenvolvedores
├── AGENT.md                       # Diretrizes de desenvolvimento para agentes de IA
│
├── packages/
│   └── agent_core/                # Dart puro (sem dependência de Flutter)
│       ├── lib/                   # Models, clientes MQTT, pipes de áudio, mídia e soundpad
│       └── test/                  # Golden tests, testes contratuais e testes unitários
│
├── apps/
│   └── cms_app/                   # Editor visual Flutter Desktop (Linux/Windows)
│       ├── lib/                   # UI Three-pane (Páginas / Live Preview / Inspector)
│       ├── linux/                 # Runners e integrações nativas Linux
│       └── windows/               # Configurações Windows, hub_audio_helper (WASAPI) e nircmd
│
└── dashboard_web/                 # Frontend Kiosk do tablet (HTML5/CSS3/Vanilla JS)
    ├── index.html                 # Interface Touch Kiosk com tema dinâmico
    ├── style.css                  # Estilos responsivos e animações
    ├── app.js                     # Motor Vanilla JS (compatível com Android 5/6 WebView)
    ├── mqtt.min.js                # Cliente MQTT para WebSocket
    ├── twemoji.min.js             # Renderização cross-platform de emojis
    └── start-tablet.sh            # Script Termux de inicialização dos serviços
```

---

## 📡 Contrato de Comunicação MQTT

Todos os tópicos utilizam o prefixo `nodes/{deviceId}/...` com auto-descoberta dinâmica.

### Tópicos Publicados pelo Agente (Retained)

| Tópico | Exemplo de Payload | Descrição |
| :--- | :--- | :--- |
| `nodes/{deviceId}/status` | `{"online": true, "os": "linux"}` | Presença do PC (mantido com LWT). |
| `nodes/{deviceId}/layout` | `{"deviceName": "...", "theme": {...}, "pages": [...]}` | Telas, botões e temas do kiosk. |
| `nodes/{deviceId}/audio/volume` | `{"value": 75}` | Nível de volume master (0-100). |
| `nodes/{deviceId}/audio/apps` | `[{"id": "12", "name": "Spotify", "volume": 60}]` | Mixer por aplicação. |
| `nodes/{deviceId}/media` | `{"status": "Playing", "title": "...", "artist": "..."}` | Metadados de reprodução (MPRIS no Linux). |
| `nodes/{deviceId}/sound/state` | `{"current_sound_id": "...", "is_playing": true, ...}` | Estado em tempo real da mesa de sons. |
| `nodes/{deviceId}/state/{sliderId}` | `{"value": 80}` | Estado atual de sliders (brilho). |
| `nodes/{deviceId}/stats/cpu` | `{"load": 25, "temp": 48, "freq_mhz": 3200}` | Telemetria de CPU do PC. |
| `nodes/{deviceId}/stats/ram` | `{"used_mb": 4096, "total_mb": 16384, "percent": 25}` | Uso de memória RAM. |
| `nodes/{deviceId}/stats/disk` | `{"mount": "/", "used_gb": 100, "total_gb": 500, "percent": 20}` | Uso do disco principal. |

### Comandos Recebidos pelo Agente

Tópico de subscrição: `nodes/{deviceId}/cmd`

```json
{"action": "play_pause"}
{"action": "next"}
{"action": "prev"}
{"action": "set_volume", "value": 75}
{"action": "set_app_volume", "app_id": "spotify", "value": 50}
{"action": "set_slider", "id": "slider_id", "value": 40}
{"action": "play_sound", "sound_id": "som_1"}
{"action": "stop_sound"}
{"action": "tile_id"}
```

> [!IMPORTANT]
> **Segurança de Execução:** Comandos do shell nunca são transmitidos pela rede. O layout publicado para o tablet contém apenas as referências visuais (`toPublishJson()`). A resolução de comandos locais é realizada exclusivamente pelo `CommandDispatcher` na máquina anfitriã a partir do `layout.json` gravado em disco.

---

## 🚀 Como Inicializar

### 1. No Tablet (O Hub Central)

Pré-requisitos no Termux:
```bash
pkg install mosquitto python
```

Execute o script de inicialização do tablet:
```bash
bash ~/start-tablet.sh
```
O script iniciará:
- O broker Mosquitto nas portas `1883` (TCP) e `9001` (WebSocket).
- O servidor estático Python na porta `8080`.

Acesse no navegador (Chrome ou Fully Kiosk Browser):
```text
http://127.0.0.1:8080
```

### 2. No Computador (Host / CMS)

#### Linux:
```bash
cd apps/cms_app
flutter pub get
flutter run -d linux
```

#### Windows:
```powershell
cd apps/cms_app
flutter pub get
flutter run -d windows
```

---

## 🗺️ Estado do Projeto e Roadmap

- [x] **Contrato MQTT Canônico:** Travado por testes automatizados e golden test.
- [x] **Segurança de Bindings:** Comandos de terminal e atalhos isolados localmente.
- [x] **CMS Visual:** Editor Three-Pane (Páginas, Live Preview, Inspector).
- [x] **Mixer de Áudio:** Master e apps no Linux (PipeWire/pactl) e Windows (WASAPI nativo).
- [x] **Mesa de Sons (Sound Pad):** Gerenciador de biblioteca de sons, suporte a cabo virtual e toggle por reclique.
- [x] **Telemetria de Sistema:** Leitura em tempo real de CPU, RAM e Disco no Linux e Windows.
- [x] **Wayland no Linux:** Suporte nativo a envio de teclas via `wtype` (Hyprland / wlroots) e fallback para `ydotool` / `xdotool`.
- [ ] **Brilho no Windows:** Implementação de suporte nativo DDC/CI.
