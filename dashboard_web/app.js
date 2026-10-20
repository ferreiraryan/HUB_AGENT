/* =========================================================
   0. ICON MAP
   ========================================================= */
const ICON_MAP = {
  // Mídia & Controles
  'play_arrow': '▶️', 'pause': '⏸️', 'stop': '⏹️', 'fiber_manual_record': '⏺️',
  'skip_next': '⏭️', 'skip_previous': '⏮️', 'fast_forward': '⏩', 'fast_rewind': '⏪',
  'shuffle': '🔀', 'repeat': '🔁', 'loop': '🔄',

  // Áudio & Som
  'volume_up': '🔊', 'volume_down': '🔉', 'volume_mute': '🔇', 'volume_off': '🔇',
  'music_note': '🎵', 'headphones': '🎧', 'radio': '📻', 'mic': '🎙️', 'tv': '📺',
  'graphic_eq': '🎛️',

  // Navegação & UI
  'arrow_back': '⬅️', 'arrow_forward': '➡️', 'arrow_upward': '⬆️', 'arrow_downward': '⬇️',
  'home': '🏠', 'refresh': '🔄', 'search': '🔍', 'settings': '⚙️', 'close': '❌',
  'check': '✔️', 'add': '➕', 'remove': '➖', 'delete': '🗑️', 'push_pin': '📌',
  'location_on': '📍', 'link': '🔗', 'notifications': '🔔', 'notifications_off': '🔕',

  // Pastas & Arquivos
  'folder': '📁', 'folder_open': '📂', 'insert_drive_file': '📄', 'bar_chart': '📊',
  'show_chart': '📈', 'content_paste': '📋', 'inventory_2': '📦',

  // Dispositivos & Hardware
  'computer': '💻', 'desktop_windows': '🖥️', 'smartphone': '📱', 'watch': '⌚',
  'keyboard': '⌨️', 'mouse': '🖱️', 'print': '🖨️', 'battery_full': '🔋',
  'power': '🔌', 'lightbulb': '💡', 'flashlight_on': '🔦', 'photo_camera': '📷',
  'videocam': '📹', 'language': '🌐',

  // Comunicação & Apps
  'local_fire_department': '🔥', 'chat': '💬', 'smart_toy': '🤖', 'sports_esports': '🎮',
  'mail': '📧', 'call': '📞', 'terminal': '💻', 'build': '🔧', 'science': '🧪',
  'radar': '📡', 'calculate': '🧮',

  // Diversos & Clima
  'chair': '🛋️', 'shower': '🚿', 'wb_sunny': '☀️', 'cloud': '☁️', 'water_drop': '💧',
  'bolt': '⚡', 'ac_unit': '❄️', 'dark_mode': '🌙', 'star': '⭐', 'warning': '⚠️',
  'block': '🚫', 'help_outline': '❓', 'priority_high': '❗', 'verified': '✅',

  // Números
  'looks_one': '1️⃣', 'looks_two': '2️⃣', 'looks_3': '3️⃣', 'looks_4': '4️⃣', 'looks_5': '5️⃣',
  'looks_6': '6️⃣', 'filter_7': '7️⃣', 'filter_8': '8️⃣', 'filter_9': '9️⃣',
};

/* =========================================================
   1. CONFIG
   ========================================================= */
const MQTT_CONFIG = {
  brokerUrl: 'ws://127.0.0.1:9001',
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
  volumeCache: {},
  slidersCache: {},
  mediaCache: {},
  shortcutsCache: {},
  currentPageCache: {},
  statsCache: {},
  soundStateCache: {},
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
    const log = typeof window.logMsg === 'function' ? window.logMsg : function(msg) { console.log(msg); };

    log('Tentando conectar em: ' + MQTT_CONFIG.brokerUrl, '#0ff');
    state.mqttClient = mqtt.connect(MQTT_CONFIG.brokerUrl, MQTT_CONFIG.options);

    state.mqttClient.on('connect', () => {
      log('MQTT CONNECTED!', '#0f0');
      state.isBrokerConnected = true;
      UI.updateBrokerStatus(true);
      this.subscribeAll();
    });

    state.mqttClient.on('reconnect', () => log('MQTT RECONNECTING...', '#fa0'));
    state.mqttClient.on('close', () => log('MQTT CONNECTION CLOSED', '#f55'));
    state.mqttClient.on('offline', () => log('MQTT OFFLINE', '#f55'));
    state.mqttClient.on('error', (err) => {
      log('MQTT ERROR: ' + (err.message || err), '#f55');
      console.error('[MQTT] erro:', err);
    });
    
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
    state.mqttClient.subscribe('nodes/+/sound/state');
    state.mqttClient.subscribe('nodes/+/event');
    state.mqttClient.subscribe('nodes/+/state/+');
    state.mqttClient.subscribe('nodes/+/stats/cpu');
    state.mqttClient.subscribe('nodes/+/stats/ram');
    state.mqttClient.subscribe('nodes/+/stats/disk');
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

    if (!state.devices[deviceId]) {
      state.devices[deviceId] = { id: deviceId, name: deviceId, online: false, cmdTopic: 'nodes/' + deviceId + '/cmd' };
      state.slidersCache[deviceId] = {};
      if (!state.currentDeviceId) Navigation.selectDevice(deviceId);
    }
    const device = state.devices[deviceId];

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
    else if (topicType === 'sound/state') {
      state.soundStateCache[device.id] = data;
      if (state.currentDeviceId === device.id) UI.updateSoundStateInPlace(device.id);
    }
    else if (topicType === 'event') {
      if (state.currentDeviceId === device.id) UI.showToast(data);
    }
    else if (topicType.startsWith('state/')) {
      const sliderId = topicParts[3];
      if (!state.slidersCache[device.id]) state.slidersCache[device.id] = {};
      state.slidersCache[device.id][sliderId] = data.value;

      if (state.currentDeviceId === device.id) UI.updateSliderUI(sliderId, data.value);
    }
    else if (topicType.startsWith('stats/')) {
      const kind = topicParts[3];
      if (!state.statsCache[device.id]) state.statsCache[device.id] = {};
      state.statsCache[device.id][kind] = data;
      if (state.currentDeviceId === device.id) UI.updateStatsInPlace(device.id);
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

  // Ajustado para não usar default parameters
  publishCommand(device, action, payloadExtra) {
    if (!state.isBrokerConnected) return;
    payloadExtra = payloadExtra || {};
    payloadExtra.action = action;
    state.mqttClient.publish(device.cmdTopic, JSON.stringify(payloadExtra));
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
  showToast(data) {
    if (!data || !data.message) return;
    const container = document.getElementById('toast-container');
    if (!container) return;

    while (container.children.length >= 3) {
      const oldest = container.firstChild;
      if (oldest._dismissTimer) clearTimeout(oldest._dismissTimer);
      container.removeChild(oldest);
    }

    const kind = (data.kind || 'info').toLowerCase();
    const duration = (typeof data.duration === 'number' && data.duration > 0)
      ? data.duration
      : 3000;

    const iconMap = {
      'info': 'ℹ️',
      'success': '✅',
      'warning': '⚠️',
      'error': '❌'
    };
    const icon = iconMap[kind] || 'ℹ️';

    const toast = document.createElement('div');
    toast.className = 'toast toast--' + kind;
    toast.innerHTML = 
      '<span class="toast__icon">' + icon + '</span>' +
      '<span class="toast__message">' + UI.escapeHtml(data.message) + '</span>';

    container.appendChild(toast);
    UI.parseEmojis(toast);

    void toast.offsetWidth;
    toast.classList.add('toast--visible');

    toast._dismissTimer = setTimeout(function() {
      toast.classList.remove('toast--visible');
      setTimeout(function() {
        if (toast.parentNode === container) {
          container.removeChild(toast);
        }
      }, 200);
    }, duration);
  },

  updateBrokerStatus(connected) {
    dom.brokerStatus.textContent = connected ? 'Conectado' : 'Desconectado';
    dom.brokerStatus.classList.toggle('broker-status--online', connected);
    dom.brokerStatus.classList.toggle('broker-status--offline', !connected);
  },

  parseEmojis(target) {
    if (typeof twemoji !== 'undefined' && twemoji && typeof twemoji.parse === 'function') {
      try {
        twemoji.parse(target || document.body, {
          folder: 'svg',
          ext: '.svg',
          base: 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/'
        });
      } catch (e) {
        console.warn('[Twemoji] Erro ao processar:', e);
      }
    }
  },

  renderDeviceTabs() {
    // Substituindo Object.values para compatibilidade com Chrome antigo
    const devices = Object.keys(state.devices).map(function(k) { return state.devices[k]; });
    
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
      tab.className = 'device-tab ' + (device.online ? 'device-tab--online' : 'device-tab--offline') + ' ' + (isActive ? 'device-tab--active' : '');
      tab.innerHTML = 
        '<span class="device-tab__dot"></span>' +
        '<span class="device-tab__name">' + UI.escapeHtml(device.name) + '</span>' +
        (isPlaying ? '<span class="device-tab__media">&#127925;</span>' : '');
      
      tab.addEventListener('click', () => Navigation.selectDevice(device.id));
      dom.deviceTabs.appendChild(tab);
    });
    this.parseEmojis(dom.deviceTabs);
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

  iconFor(item) {
    const raw = item.icon || '';
    return ICON_MAP[raw] || raw || '⚡';
  },

  applyTheme(theme) {
    const root = document.documentElement.style;
    if (theme.bgColor) root.setProperty('--bg-color', theme.bgColor);
    if (theme.cardColor) root.setProperty('--card-color', theme.cardColor);
    if (theme.accentColor) {
      root.setProperty('--accent-color', theme.accentColor);
      const match = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(theme.accentColor);
      if (match) {
        root.setProperty('--accent-glow', 'rgba(' + parseInt(match[1], 16) + ', ' + parseInt(match[2], 16) + ', ' + parseInt(match[3], 16) + ', 0.35)');
      }
    }
  },

  updateDeviceStatusBadge(online) {
    dom.deviceStatusBadge.textContent = online ? 'Online' : 'Offline';
    dom.deviceStatusBadge.classList.toggle('badge--online', online);
    dom.deviceStatusBadge.classList.toggle('badge--offline', !online);
  },

  updateSliderUI(id, value) {
    const input = dom.shortcutsGrid.querySelector('input[data-slider-id="' + id + '"]');
    if (input && document.activeElement !== input) {
      input.value = value;
      const label = dom.shortcutsGrid.querySelector('output[data-slider-value="' + id + '"]');
      if (label) label.textContent = value + '%';
    }
  },

  updateStatsInPlace(deviceId) {
    const stats = state.statsCache[deviceId] || {};
    const cards = dom.shortcutsGrid.querySelectorAll('.shortcut-btn--stat');

    cards.forEach((card) => {
      const kind = card.dataset.statKind;
      const field = card.dataset.statField;
      const unit = card.dataset.statUnit;

      // Remoção do operador ?? (Nullish Coalescing)
      const payload = stats[kind] || {};
      const raw = payload[field];
      const display = (raw === undefined || raw === null) ? '--' : raw;

      const valueEl = card.querySelector('.stat-card__value');
      if (valueEl) {
        valueEl.textContent = String(display) + (unit || '');
      }

      const barFill = card.querySelector('.stat-card__bar-fill');
      if (barFill && unit === '%' && typeof raw === 'number') {
        const pct = Math.max(0, Math.min(100, raw));
        barFill.style.width = pct + '%';
      }
    });
  },

  parseSoundState(data) {
    if (!data) return { isPlaying: false, soundId: null };
    var isPlaying = !!(data.is_playing || data.status === 'playing');
    var soundId = data.current_sound_id || data.sound_id || data.playing || null;
    return {
      isPlaying: isPlaying && !!soundId,
      soundId: isPlaying ? soundId : null
    };
  },

  updateSoundStateInPlace(deviceId) {
    const soundPlayback = this.parseSoundState(state.soundStateCache[deviceId]);
    const soundButtons = dom.shortcutsGrid.querySelectorAll('.shortcut-btn--sound');
    soundButtons.forEach((btn) => {
      const soundId = btn.dataset.soundId;
      const isThisPlaying = soundPlayback.isPlaying && (soundId === soundPlayback.soundId);

      btn.classList.toggle('shortcut-btn--playing', isThisPlaying);
      btn.disabled = false;
    });
  },

  renderShortcuts(deviceId) {
    dom.shortcutsGrid.innerHTML = '';
    const pages = state.shortcutsCache[deviceId];
    if (!pages) return;

    const currentPageId = state.currentPageCache[deviceId] || 'home';
    const items = pages[currentPageId] || [];
    const hasExplicitBack = items.some((item) => item.type === 'back');

    const renderList = (currentPageId !== 'home' && !hasExplicitBack)
      ? [{ type: 'back', icon: '⬅️', label: 'Voltar' }].concat(items)
      : items;

    renderList.forEach((item, index) => {
      if (item.type === 'slider') {
        const card = document.createElement('div');
        card.className = 'shortcut-btn shortcut-btn--slider';
        card.style.setProperty('--i', index);

        let val = 50;
        if (item.id === 'master_volume') {
          val = typeof state.volumeCache[deviceId] === 'number' ? state.volumeCache[deviceId] : 50;
        } else {
          // Remoção segura do operador ?. e ??
          if (state.slidersCache[deviceId] && state.slidersCache[deviceId][item.id] !== undefined) {
            val = state.slidersCache[deviceId][item.id];
          }
        }

        card.innerHTML = 
          '<div class="shortcut-slider__header">' +
            '<div class="shortcut-slider__title">' +
              '<span class="shortcut-slider__icon">' + UI.escapeHtml(UI.iconFor(item)) + '</span>' +
              '<span>' + UI.escapeHtml(item.label || item.id) + '</span>' +
            '</div>' +
            '<output class="shortcut-slider__value" data-slider-value="' + item.id + '">' + val + '%</output>' +
          '</div>' +
          '<input type="range" class="slider-horizontal" data-slider-id="' + item.id + '" min="0" max="100" value="' + val + '">';

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
                MqttLayer.publishCommand(device, 'set_slider', { id: item.id, value: Number(v) });
              }
            }
          }
        });
        dom.shortcutsGrid.appendChild(card);
      }
      else if (item.type === 'stat') {
        const stats = state.statsCache[deviceId] || {};
        const payload = stats[item.source.kind] || {};
        const raw = payload[item.source.field];
        const display = (raw === undefined || raw === null) ? '--' : raw;

        const card = document.createElement('div');
        card.className = 'shortcut-btn shortcut-btn--stat';
        card.style.setProperty('--i', index);
        card.dataset.statKind = item.source.kind;
        card.dataset.statField = item.source.field;
        card.dataset.statUnit = item.source.unit || '';

        const pct = item.source.unit === '%' && typeof raw === 'number'
          ? Math.max(0, Math.min(100, raw))
          : 0;

        card.innerHTML = 
          '<div class="stat-card__header">' +
            '<span class="stat-card__icon">' + UI.escapeHtml(UI.iconFor(item)) + '</span>' +
            '<span class="stat-card__label">' + UI.escapeHtml(item.label || item.id) + '</span>' +
          '</div>' +
          '<div class="stat-card__value">' + UI.escapeHtml(String(display)) + UI.escapeHtml(item.source.unit || '') + '</div>' +
          '<div class="stat-card__bar">' +
            '<div class="stat-card__bar-fill" style="width: ' + pct + '%"></div>' +
          '</div>';

        dom.shortcutsGrid.appendChild(card);
      }
      else if (item.type === 'sound') {
        const soundPlayback = UI.parseSoundState(state.soundStateCache[deviceId]);
        const isThisPlaying = soundPlayback.isPlaying && (soundPlayback.soundId === item.sound_id);

        const btn = document.createElement('button');
        btn.className = 'shortcut-btn shortcut-btn--sound' + (isThisPlaying ? ' shortcut-btn--playing' : '');
        btn.type = 'button';
        btn.style.setProperty('--i', index);
        btn.dataset.soundId = item.sound_id;
        btn.disabled = false;

        btn.innerHTML = 
          '<span class="shortcut-btn__icon">' + UI.escapeHtml(UI.iconFor(item)) + '</span>' +
          '<span>' + UI.escapeHtml(item.label || 'Som') + '</span>' +
          '<span class="sound-wave-badge" aria-hidden="true"><span></span><span></span><span></span></span>';

        btn.addEventListener('click', () => {
          const currentState = UI.parseSoundState(state.soundStateCache[deviceId]);
          const isCurrentlyPlayingThis = currentState.isPlaying && (currentState.soundId === item.sound_id);
          const device = state.devices[deviceId];
          if (!device) return;

          if (isCurrentlyPlayingThis) {
            MqttLayer.publishCommand(device, 'stop_sound');
          } else {
            MqttLayer.publishCommand(device, 'play_sound', { sound_id: item.sound_id });
          }
        });
        dom.shortcutsGrid.appendChild(btn);
      }
      else {
        const btn = document.createElement('button');
        btn.className = 'shortcut-btn';
        btn.type = 'button';
        btn.style.setProperty('--i', index);
        btn.innerHTML = 
          '<span class="shortcut-btn__icon">' + UI.escapeHtml(UI.iconFor(item)) + '</span>' +
          '<span>' + UI.escapeHtml(item.label || item.id || 'Sem Nome') + '</span>';

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
    this.parseEmojis(dom.shortcutsGrid);
  },

  renderNowPlaying(data) {
    if (!data) {
      dom.npTitle.textContent = 'Nenhuma mídia tocando';
      dom.npArtist.textContent = '-';
      dom.npIcon.textContent = '\u{1F3B5}';
      dom.npIcon.classList.remove('np-icon--playing');
      dom.nowPlaying.classList.add('now-playing--empty');
      this.parseEmojis(dom.npIcon);
      return;
    }
    const isPlaying = data.status === 'Playing';
    dom.npTitle.textContent = data.title || 'Desconhecido';
    dom.npArtist.textContent = data.artist || 'Desconhecido';
    dom.npIcon.textContent = isPlaying ? '\u25B6\uFE0F' : '\u23F8\uFE0F';
    dom.npIcon.classList.toggle('np-icon--playing', isPlaying);
    dom.nowPlaying.classList.remove('now-playing--empty');
    this.parseEmojis(dom.npIcon);
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
      const vol = app.volume !== undefined ? app.volume : 0;
      
      row.innerHTML = 
        '<div class="app-mixer-row__label">' +
          '<span class="app-mixer-row__name">' + (app.name || app.id) + '</span>' +
          '<span class="app-mixer-row__value">' + vol + '%</span>' +
        '</div>' +
        '<input type="range" min="0" max="100" step="1" value="' + vol + '" data-app-id="' + app.id + '">';
      
      const input = row.querySelector('input');
      const valueLabel = row.querySelector('.app-mixer-row__value');
      let lastPublish = 0;
      input.addEventListener('input', (e) => {
        const val = e.target.value;
        valueLabel.textContent = val + '%';
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
  UI.parseEmojis(document.body);
  MqttLayer.connect();
}
document.addEventListener('DOMContentLoaded', init);
