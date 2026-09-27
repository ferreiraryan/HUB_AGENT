/* =========================================================
   1. CONFIG
   ========================================================= */
const MQTT_CONFIG = {
  brokerUrl: (() => {
    if (!window.location.hostname) {
      console.error('[MQTT] Página aberta via file:// — window.location.hostname está vazio.');
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

/* =========================================================
   2. STATE
   ========================================================= */
const state = {
  mqttClient: null,
  isBrokerConnected: false,
  devices: {},
  currentDeviceId: null,
  appsCache: {},
  volumeCache: {},    // Para o master_volume vindo do topic legado
  slidersCache: {},   // Cache genérico para sliders novos { [deviceId]: { 'brilho': 45, ... } }
  mediaCache: {},
  shortcutsCache: {},
  currentPageCache: {},
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

    state.mqttClient.on('reconnect', () => { state.isBrokerConnected = false; UI.updateBrokerStatus(false); });
    state.mqttClient.on('close', () => { state.isBrokerConnected = false; UI.updateBrokerStatus(false); });
    state.mqttClient.on('error', (err) => console.error('[MQTT] erro:', err));

    state.mqttClient.on('message', (topic, payloadBuffer) => {
      this.handleMessage(topic, payloadBuffer);
    });
  },

  subscribeAll() {
    state.mqttClient.subscribe('nodes/+/status');
    state.mqttClient.subscribe('nodes/+/layout');
    state.mqttClient.subscribe('nodes/+/audio/volume');
    state.mqttClient.subscribe('nodes/+/audio/apps');
    state.mqttClient.subscribe('nodes/+/media');
    // Prepara para os futuros sensores genéricos:
    state.mqttClient.subscribe('nodes/+/state/+');
  },

  handleMessage(topic, payloadBuffer) {
    let data;
    try {
      data = JSON.parse(payloadBuffer.toString());
    } catch (e) { return; }

    const topicParts = topic.split('/');
    if (topicParts[0] !== 'nodes' || topicParts.length < 3) return;

    const deviceId = topicParts[1];
    const topicType = topicParts.slice(2).join('/');

    // AUTO-DISCOVERY
    if (!state.devices[deviceId]) {
      state.devices[deviceId] = { id: deviceId, name: deviceId, online: false, cmdTopic: `nodes/${deviceId}/cmd` };
      state.slidersCache[deviceId] = {};
      if (!state.currentDeviceId) Navigation.selectDevice(deviceId);
    }
    const device = state.devices[deviceId];

    // ROTEAMENTO
    if (topicType === 'status') {
      device.online = !!data.online;
      UI.renderDeviceTabs();
      if (state.currentDeviceId === device.id) {
        UI.updateDeviceStatusBadge(device.online);
        UI.setOfflineOverlay(!device.online);
      }
    }
    else if (topicType === 'audio/apps') {
      state.appsCache[device.id] = Array.isArray(data) ? data : (data.apps || []);
      if (state.currentDeviceId === device.id) UI.renderAppMixer(state.appsCache[device.id]);
    }
    else if (topicType === 'audio/volume') {
      if (typeof data.value === 'number') {
        state.volumeCache[device.id] = data.value;
        if (state.currentDeviceId === device.id) UI.updateSliderUI('master_volume', data.value);
      }
    }
    // Captura estado genérico de sensores (ex: brilho)
    else if (topicType.startsWith('state/')) {
      const sliderId = topicParts[3];
      if (!state.slidersCache[device.id]) state.slidersCache[device.id] = {};
      state.slidersCache[device.id][sliderId] = data.value;

      if (state.currentDeviceId === device.id) UI.updateSliderUI(sliderId, data.value);
    }
    else if (topicType === 'media') {
      state.mediaCache[device.id] = data;
      UI.renderDeviceTabs();
      if (state.currentDeviceId === device.id) UI.renderNowPlaying(data);
    }
    else if (topicType === 'layout') {
      if (data.deviceName) {
        device.name = data.deviceName;
        UI.renderDeviceTabs();
        if (state.currentDeviceId === device.id) dom.deviceTitle.textContent = device.name;
      }
      if (data.theme) UI.applyTheme(data.theme);

      if (data.pages) state.shortcutsCache[device.id] = data.pages;
      else state.shortcutsCache[device.id] = { home: data.shortcuts || [] };

      state.currentPageCache[device.id] = 'home';
      if (state.currentDeviceId === device.id) UI.renderShortcuts(device.id);
    }
  },

  publishCommand(device, action, payloadExtra = {}) {
    if (!state.isBrokerConnected) return;
    const payload = { action, ...payloadExtra };
    state.mqttClient.publish(device.cmdTopic, JSON.stringify(payload));
  },

  publishMasterVolume(device, value) {
    if (!state.isBrokerConnected) return;
    state.mqttClient.publish(device.cmdTopic, JSON.stringify({ action: 'set_volume', value: Number(value) }));
  },

  publishAppVolume(device, appId, value) {
    if (!state.isBrokerConnected) return;
    state.mqttClient.publish(device.cmdTopic, JSON.stringify({ action: 'set_app_volume', app_id: appId, value: Number(value) }));
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
      tab.className = `device-tab ${device.online ? 'device-tab--online' : 'device-tab--offline'} ${isActive ? 'device-tab--active' : ''}`;
      tab.innerHTML = `
        <span class="device-tab__dot"></span>
        <span class="device-tab__name">${UI.escapeHtml(device.name)}</span>
        ${isPlaying ? '<span class="device-tab__media">&#127925;</span>' : ''}
      `;
      tab.addEventListener('click', () => Navigation.selectDevice(device.id));
      dom.deviceTabs.appendChild(tab);
    });
  },

  setOfflineOverlay(isOffline) {
    dom.mainContent.classList.toggle('main-content--disabled', isOffline);
    dom.offlineOverlay.classList.toggle('offline-overlay--active', isOffline);
  },

  escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  },

  applyTheme(theme) {
    const root = document.documentElement.style;
    if (theme.bgColor) root.setProperty('--bg-color', theme.bgColor);
    if (theme.cardColor) root.setProperty('--card-color', theme.cardColor);
    if (theme.accentColor) {
      root.setProperty('--accent-color', theme.accentColor);
      const match = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(theme.accentColor);
      if (match) {
        root.setProperty('--accent-glow', `rgba(${parseInt(match[1], 16)}, ${parseInt(match[2], 16)}, ${parseInt(match[3], 16)}, 0.35)`);
      }
    }
  },

  updateDeviceStatusBadge(online) {
    dom.deviceStatusBadge.textContent = online ? 'Online' : 'Offline';
    dom.deviceStatusBadge.classList.toggle('badge--online', online);
    dom.deviceStatusBadge.classList.toggle('badge--offline', !online);
  },

  // Atualiza via ID do sensor no DOM sem re-renderizar a grid inteira
  updateSliderUI(id, value) {
    const input = dom.shortcutsGrid.querySelector(`input[data-slider-id="${id}"]`);
    if (input && document.activeElement !== input) {
      input.value = value;
      const label = dom.shortcutsGrid.querySelector(`output[data-slider-value="${id}"]`);
      if (label) label.textContent = value + '%';
    }
  },

  renderShortcuts(deviceId) {
    dom.shortcutsGrid.innerHTML = '';
    const pages = state.shortcutsCache[deviceId];
    if (!pages) return;

    const currentPageId = state.currentPageCache[deviceId] || 'home';
    const items = pages[currentPageId] || [];
    const hasExplicitBack = items.some((item) => item.type === 'back');

    const renderList = (currentPageId !== 'home' && !hasExplicitBack)
      ? [{ type: 'back', icon: '⬅️', label: 'Voltar' }, ...items]
      : items;

    renderList.forEach((item, index) => {

      // ====== RENDERIZAÇÃO DO SLIDER ======
      if (item.type === 'slider') {
        const card = document.createElement('div');
        card.className = 'shortcut-btn shortcut-btn--slider';
        card.style.setProperty('--i', index);

        // Resolve o valor inicial (master volume tem tratamento especial provisório)
        let val = 50;
        if (item.id === 'master_volume') {
          val = typeof state.volumeCache[deviceId] === 'number' ? state.volumeCache[deviceId] : 50;
        } else {
          val = state.slidersCache[deviceId]?.[item.id] ?? 50;
        }

        card.innerHTML = `
          <div class="shortcut-slider__header">
            <div class="shortcut-slider__title">
              <span class="shortcut-slider__icon">${UI.escapeHtml(item.icon || '⎚')}</span>
              <span>${UI.escapeHtml(item.label || item.id)}</span>
            </div>
            <output class="shortcut-slider__value" data-slider-value="${item.id}">${val}%</output>
          </div>
          <input type="range" class="slider-horizontal" data-slider-id="${item.id}" min="0" max="100" value="${val}">
        `;

        const input = card.querySelector('input');
        const output = card.querySelector('output');
        let lastPublish = 0;

        input.addEventListener('input', (e) => {
          const v = e.target.value;
          output.textContent = v + '%';

          const now = Date.now();
          if (now - lastPublish > 120) {
            lastPublish = now;
            const device = state.devices[deviceId];
            if (device) {
              if (item.id === 'master_volume') {
                MqttLayer.publishMasterVolume(device, v);
              } else {
                // Publica a intenção de mudança de qualquer outro slider via Action
                MqttLayer.publishCommand(device, 'set_slider', { id: item.id, value: Number(v) });
              }
            }
          }
        });
        dom.shortcutsGrid.appendChild(card);
      }

      // ====== RENDERIZAÇÃO DOS BOTÕES COMUNS ======
      else {
        const btn = document.createElement('button');
        btn.className = 'shortcut-btn';
        btn.type = 'button';
        btn.style.setProperty('--i', index);
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
            const device = state.devices[deviceId];
            if (device) MqttLayer.publishCommand(device, item.id);
          }
        });
        dom.shortcutsGrid.appendChild(btn);
      }
    });
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
   Navegação
   ========================================================= */
const Navigation = {
  selectDevice(deviceId) {
    const device = state.devices[deviceId];
    if (!device) return;

    state.currentDeviceId = deviceId;
    dom.deviceTitle.textContent = device.name;
    UI.updateDeviceStatusBadge(device.online);
    UI.setOfflineOverlay(!device.online);

    UI.renderAppMixer(state.appsCache[deviceId] || []);
    UI.renderShortcuts(deviceId);
    UI.renderNowPlaying(state.mediaCache[deviceId] || null);
    UI.renderDeviceTabs();
    Navigation.closeMixerDrawer();
  },
  openMixerDrawer() { dom.mixerDrawer.classList.add('mixer-drawer--open'); },
  closeMixerDrawer() { dom.mixerDrawer.classList.remove('mixer-drawer--open'); },
};

/* =========================================================
   6. EVENT BINDINGS
   ========================================================= */
function bindEvents() {
  dom.btnToggleMixer.addEventListener('click', Navigation.openMixerDrawer);
  dom.btnCloseMixer.addEventListener('click', Navigation.closeMixerDrawer);
  dom.mixerBackdrop.addEventListener('click', Navigation.closeMixerDrawer);
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
