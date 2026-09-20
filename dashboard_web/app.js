/**
 * MQTT Dashboard - app.js
 * Vanilla JS (ES6), sem frameworks. Otimizado para tablets fracos (Android 5/6, 2GB RAM):
 *  - sem libs de reatividade/virtual DOM
 *  - DOM cacheado (querySelector uma única vez)
 *  - listeners de slider usam 'input' direto, sem debounce pesado (throttle leve no MQTT publish)
 *
 * Estrutura do arquivo:
 *   1. CONFIG         -> tudo que o usuário/instalador deve poder editar facilmente
 *   2. STATE            -> estado da aplicação em memória
 *   3. DOM REFS         -> cache de elementos
 *   4. MQTT LAYER       -> conexão, subscribe, publish
 *   5. UI LAYER         -> renderização e navegação entre telas
 *   6. EVENT BINDINGS   -> listeners de toque/slider
 *   7. INIT             -> bootstrap da aplicação
 */

/* =========================================================
   1. CONFIG
   ========================================================= */
const MQTT_CONFIG = {
  brokerUrl: (() => {
    if (!window.location.hostname) {
      console.error(
        '[MQTT] Página aberta via file:// — window.location.hostname está vazio. ' +
        'Sirva os arquivos via HTTP (ex: python3 -m http.server) para a conexão funcionar.'
      );
    }
    return 'ws://' + window.location.hostname + ':9001';
  })(),
  options: {
    clientId: 'kiosk-dashboard-' + Math.random().toString(16).slice(2, 8),
    reconnectPeriod: 3000,
    connectTimeout: 8000,
    clean: true,
  },
};

// Sem lista fixa de dispositivos: o tablet assina `nodes/+/...` (wildcard) e
// descobre qualquer node que publicar na rede (ver Auto-Discovery em handleMessage).

/* =========================================================
   2. STATE
   ========================================================= */
const state = {
  mqttClient: null,
  isBrokerConnected: false,
  devices: {}, // Começa vazio. Preenchido dinamicamente via Auto-Discovery (ver MqttLayer.handleMessage).
  currentDeviceId: null,
  appsCache: {},
  volumeCache: {},
  mediaCache: {},
  // { [deviceId]: { home: [...], alguma_pasta: [...] } } — suporta tanto o formato antigo
  // (array simples de atalhos) quanto o novo formato com pastas (objeto de páginas).
  shortcutsCache: {},
  currentPageCache: {}, // { [deviceId]: 'home' | 'nome_da_pasta' } — em qual página de atalhos cada device está
};

/* =========================================================
   3. DOM REFS
   ========================================================= */
const dom = {
  deviceTabs: document.getElementById('device-tabs'),
  brokerStatus: document.getElementById('broker-status'),

  deviceTitle: document.getElementById('device-title'),
  deviceStatusBadge: document.getElementById('device-status-badge'),

  mainContent: document.getElementById('main-content'),
  offlineOverlay: document.getElementById('offline-overlay'),

  masterVolume: document.getElementById('master-volume'),
  masterVolumeValue: document.getElementById('master-volume-value'),

  btnToggleMixer: document.getElementById('btn-toggle-mixer'),
  mixerDrawer: document.getElementById('mixer-drawer'),
  mixerBackdrop: document.getElementById('mixer-backdrop'),
  btnCloseMixer: document.getElementById('btn-close-mixer'),
  mixerAppsList: document.getElementById('mixer-apps-list'),

  shortcutsGrid: document.getElementById('shortcuts-grid'),

  nowPlaying: document.getElementById('now-playing'),
  npIcon: document.getElementById('np-icon'),
  npTitle: document.getElementById('np-title'),
  npArtist: document.getElementById('np-artist'),
};

/* =========================================================
   4. MQTT LAYER
   ========================================================= */
const MqttLayer = {
  connect() {
    state.mqttClient = mqtt.connect(MQTT_CONFIG.brokerUrl, MQTT_CONFIG.options);

    state.mqttClient.on('connect', () => {
      state.isBrokerConnected = true;
      UI.updateBrokerStatus(true);
      this.subscribeAll();
    });

    state.mqttClient.on('reconnect', () => {
      state.isBrokerConnected = false;
      UI.updateBrokerStatus(false);
    });

    state.mqttClient.on('close', () => {
      state.isBrokerConnected = false;
      UI.updateBrokerStatus(false);
    });

    state.mqttClient.on('error', (err) => {
      console.error('[MQTT] erro de conexão:', err);
    });

    state.mqttClient.on('message', (topic, payloadBuffer) => {
      this.handleMessage(topic, payloadBuffer);
    });
  },

  subscribeAll() {
    // Wildcard '+' casa qualquer nível do tópico: escuta QUALQUER device que publicar,
    // sem precisar saber o ID dele com antecedência.
    state.mqttClient.subscribe('nodes/+/status');
    state.mqttClient.subscribe('nodes/+/layout');
    state.mqttClient.subscribe('nodes/+/audio/volume');
    state.mqttClient.subscribe('nodes/+/audio/apps');
    state.mqttClient.subscribe('nodes/+/media');
  },

  handleMessage(topic, payloadBuffer) {
    let data;
    try {
      data = JSON.parse(payloadBuffer.toString());
    } catch (e) {
      console.warn('[MQTT] payload não-JSON ignorado em', topic);
      return;
    }

    // Extrai o ID do dispositivo e o sub-tópico. Ex: "nodes/arch-desktop/audio/volume"
    //   topicParts[0] = "nodes", topicParts[1] = deviceId, resto = topicType
    const topicParts = topic.split('/');
    if (topicParts[0] !== 'nodes' || topicParts.length < 3) return;

    const deviceId = topicParts[1];
    const topicType = topicParts.slice(2).join('/'); // "status", "layout", "audio/volume", "audio/apps", "media"

    // AUTO-DISCOVERY: se o device ainda não existe em memória, registra na hora.
    // Nome provisório = o próprio ID; o tópico "layout" pode renomear depois via "deviceName".
    if (!state.devices[deviceId]) {
      state.devices[deviceId] = {
        id: deviceId,
        name: deviceId,
        online: false,
        cmdTopic: `nodes/${deviceId}/cmd`,
      };
      // Sem tela Home pra escolher manualmente: o primeiro device que aparecer
      // na rede já entra selecionado, pra não deixar a UI vazia esperando um clique.
      if (!state.currentDeviceId) {
        Navigation.selectDevice(deviceId);
      }
    }
    const device = state.devices[deviceId];

    // --- ROTEAMENTO BASEADO NO SUB-TÓPICO ---
    if (topicType === 'status') {
      device.online = !!data.online;
      if (data.os) device.os = data.os; // opcional, só cosmético caso a UI queira usar depois

      UI.renderDeviceTabs();
      if (state.currentDeviceId === device.id) {
        UI.updateDeviceStatusBadge(device.online);
        UI.setOfflineOverlay(!device.online);
      }
    } else if (topicType === 'audio/apps') {
      state.appsCache[device.id] = Array.isArray(data) ? data : (data.apps || []);
      if (state.currentDeviceId === device.id) {
        UI.renderAppMixer(state.appsCache[device.id]);
      }
    } else if (topicType === 'audio/volume') {
      if (typeof data.value === 'number') {
        state.volumeCache[device.id] = data.value;
        // Evita feedback loop: eu movo -> publico -> broker ecoa -> "pulo" no slider
        const isDraggingMaster = document.activeElement === dom.masterVolume;
        if (state.currentDeviceId === device.id && !isDraggingMaster) {
          UI.setMasterVolumeUI(data.value);
        }
      }
    } else if (topicType === 'media') {
      state.mediaCache[device.id] = data;
      UI.renderDeviceTabs(); // atualiza o indicador de mídia na aba da sidebar
      if (state.currentDeviceId === device.id) {
        UI.renderNowPlaying(data);
      }
    } else if (topicType === 'layout') {
      // "deviceName" é texto livre vindo de outra máquina na rede - tratado como não confiável
      // (ver UI.escapeHtml em renderDeviceTabs antes de ir pro innerHTML).
      if (data.deviceName) {
        device.name = data.deviceName;
        UI.renderDeviceTabs();
        if (state.currentDeviceId === device.id) {
          dom.deviceTitle.textContent = device.name;
        }
      }

      // Tema dinâmico (config-driven UI): o node pode mandar cores próprias no layout
      if (data.theme) {
        UI.applyTheme(data.theme);
      }

      // Formato novo: { pages: { home: [...], alguma_pasta: [...] } }
      // Formato antigo (retrocompatível): { shortcuts: [...] } - vira uma página "home" única
      if (data.pages) {
        state.shortcutsCache[device.id] = data.pages;
      } else {
        state.shortcutsCache[device.id] = { home: data.shortcuts || [] };
      }

      // Sempre volta pra "home" quando chega um layout novo, pra não deixar o usuário
      // preso numa pasta que pode nem existir mais na config atualizada.
      state.currentPageCache[device.id] = 'home';

      if (state.currentDeviceId === device.id) {
        UI.renderShortcuts(device.id);
      }
    }
  },

  publishCommand(device, action) {
    if (!state.isBrokerConnected) return;
    state.mqttClient.publish(device.cmdTopic, JSON.stringify({ action }));
  },

  publishMasterVolume(device, value) {
    if (!state.isBrokerConnected) return;
    state.mqttClient.publish(device.cmdTopic, JSON.stringify({
      action: 'set_volume',
      value: Number(value),
    }));
  },

  publishAppVolume(device, appId, value) {
    if (!state.isBrokerConnected) return;
    state.mqttClient.publish(device.cmdTopic, JSON.stringify({
      action: 'set_app_volume',
      app_id: appId,
      value: Number(value),
    }));
  },
};

/* =========================================================
   5. UI LAYER
   ========================================================= */
const UI = {
  updateBrokerStatus(connected) {
    dom.brokerStatus.textContent = connected ? 'Conectado' : 'Desconectado';
    dom.brokerStatus.classList.toggle('broker-status--online', connected);
    dom.brokerStatus.classList.toggle('broker-status--offline', !connected);
  },

  /** Renderiza as abas de dispositivos na sidebar (substitui o antigo grid da Home) */
  renderDeviceTabs() {
    const devices = Object.values(state.devices);

    if (devices.length === 0) {
      dom.deviceTabs.innerHTML = '<p class="device-tabs__empty">Procurando dispositivos&hellip;</p>';
      return;
    }

    dom.deviceTabs.innerHTML = '';
    devices.forEach((device) => {
      const media = state.mediaCache[device.id];
      const isPlaying = media && media.status === 'Playing';
      const isActive = state.currentDeviceId === device.id;

      const tab = document.createElement('button');
      tab.type = 'button';
      tab.className = [
        'device-tab',
        device.online ? 'device-tab--online' : 'device-tab--offline',
        isActive ? 'device-tab--active' : '',
      ].join(' ').trim();

      tab.innerHTML = `
        <span class="device-tab__dot"></span>
        <span class="device-tab__name">${UI.escapeHtml(device.name)}</span>
        ${isPlaying ? '<span class="device-tab__media">&#127925;</span>' : ''}
      `;

      // Decisão de produto: aba offline continua clicável (mostra o conteúdo
      // "apagado" com overlay), em vez de travar o clique - ver setOfflineOverlay.
      tab.addEventListener('click', () => Navigation.selectDevice(device.id));

      dom.deviceTabs.appendChild(tab);
    });
  },

  /** Mostra/esconde o overlay "Dispositivo offline" e esmaece o conteúdo principal */
  setOfflineOverlay(isOffline) {
    dom.mainContent.classList.toggle('main-content--disabled', isOffline);
    dom.offlineOverlay.classList.toggle('offline-overlay--active', isOffline);
  },

  escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  },

  /**
   * Aplica um tema vindo do layout do node nas CSS custom properties reais do style.css.
   * Espera: { bgColor, cardColor, accentColor } (todas opcionais, em hex "#rrggbb").
   * O "glow" (--accent-glow) é recalculado a partir de accentColor pra não ficar
   * com um verde antigo brilhando sobre uma cor de destaque nova.
   */
  applyTheme(theme) {
    const root = document.documentElement.style;
    if (theme.bgColor) root.setProperty('--bg-color', theme.bgColor);
    if (theme.cardColor) root.setProperty('--card-color', theme.cardColor);
    if (theme.accentColor) {
      // Por decisão de produto, online/offline e todo o "brilho" da UI seguem o tema
      // customizado do node (não ficam fixos em verde) - ver --accent-color no CSS.
      root.setProperty('--accent-color', theme.accentColor);
      const glow = UI.hexToRgba(theme.accentColor, 0.35);
      if (glow) root.setProperty('--accent-glow', glow);
    }
  },

  /** Converte "#rrggbb" em "rgba(r, g, b, a)". Retorna null se o hex for inválido (evita CSS quebrado). */
  hexToRgba(hex, alpha) {
    const match = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    if (!match) return null;
    const r = parseInt(match[1], 16);
    const g = parseInt(match[2], 16);
    const b = parseInt(match[3], 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  },

  updateDeviceStatusBadge(online) {
    dom.deviceStatusBadge.textContent = online ? 'Online' : 'Offline';
    dom.deviceStatusBadge.classList.toggle('badge--online', online);
    dom.deviceStatusBadge.classList.toggle('badge--offline', !online);
  },

  /**
   * Renderiza a página de atalhos ATUAL de um device (state.currentPageCache[deviceId]).
   * Suporta 3 tipos de item:
   *   - "shortcut": dispara um comando MQTT (payload {"action": item.id} via cmdTopic)
   *   - "folder":   navega para outra página (item.target)
   *   - "back":     volta pra "home"
   */
  renderShortcuts(deviceId) {
    dom.shortcutsGrid.innerHTML = '';

    const pages = state.shortcutsCache[deviceId];
    if (!pages) return;

    const currentPageId = state.currentPageCache[deviceId] || 'home';
    const items = pages[currentPageId] || [];
    const hasExplicitBack = items.some((item) => item.type === 'back');

    // Rede de segurança: se estamos numa subpasta e a config não trouxe um botão de
    // voltar, criamos um pra não deixar o usuário preso sem saída.
    const renderList = (currentPageId !== 'home' && !hasExplicitBack)
      ? [{ type: 'back', icon: '⬅️', label: 'Voltar' }, ...items]
      : items;

    renderList.forEach((item, index) => {
      const btn = document.createElement('button');
      btn.className = 'shortcut-btn';
      btn.type = 'button';
      btn.style.setProperty('--i', index); // usado pelo CSS pra escalonar a animação de entrada
      // icon/label vêm de fora (config do node) - escapados antes de ir pro innerHTML
      btn.innerHTML = `
        <span class="shortcut-btn__icon">${UI.escapeHtml(item.icon || '⚡')}</span>
        <span>${UI.escapeHtml(item.label || item.id || 'Sem Nome')}</span>
      `;

      btn.addEventListener('click', () => {
        if (item.type === 'folder' && item.target) {
          state.currentPageCache[deviceId] = item.target;
          UI.renderShortcuts(deviceId);
        } else if (item.type === 'back') {
          state.currentPageCache[deviceId] = 'home';
          UI.renderShortcuts(deviceId);
        } else if (item.id) {
          // type "shortcut" (ou omitido) -> comando de verdade, via cmdTopic/action
          const device = state.devices[state.currentDeviceId];
          if (device) MqttLayer.publishCommand(device, item.id);
        }
      });

      dom.shortcutsGrid.appendChild(btn);
    });
  },

  setMasterVolumeUI(value) {
    dom.masterVolume.value = value;
    dom.masterVolumeValue.textContent = `${value}%`;
  },

  renderNowPlaying(data) {
    if (!data) {
      dom.npTitle.textContent = 'Nenhuma mídia tocando';
      dom.npArtist.textContent = '-';
      dom.npIcon.textContent = '\u{1F3B5}';
      dom.npIcon.classList.remove('np-icon--playing');
      dom.nowPlaying.classList.add('now-playing--empty');
      return;
    }

    const isPlaying = data.status === 'Playing';
    dom.npTitle.textContent = data.title || 'Desconhecido';
    dom.npArtist.textContent = data.artist || 'Desconhecido';
    dom.npIcon.textContent = isPlaying ? '\u25B6\uFE0F' : '\u23F8\uFE0F';
    dom.npIcon.classList.toggle('np-icon--playing', isPlaying);
    dom.nowPlaying.classList.remove('now-playing--empty');
  },

  renderAppMixer(apps) {
    dom.mixerAppsList.innerHTML = '';

    if (!apps || apps.length === 0) {
      dom.mixerAppsList.innerHTML = '<p class="mixer-empty-msg">Nenhuma aplicação de áudio ativa no momento.</p>';
      return;
    }

    apps.forEach((app) => {
      const row = document.createElement('div');
      row.className = 'app-mixer-row';
      row.innerHTML = `
        <div class="app-mixer-row__label">
          <span class="app-mixer-row__name">${app.name || app.id}</span>
          <span class="app-mixer-row__value">${app.volume ?? 0}%</span>
        </div>
        <input type="range" min="0" max="100" step="1" value="${app.volume ?? 0}" data-app-id="${app.id}">
      `;

      const input = row.querySelector('input');
      const valueLabel = row.querySelector('.app-mixer-row__value');

      let lastPublish = 0;
      input.addEventListener('input', (e) => {
        const val = e.target.value;
        valueLabel.textContent = `${val}%`;

        const now = Date.now();
        if (now - lastPublish > 120) {
          lastPublish = now;
          const device = state.devices[state.currentDeviceId];
          if (device) MqttLayer.publishAppVolume(device, app.id, val);
        }
      });

      dom.mixerAppsList.appendChild(row);
    });
  },
};

/* =========================================================
   Navegação: troca de dispositivo ativo (sidebar) + drawer do mixer
   ========================================================= */
const Navigation = {
  selectDevice(deviceId) {
    const device = state.devices[deviceId];
    if (!device) return;

    state.currentDeviceId = deviceId;
    dom.deviceTitle.textContent = device.name;
    UI.updateDeviceStatusBadge(device.online);
    UI.setOfflineOverlay(!device.online);

    // Injeta as grids cacheadas (mensagens retidas já chegaram antes do clique)
    UI.renderAppMixer(state.appsCache[deviceId] || []);
    UI.renderShortcuts(deviceId);

    UI.setMasterVolumeUI(
      typeof state.volumeCache[deviceId] === 'number' ? state.volumeCache[deviceId] : 50
    );
    UI.renderNowPlaying(state.mediaCache[deviceId] || null);

    UI.renderDeviceTabs(); // reflete a aba ativa destacada na sidebar
    Navigation.closeMixerDrawer(); // trocou de PC -> fecha o mixer se estava aberto
  },

  openMixerDrawer() {
    dom.mixerDrawer.classList.add('mixer-drawer--open');
  },

  closeMixerDrawer() {
    dom.mixerDrawer.classList.remove('mixer-drawer--open');
  },
};

/* =========================================================
   6. EVENT BINDINGS
   ========================================================= */
function bindEvents() {
  dom.btnToggleMixer.addEventListener('click', Navigation.openMixerDrawer);
  dom.btnCloseMixer.addEventListener('click', Navigation.closeMixerDrawer);
  // Toca fora do painel (no backdrop escurecido) também fecha o drawer
  dom.mixerBackdrop.addEventListener('click', Navigation.closeMixerDrawer);

  let lastMasterPublish = 0;
  dom.masterVolume.addEventListener('input', (e) => {
    const val = e.target.value;
    dom.masterVolumeValue.textContent = `${val}%`;

    const now = Date.now();
    if (now - lastMasterPublish > 120) {
      lastMasterPublish = now;
      const device = state.devices[state.currentDeviceId];
      if (device) MqttLayer.publishMasterVolume(device, val);
    }
  });
}

/* =========================================================
   7. INIT
   ========================================================= */
function init() {
  UI.renderDeviceTabs();
  bindEvents();
  MqttLayer.connect();
}

document.addEventListener('DOMContentLoaded', init);
