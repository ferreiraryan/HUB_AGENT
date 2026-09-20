# Hub Agent 🚀

Um ecossistema modular e local de automação e controle distribuído baseado na arquitetura **Hub & Spoke** via **MQTT**. O sistema transforma um tablet Android legado em um painel touch kiosk responsivo com baixíssima latência, enquanto gerencia comandos, áudio e mídia de estações de trabalho satélites (Linux/Windows) controladas por um CMS visual desktop em Flutter.

---

## 📌 Visão Geral do Sistema

```
 ┌────────────────────────────────────────────────────────┐
 │                   TABLET (Hub Central)                 │
 │                                                        │
 │   Mosquitto Broker (TCP :1883) ◄──────────┐            │
 │             ▲                             │            │
 │   bridge.js (WS :9001 -> TCP :1883)       │            │
 │             ▲                             │            │
 │   Web Dashboard (:8080)                   │            │
 │   (Vanilla JS / Fully Kiosk)              │            │
 └───────────────────────────────────────────┼────────────┘
                                             │
                                     MQTT TCP (:1883)
                                             │
 ┌───────────────────────────────────────────┴────────────┐
 │                    PC (Spoke / Satélite)               │
 │                                                        │
 │   [apps/cms_app]                                       │
 │   Flutter Desktop (Editor Visual 3-pane + Tray)        │
 │             │                                          │
 │   [packages/agent_core]                                │
 │   Dart Puro (MQTT Engine, Audio Mixer, Media IPC)      │
 └────────────────────────────────────────────────────────┘
```

- **Tablet (O Hub):** Fica fixo na bancada rodando o broker MQTT e hospedando a interface web com WebSocket Bridge sobre o Termux.
- **PC Satélite (O Spoke):** Executa o aplicativo desktop que publica layouts, telemetria de mídia e áudio, além de escutar e executar comandos locais (scripts, launchers e atalhos).
- **Zero Cloud:** Toda a comunicação opera estritamente na rede local (LAN).

---

## 📂 Estrutura do Monorepo

O repositório adota um layout monorepo gerenciado via `melos` para os componentes em Dart/Flutter, mantendo o frontend e o bridge web do tablet isolados.

```text
hub_agent/
├── .gitignore
├── README.md                      # Documentação central do projeto
├── melos.yaml                     # Workspace Dart/Flutter
│
├── packages/
│   └── agent_core/                # Dart puro (sem dependência de Flutter)
│       ├── lib/                   # Models, clientes MQTT, pipes de áudio e playerctl
│       └── test/                  # Golden tests e validação canônica de contrato
│
├── apps/
│   └── cms_app/                   # Editor visual Flutter Desktop (Linux/Windows)
│       ├── lib/                   # UI Three-pane (Páginas / Live Preview / Inspector)
│       └── linux/ & windows/      # Configurações e runners nativos
│
└── tablet/                        # Frontend Kiosk e servidor WebSocket
    ├── index.html                 # Interface Touch Kiosk
    ├── style.css                  # Folha de estilos (Variáveis dinâmicas CSS)
    ├── app.js                     # Motor Vanilla JS (Auto-Discovery e navegação)
    ├── mqtt.min.js                # Cliente MQTT para WebSocket
    ├── bridge.js                  # Proxy WebSocket (:9001) para TCP (:1883) + Servidor HTTP (:8080)
    ├── package.json               # Dependências do bridge (Node.js/ws)
    └── README.md                  # Instruções de setup isolado no Android/Termux
```

---

## 📡 Contrato de Comunicação MQTT

O ecossistema utiliza tópicos estruturados em torno de `nodes/{deviceId}/...` com auto-descoberta dinâmica.

### Tópicos Publicados pelo Agente (Retained)

| Tópico | Exemplo de Payload | Descrição |
| :--- | :--- | :--- |
| `nodes/{deviceId}/status` | `{"online": true, "os": "linux"}` | Presença do PC (mantido com LWT). |
| `nodes/{deviceId}/layout` | *(Ver schema abaixo)* | Árvore de telas, temas e atalhos. |
| `nodes/{deviceId}/audio/volume` | `{"value": 75}` | Nível de volume master (0-100). |
| `nodes/{deviceId}/audio/apps` | `[{"id": "12", "name": "Spotify", "volume": 60}]` | Mixer por aplicação. |
| `nodes/{deviceId}/media` | `{"status": "Playing", "title": "...", "artist": "..."}` | Metadados de reprodução (MPRIS). |

### Tópicos Publicados pelo Tablet (Comandos)

| Tópico | Payload | Ação |
| :--- | :--- | :--- |
| `nodes/{deviceId}/cmd` | `{"action": "terminal"}` | Dispara o comando cadastrado no layout. |
| `nodes/{deviceId}/audio/volume/set` | `{"value": 50}` | Altera o volume master do sistema. |
| `nodes/{deviceId}/audio/app/set` | `{"app_id": "12", "value": 40}` | Altera o volume de um app específico. |

---

### Schema do `layout.json` (Config-Driven UI)

```json
{
  "deviceName": "Arch Desktop",
  "theme": {
    "bgColor": "#11111b",
    "cardColor": "#1e1e2e",
    "accentColor": "#cba6f7",
    "borderRadius": "16px"
  },
  "pages": {
    "home": [
      {
        "type": "folder",
        "id": "dev_tools",
        "icon": "📁",
        "label": "Dev Tools",
        "target": "dev_tools"
      },
      {
        "type": "shortcut",
        "id": "lock",
        "icon": "🔒",
        "label": "Bloquear",
        "cmd": ["loginctl", "lock-session"]
      }
    ],
    "dev_tools": [
      {
        "type": "back",
        "id": "back_home",
        "icon": "⬅️",
        "label": "Voltar"
      },
      {
        "type": "shortcut",
        "id": "terminal",
        "icon": "💻",
        "label": "Kitty",
        "cmd": ["kitty"]
      }
    ]
  }
}
```

---

## 🚀 Como Inicializar

### 1. No Tablet (O Servidor Central)

Pré-requisitos no Termux:
```bash
pkg install nodejs-lts mosquitto
```

Passos de execução:
```bash
# Evita suspensão de CPU pelo Android
termux-wake-lock

# Encerra eventuais processos órfãos
killall mosquitto node 2>/dev/null

# 1. Inicia o broker MQTT em background (TCP porta 1883)
mosquitto -d

# 2. Entra na pasta do tablet e inicia a ponte WebSocket + Servidor HTTP
cd ~/dashboard
npm install # Executado apenas na primeira vez
node bridge.js
```

Acesse no navegador (Chrome ou Fully Kiosk):
```text
http://127.0.0.1:8080
```
> O indicador de status do broker mudará para verde assim que o socket for autenticado em `ws://127.0.0.1:9001`.

---

### 2. No PC (O Satélite / CMS)

#### Configuração das Ferramentas
No diretório raiz do monorepo:
```bash
dart pub global activate melos
melos bootstrap
```

#### Executando o CMS Desktop
```bash
cd apps/cms_app
flutter run -d linux # ou -d windows
```

O CMS iniciará conectado ao IP configurado do tablet, publicará o LWT de status online e despachará o layout configurado no disco.

---

## 🛠️ Diagnóstico e Troubleshooting

- **Bolinha do broker vermelha no tablet:** O `bridge.js` não está em execução ou o Mosquitto não subiu na porta `1883`. Verifique com `ps aux | grep -E "mosquitto|node"`.
- **Card do PC não aparece ou fica offline:** Verifique se o endereço IP do tablet definido na inicialização do `agent_core`/`cms_app` confere com o IP local atribuído pelo Wi-Fi. Certifique-se de que a porta `1883` não está bloqueada pelo firewall (`ufw` ou `iptables`).
- **Comandos de interface gráfica não disparam no Linux:** No Wayland/Hyprland, garanta que os subprocessos do agente herdem as variáveis `WAYLAND_DISPLAY` e `XDG_RUNTIME_DIR`.
- **Alterações de layout não refletem no tablet:** Certifique-se de que a mensagem despachada em `nodes/{deviceId}/layout` utiliza a flag MQTT `retain: true`.

---

## 🗺️ Roadmap e Próximos Passos

- [x] **MVP:** Contrato MQTT validado e travado por testes contratuais.
- [x] **Auto-Discovery:** Suporte multi-dispositivo dinâmico via `nodes/#`.
- [x] **Config-Driven UI:** Suporte a temas CSS dinâmicos e navegação por pastas aninhadas.
- [x] **CMS Visual:** Editor Three-Pane (Páginas, Live Preview, Inspector).
- [ ] **Drag-and-Drop:** Reordenação interativa de botões no editor.
- [ ] **Native Audio Daemon:** Migração completa da captura do PipeWire/wpctl para Dart FFI.
- [ ] **Telemetria de Sistema:** Envio e exibição de uso de CPU/RAM/GPU no dashboard do tablet.
