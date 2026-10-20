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
  layoutHashCache: {},
  searchOpen: false,
  searchQuery: '',
  searchScope: 'page', // 'page' | 'global'
  searchFilter: 'all', // 'all' | 'sound' | 'slider' | 'shortcut' | 'stat' | 'folder'
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

  btnToggleSearch: document.getElementById('btn-toggle-search'),
  searchSection: document.getElementById('search-section'),
  widgetSearchInput: document.getElementById('widget-search-input'),
  btnClearSearch: document.getElementById('btn-clear-search'),
  btnScopePage: document.getElementById('btn-scope-page'),
  btnScopeGlobal: document.getElementById('btn-scope-global'),
  btnRemotePcSearch: document.getElementById('btn-remote-pc-search'),
  filterChips: document.querySelectorAll('.filter-chip'),

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
    state.mqttClient.subscribe('nodes/+/search');
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
      const nextOnline = !!data.online;
      const statusChanged = (device.online !== nextOnline);
      device.online = nextOnline;
      if (statusChanged) UI.renderDeviceTabs();
      if (state.currentDeviceId === device.id) {
        UI.updateDeviceStatusBadge(device.online);
        UI.setOfflineOverlay(!device.online);
      }
    }
    else if (topicType === 'audio/apps') {
      state.appsCache[device.id] = Array.isArray(data) ? data : (data.apps || []);
      if (state.currentDeviceId === device.id && dom.mixerDrawer.classList.contains('mixer-drawer--open')) {
        UI.renderAppMixer(state.appsCache[device.id]);
      }
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
    else if (topicType === 'search') {
      if (state.currentDeviceId === device.id) {
        var queryText = (data && typeof data.query === 'string') ? data.query : '';
        state.searchQuery = queryText;
        if (dom.widgetSearchInput) {
          dom.widgetSearchInput.value = queryText;
        }
        if (dom.btnClearSearch) {
          dom.btnClearSearch.style.display = queryText.length > 0 ? 'inline-block' : 'none';
        }
        if (!state.searchOpen) {
          state.searchOpen = true;
          if (dom.searchSection) dom.searchSection.style.display = 'flex';
          if (dom.btnToggleSearch) {
            dom.btnToggleSearch.classList.add('btn-pill--active');
            dom.btnToggleSearch.setAttribute('aria-expanded', 'true');
          }
        }
        UI.renderShortcuts(device.id);
      }
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
      if (state.currentDeviceId === device.id) UI.updateStatsInPlace(device.id, kind);
    }
    else if (topicType === 'media') {
      const oldMedia = state.mediaCache[device.id];
      const statusChanged = !oldMedia || oldMedia.status !== data.status;
      state.mediaCache[device.id] = data;
      if (statusChanged) UI.renderDeviceTabs();
      if (state.currentDeviceId === device.id) UI.renderNowPlaying(data);
    }
    else if (topicType === 'layout') {
      if (data.deviceName) {
        const nameChanged = (device.name !== data.deviceName);
        device.name = data.deviceName;
        if (nameChanged) {
          UI.renderDeviceTabs();
          if (state.currentDeviceId === device.id) dom.deviceTitle.textContent = device.name;
        }
      }
      if (data.theme) UI.applyTheme(data.theme);

      const pagesData = data.pages ? data.pages : { home: data.shortcuts || [] };
      const pagesHash = JSON.stringify(pagesData);
      const layoutChanged = (state.layoutHashCache[device.id] !== pagesHash);

      state.shortcutsCache[device.id] = pagesData;
      state.layoutHashCache[device.id] = pagesHash;

      if (layoutChanged) {
        state.currentPageCache[device.id] = 'home';
        if (state.currentDeviceId === device.id) UI.renderShortcuts(device.id);
      }
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
    if (!input) return;
    if (input._isDragging) return;
    const now = Date.now();
    if (input._lastUserInput && (now - input._lastUserInput < 400)) return;
    if (document.activeElement === input) return;

    const strVal = String(value);
    if (input.value !== strVal) {
      input.value = strVal;
    }
    const label = dom.shortcutsGrid.querySelector('output[data-slider-value="' + id + '"]');
    if (label) {
      const txt = value + '%';
      if (label.textContent !== txt) label.textContent = txt;
    }
  },

  updateStatsInPlace(deviceId, targetKind) {
    const stats = state.statsCache[deviceId] || {};
    const selector = targetKind 
      ? '.shortcut-btn--stat[data-stat-kind="' + targetKind + '"]'
      : '.shortcut-btn--stat';
    const cards = dom.shortcutsGrid.querySelectorAll(selector);

    cards.forEach((card) => {
      const kind = card.dataset.statKind;
      const field = card.dataset.statField;
      const unit = card.dataset.statUnit;

      const payload = stats[kind] || {};
      const raw = payload[field];
      const display = (raw === undefined || raw === null) ? '--' : raw;
      const formatted = String(display) + (unit || '');

      const valueEl = card.querySelector('.stat-card__value');
      if (valueEl && valueEl.textContent !== formatted) {
        valueEl.textContent = formatted;
      }

      if (unit === '%' && typeof raw === 'number') {
        const pct = Math.max(0, Math.min(100, raw));
        const barFill = card.querySelector('.stat-card__bar-fill');
        if (barFill) {
          const widthStr = pct + '%';
          if (barFill.style.width !== widthStr) {
            barFill.style.width = widthStr;
          }
        }
        const meterFillV = card.querySelector('.stat-card__meter-fill-v');
        if (meterFillV) {
          const heightStr = pct + '%';
          if (meterFillV.style.height !== heightStr) {
            meterFillV.style.height = heightStr;
          }
        }
      }

      const detailEl = card.querySelector('.stat-card__detail');
      if (detailEl) {
        let detailText = '';
        if (kind === 'cpu') {
          if (typeof payload.temp === 'number') detailText += payload.temp + '°C';
          if (typeof payload.freq_mhz === 'number') {
            detailText += (detailText ? ' • ' : '') + payload.freq_mhz + ' MHz';
          }
          if (!detailText) detailText = 'Processador';
        } else if (kind === 'ram') {
          if (typeof payload.used_mb === 'number' && typeof payload.total_mb === 'number') {
            detailText = (payload.used_mb / 1024).toFixed(1) + ' GB / ' + (payload.total_mb / 1024).toFixed(1) + ' GB';
          } else {
            detailText = 'Memória do Sistema';
          }
        } else if (kind === 'disk') {
          if (typeof payload.used_gb === 'number' && typeof payload.total_gb === 'number') {
            detailText = payload.used_gb + ' GB / ' + payload.total_gb + ' GB';
          } else {
            detailText = 'Armazenamento';
          }
        }
        if (detailEl.textContent !== detailText) {
          detailEl.textContent = detailText;
        }
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
      const currentlyPlaying = btn.classList.contains('shortcut-btn--playing');
      if (currentlyPlaying !== isThisPlaying) {
        btn.classList.toggle('shortcut-btn--playing', isThisPlaying);
      }
    });
  },

  resolveGridPlacements(items, cols) {
    const occupied = [];
    function ensureRows(targetRowExclusive) {
      while (occupied.length < targetRowExclusive) {
        const rowArr = [];
        for (let c = 0; c < cols; c++) rowArr.push(false);
        occupied.push(rowArr);
      }
    }
    function canFitAt(r, c, w, h) {
      if (c < 0 || c + w > cols || r < 0) return false;
      ensureRows(r + h);
      for (let dr = 0; dr < h; dr++) {
        for (let dc = 0; dc < w; dc++) {
          if (occupied[r + dr][c + dc]) return false;
        }
      }
      return true;
    }
    function markOccupied(r, c, w, h) {
      ensureRows(r + h);
      for (let dr = 0; dr < h; dr++) {
        for (let dc = 0; dc < w; dc++) {
          occupied[r + dr][c + dc] = true;
        }
      }
    }

    const placements = new Array(items.length);
    const unpositioned = [];

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const defaultW = (item.type === 'slider' || item.type === 'stat') ? 2 : 1;
      let w = (typeof item.width === 'number' && item.width >= 1 && item.width <= 2) ? item.width : defaultW;
      const h = (typeof item.height === 'number' && item.height >= 1 && item.height <= 2) ? item.height : 1;
      if (item.type === 'slider') {
        const isVert = (h > w) || (item.height === 2 && item.width !== 2);
        if (isVert) w = 1;
      }

      if (typeof item.x === 'number' && typeof item.y === 'number' && item.x >= 0 && item.y >= 0) {
        const col = Math.min(Math.max(0, Math.floor(item.x)), cols - w);
        const row = Math.max(0, Math.floor(item.y));
        if (canFitAt(row, col, w, h)) {
          markOccupied(row, col, w, h);
          placements[i] = { col: col, row: row, w: w, h: h };
        } else {
          unpositioned.push({ index: i, w: w, h: h });
        }
      } else {
        unpositioned.push({ index: i, w: w, h: h });
      }
    }

    for (let u = 0; u < unpositioned.length; u++) {
      const entry = unpositioned[u];
      const w = entry.w;
      const h = entry.h;
      let row = 0;
      let col = 0;
      let found = false;
      while (!found) {
        ensureRows(row + h);
        for (let c = 0; c <= cols - w; c++) {
          if (canFitAt(row, c, w, h)) {
            col = c;
            found = true;
            break;
          }
        }
        if (!found) row++;
      }
      markOccupied(row, col, w, h);
      placements[entry.index] = { col: col, row: row, w: w, h: h };
    }

    return placements;
  },

  isSearchActive() {
    return state.searchOpen && (
      (state.searchQuery && state.searchQuery.trim().length > 0) ||
      state.searchFilter !== 'all' ||
      state.searchScope === 'global'
    );
  },

  getFilteredItems(deviceId) {
    const pages = state.shortcutsCache[deviceId];
    if (!pages) return [];

    let pool = [];
    const currentPageId = state.currentPageCache[deviceId] || 'home';

    if (state.searchScope === 'global') {
      const pageKeys = Object.keys(pages);
      for (let k = 0; k < pageKeys.length; k++) {
        const pageKey = pageKeys[k];
        const pageTiles = pages[pageKey] || [];
        for (let t = 0; t < pageTiles.length; t++) {
          const tile = pageTiles[t];
          const copy = Object.assign({}, tile);
          copy._pageId = pageKey;
          copy.x = undefined;
          copy.y = undefined;
          pool.push(copy);
        }
      }
    } else {
      const pageTiles = pages[currentPageId] || [];
      for (let t = 0; t < pageTiles.length; t++) {
        const tile = pageTiles[t];
        const copy = Object.assign({}, tile);
        copy._pageId = currentPageId;
        copy.x = undefined;
        copy.y = undefined;
        pool.push(copy);
      }
    }

    // Remover 'back' pois navegação para voltar não deve aparecer nos resultados
    pool = pool.filter(function(item) { return item.type !== 'back'; });

    // Filtro por tipo
    if (state.searchFilter !== 'all') {
      pool = pool.filter(function(item) {
        if (state.searchFilter === 'sound') return item.type === 'sound';
        if (state.searchFilter === 'slider') return item.type === 'slider';
        if (state.searchFilter === 'stat') return item.type === 'stat';
        if (state.searchFilter === 'folder') return item.type === 'folder';
        if (state.searchFilter === 'shortcut') return item.type === 'shortcut' || !item.type;
        return true;
      });
    }

    // Filtro por query de texto
    const q = (state.searchQuery || '').trim().toLowerCase();
    if (q.length > 0) {
      pool = pool.filter(function(item) {
        const label = (item.label || '').toLowerCase();
        const id = (item.id || '').toLowerCase();
        const soundId = (item.sound_id || '').toLowerCase();
        const target = (item.target || '').toLowerCase();
        return label.indexOf(q) !== -1 ||
               id.indexOf(q) !== -1 ||
               soundId.indexOf(q) !== -1 ||
               target.indexOf(q) !== -1;
      });
    }

    return pool;
  },

  resetSearchFilters(deviceId, rerender) {
    state.searchQuery = '';
    state.searchFilter = 'all';
    state.searchScope = 'page';

    if (dom.widgetSearchInput) dom.widgetSearchInput.value = '';
    if (dom.btnClearSearch) dom.btnClearSearch.style.display = 'none';

    if (dom.btnScopePage) dom.btnScopePage.classList.add('scope-btn--active');
    if (dom.btnScopeGlobal) dom.btnScopeGlobal.classList.remove('scope-btn--active');

    if (dom.filterChips) {
      dom.filterChips.forEach(function(chip) {
        const isAll = chip.getAttribute('data-filter') === 'all';
        chip.classList.toggle('filter-chip--active', isAll);
      });
    }

    if (rerender !== false) {
      UI.renderShortcuts(deviceId || state.currentDeviceId);
    }
  },

  renderShortcuts(deviceId) {
    dom.shortcutsGrid.innerHTML = '';
    const pages = state.shortcutsCache[deviceId];
    if (!pages) return;

    let renderList;
    const isSearching = this.isSearchActive();

    if (isSearching) {
      renderList = this.getFilteredItems(deviceId);
      if (renderList.length === 0) {
        dom.shortcutsGrid.innerHTML = 
          '<div class="shortcuts-empty">' +
            '<p>Nenhum widget encontrado com os filtros selecionados.</p>' +
            '<button type="button" class="btn-reset-filters" id="btn-reset-filters">Limpar filtros</button>' +
          '</div>';
        const btnReset = document.getElementById('btn-reset-filters');
        if (btnReset) {
          btnReset.addEventListener('click', function() {
            UI.resetSearchFilters(deviceId, true);
          });
        }
        return;
      }
    } else {
      const currentPageId = state.currentPageCache[deviceId] || 'home';
      const items = pages[currentPageId] || [];
      const hasExplicitBack = items.some((item) => item.type === 'back');

      renderList = (currentPageId !== 'home' && !hasExplicitBack)
        ? [{ type: 'back', icon: '⬅️', label: 'Voltar', x: 0, y: 0 }].concat(items)
        : items;
    }

    const placements = this.resolveGridPlacements(renderList, 6);

    renderList.forEach((item, index) => {
      const pos = placements[index];
      const w = pos.w;
      const h = pos.h;
      const gridColumnStyle = (pos.col + 1) + ' / span ' + w;
      const gridRowStyle = (pos.row + 1) + ' / span ' + h;

      const dimClasses = ' tile--w-' + w + ' tile--h-' + h;
      const showPageBadge = isSearching && state.searchScope === 'global' && !!item._pageId;
      const pageBadgeHtml = showPageBadge
        ? '<span class="tile-page-badge" title="Página: ' + UI.escapeHtml(item._pageId) + '">&#128196; ' + UI.escapeHtml(item._pageId) + '</span>'
        : '';

      if (item.type === 'slider') {
        const isVertical = h > w;
        const card = document.createElement('div');
        card.className = 'shortcut-btn shortcut-btn--slider' + (isVertical ? ' shortcut-btn--slider-vertical' : '') + dimClasses;
        card.style.setProperty('--i', index);
        card.style.gridColumn = gridColumnStyle;
        card.style.gridRow = gridRowStyle;

        let val = 50;
        if (item.id === 'master_volume') {
          val = typeof state.volumeCache[deviceId] === 'number' ? state.volumeCache[deviceId] : 50;
        } else {
          // Remoção segura do operador ?. e ??
          if (state.slidersCache[deviceId] && state.slidersCache[deviceId][item.id] !== undefined) {
            val = state.slidersCache[deviceId][item.id];
          }
        }

        if (isVertical) {
          card.innerHTML = 
            '<div class="shortcut-slider__header shortcut-slider__header--vertical">' +
              '<span class="shortcut-slider__icon">' + UI.escapeHtml(UI.iconFor(item)) + '</span>' +
              '<output class="shortcut-slider__value" data-slider-value="' + item.id + '">' + val + '%</output>' +
            '</div>' +
            '<div class="shortcut-slider__track-v">' +
              '<input type="range" class="slider-vertical" data-slider-id="' + item.id + '" min="0" max="100" value="' + val + '">' +
            '</div>' +
            '<div class="shortcut-slider__label-v">' + UI.escapeHtml(item.label || item.id) + '</div>';
        } else {
          card.innerHTML = 
            '<div class="shortcut-slider__header">' +
              '<div class="shortcut-slider__title">' +
                '<span class="shortcut-slider__icon">' + UI.escapeHtml(UI.iconFor(item)) + '</span>' +
                '<span>' + UI.escapeHtml(item.label || item.id) + '</span>' +
              '</div>' +
              '<output class="shortcut-slider__value" data-slider-value="' + item.id + '">' + val + '%</output>' +
            '</div>' +
            '<input type="range" class="slider-horizontal" data-slider-id="' + item.id + '" min="0" max="100" value="' + val + '">';
        }

        const input = card.querySelector('input');
        const output = card.querySelector('output');
        let lastPublish = 0;

        const markDragging = () => { input._isDragging = true; input._lastUserInput = Date.now(); };
        const unmarkDragging = () => { input._isDragging = false; input._lastUserInput = Date.now(); };

        input.addEventListener('touchstart', markDragging, { passive: true });
        input.addEventListener('touchend', unmarkDragging, { passive: true });
        input.addEventListener('touchcancel', unmarkDragging, { passive: true });
        input.addEventListener('mousedown', markDragging);
        input.addEventListener('mouseup', unmarkDragging);

        input.addEventListener('input', (e) => {
          input._lastUserInput = Date.now();
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
        if (showPageBadge) card.insertAdjacentHTML('afterbegin', pageBadgeHtml);
        dom.shortcutsGrid.appendChild(card);
      }
      else if (item.type === 'stat') {
        const stats = state.statsCache[deviceId] || {};
        const payload = stats[item.source.kind] || {};
        const raw = payload[item.source.field];
        const display = (raw === undefined || raw === null) ? '--' : raw;

        const card = document.createElement('div');
        const is1x1 = (w === 1 && h === 1);
        const isVertical = (w === 1 && h === 2);
        const isPro = (w === 2 && h === 2);

        let statVariantClass = '';
        if (is1x1) statVariantClass = ' shortcut-btn--stat-1x1';
        else if (isVertical) statVariantClass = ' shortcut-btn--stat-vertical';
        else if (isPro) statVariantClass = ' shortcut-btn--stat-pro';

        card.className = 'shortcut-btn shortcut-btn--stat' + statVariantClass + dimClasses;
        card.style.setProperty('--i', index);
        card.style.gridColumn = gridColumnStyle;
        card.style.gridRow = gridRowStyle;
        card.dataset.statKind = item.source.kind;
        card.dataset.statField = item.source.field;
        card.dataset.statUnit = item.source.unit || '';

        const pct = item.source.unit === '%' && typeof raw === 'number'
          ? Math.max(0, Math.min(100, raw))
          : 0;

        if (isVertical) {
          card.innerHTML = 
            '<div class="stat-card__header">' +
              '<span class="stat-card__icon">' + UI.escapeHtml(UI.iconFor(item)) + '</span>' +
              '<span class="stat-card__label">' + UI.escapeHtml(item.label || item.id) + '</span>' +
            '</div>' +
            '<div class="stat-card__meter-v">' +
              '<div class="stat-card__meter-fill-v" style="height: ' + pct + '%"></div>' +
            '</div>' +
            '<div class="stat-card__value">' + UI.escapeHtml(String(display)) + UI.escapeHtml(item.source.unit || '') + '</div>';
        } else if (isPro) {
          let detailText = '';
          if (item.source.kind === 'cpu') {
            if (typeof payload.temp === 'number') detailText += payload.temp + '°C';
            if (typeof payload.freq_mhz === 'number') {
              detailText += (detailText ? ' • ' : '') + payload.freq_mhz + ' MHz';
            }
            if (!detailText) detailText = 'Processador';
          } else if (item.source.kind === 'ram') {
            if (typeof payload.used_mb === 'number' && typeof payload.total_mb === 'number') {
              detailText = (payload.used_mb / 1024).toFixed(1) + ' GB / ' + (payload.total_mb / 1024).toFixed(1) + ' GB';
            } else {
              detailText = 'Memória do Sistema';
            }
          } else if (item.source.kind === 'disk') {
            if (typeof payload.used_gb === 'number' && typeof payload.total_gb === 'number') {
              detailText = payload.used_gb + ' GB / ' + payload.total_gb + ' GB';
            } else {
              detailText = 'Armazenamento';
            }
          }
          const badgeLabel = (item.source.kind || 'STAT').toUpperCase();
          card.innerHTML = 
            '<div class="stat-card__pro-header">' +
              '<div class="stat-card__pro-title">' +
                '<span class="stat-card__icon">' + UI.escapeHtml(UI.iconFor(item)) + '</span>' +
                '<span class="stat-card__label">' + UI.escapeHtml(item.label || item.id) + '</span>' +
              '</div>' +
              '<span class="stat-card__badge">' + UI.escapeHtml(badgeLabel) + '</span>' +
            '</div>' +
            '<div class="stat-card__value">' + UI.escapeHtml(String(display)) + UI.escapeHtml(item.source.unit || '') + '</div>' +
            '<div class="stat-card__detail">' + UI.escapeHtml(detailText) + '</div>' +
            '<div class="stat-card__bar">' +
              '<div class="stat-card__bar-fill" style="width: ' + pct + '%"></div>' +
            '</div>';
        } else {
          card.innerHTML = 
            '<div class="stat-card__header">' +
              '<span class="stat-card__icon">' + UI.escapeHtml(UI.iconFor(item)) + '</span>' +
              '<span class="stat-card__label">' + UI.escapeHtml(item.label || item.id) + '</span>' +
            '</div>' +
            '<div class="stat-card__value">' + UI.escapeHtml(String(display)) + UI.escapeHtml(item.source.unit || '') + '</div>' +
            '<div class="stat-card__bar">' +
              '<div class="stat-card__bar-fill" style="width: ' + pct + '%"></div>' +
            '</div>';
        }

        if (showPageBadge) card.insertAdjacentHTML('afterbegin', pageBadgeHtml);
        dom.shortcutsGrid.appendChild(card);
      }
      else if (item.type === 'sound') {
        const soundPlayback = UI.parseSoundState(state.soundStateCache[deviceId]);
        const isThisPlaying = soundPlayback.isPlaying && (soundPlayback.soundId === item.sound_id);

        const btn = document.createElement('button');
        btn.className = 'shortcut-btn shortcut-btn--sound' + (isThisPlaying ? ' shortcut-btn--playing' : '') + dimClasses;
        btn.type = 'button';
        btn.style.setProperty('--i', index);
        btn.style.gridColumn = gridColumnStyle;
        btn.style.gridRow = gridRowStyle;
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
        if (showPageBadge) btn.insertAdjacentHTML('afterbegin', pageBadgeHtml);
        dom.shortcutsGrid.appendChild(btn);
      }
      else {
        const btn = document.createElement('button');
        btn.className = 'shortcut-btn' + dimClasses;
        btn.type = 'button';
        btn.style.setProperty('--i', index);
        btn.style.gridColumn = gridColumnStyle;
        btn.style.gridRow = gridRowStyle;
        btn.innerHTML = 
          '<span class="shortcut-btn__icon">' + UI.escapeHtml(UI.iconFor(item)) + '</span>' +
          '<span>' + UI.escapeHtml(item.label || item.id || 'Sem Nome') + '</span>';

        if (showPageBadge) btn.insertAdjacentHTML('afterbegin', pageBadgeHtml);

        btn.addEventListener('click', () => {
          if (item.type === 'folder' && item.target) {
            state.currentPageCache[deviceId] = item.target;
            if (UI.isSearchActive()) {
              UI.resetSearchFilters(deviceId, false);
            }
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
    if (!apps || apps.length === 0) {
      dom.mixerAppsList.innerHTML = '<p class="mixer-empty-msg">Nenhuma aplicação de áudio ativa no momento.</p>';
      return;
    }

    const existingRows = dom.mixerAppsList.querySelectorAll('.app-mixer-row');
    const existingInputs = dom.mixerAppsList.querySelectorAll('input[data-app-id]');
    const existingIds = [];
    existingInputs.forEach((inp) => existingIds.push(inp.dataset.appId));
    const newIds = apps.map((a) => String(a.id));

    const sameApps = (existingIds.length === newIds.length) && existingIds.every((id, idx) => id === newIds[idx]);

    if (sameApps && existingRows.length === apps.length) {
      apps.forEach((app, idx) => {
        const row = existingRows[idx];
        const input = row.querySelector('input');
        const valueLabel = row.querySelector('.app-mixer-row__value');
        const vol = app.volume !== undefined ? app.volume : 0;
        if (input && !input._isDragging && document.activeElement !== input) {
          const strVol = String(vol);
          if (input.value !== strVol) input.value = strVol;
          if (valueLabel && valueLabel.textContent !== vol + '%') valueLabel.textContent = vol + '%';
        }
      });
      return;
    }

    dom.mixerAppsList.innerHTML = '';
    apps.forEach((app) => {
      const row = document.createElement('div');
      row.className = 'app-mixer-row';
      const vol = app.volume !== undefined ? app.volume : 0;
      
      row.innerHTML = 
        '<div class="app-mixer-row__label">' +
          '<span class="app-mixer-row__name">' + UI.escapeHtml(app.name || app.id) + '</span>' +
          '<span class="app-mixer-row__value">' + vol + '%</span>' +
        '</div>' +
        '<input type="range" min="0" max="100" step="1" value="' + vol + '" data-app-id="' + app.id + '">';
      
      const input = row.querySelector('input');
      const valueLabel = row.querySelector('.app-mixer-row__value');
      let lastPublish = 0;

      const markDragging = () => { input._isDragging = true; };
      const unmarkDragging = () => { input._isDragging = false; };
      input.addEventListener('touchstart', markDragging, { passive: true });
      input.addEventListener('touchend', unmarkDragging, { passive: true });
      input.addEventListener('touchcancel', unmarkDragging, { passive: true });
      input.addEventListener('mousedown', markDragging);
      input.addEventListener('mouseup', unmarkDragging);

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

    if (dom.mixerDrawer.classList.contains('mixer-drawer--open')) {
      UI.renderAppMixer(state.appsCache[deviceId] || []);
    }
    UI.renderShortcuts(deviceId);
    UI.renderNowPlaying(state.mediaCache[deviceId] || null);
    UI.renderDeviceTabs();
    Navigation.closeMixerDrawer();
  },
  openMixerDrawer() {
    dom.mixerDrawer.classList.add('mixer-drawer--open');
    if (state.currentDeviceId) {
      UI.renderAppMixer(state.appsCache[state.currentDeviceId] || []);
    }
  },
  closeMixerDrawer() { dom.mixerDrawer.classList.remove('mixer-drawer--open'); },

  toggleSearch() {
    state.searchOpen = !state.searchOpen;
    if (dom.searchSection) {
      dom.searchSection.style.display = state.searchOpen ? 'flex' : 'none';
    }
    if (dom.btnToggleSearch) {
      dom.btnToggleSearch.classList.toggle('btn-pill--active', state.searchOpen);
      dom.btnToggleSearch.setAttribute('aria-expanded', state.searchOpen ? 'true' : 'false');
    }
    if (state.searchOpen) {
      if (dom.widgetSearchInput) {
        setTimeout(function() {
          dom.widgetSearchInput.focus();
        }, 50);
      }
    } else {
      if (state.searchQuery || state.searchFilter !== 'all' || state.searchScope !== 'page') {
        UI.resetSearchFilters(state.currentDeviceId, true);
      }
    }
  },
};

/* =========================================================
   6. EVENT BINDINGS
   ========================================================= */
function bindEvents() {
  dom.btnToggleMixer.addEventListener('click', Navigation.openMixerDrawer);
  dom.btnCloseMixer.addEventListener('click', Navigation.closeMixerDrawer);
  dom.mixerBackdrop.addEventListener('click', Navigation.closeMixerDrawer);

  if (dom.btnToggleSearch) {
    dom.btnToggleSearch.addEventListener('click', Navigation.toggleSearch);
  }

  if (dom.widgetSearchInput) {
    var searchDebounceTimer = null;
    dom.widgetSearchInput.addEventListener('input', function(e) {
      var val = e.target.value;
      if (dom.btnClearSearch) {
        dom.btnClearSearch.style.display = val.length > 0 ? 'inline-block' : 'none';
      }
      if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
      searchDebounceTimer = setTimeout(function() {
        state.searchQuery = val;
        UI.renderShortcuts(state.currentDeviceId);
      }, 150);
    });
  }

  if (dom.btnClearSearch) {
    dom.btnClearSearch.addEventListener('click', function() {
      state.searchQuery = '';
      if (dom.widgetSearchInput) dom.widgetSearchInput.value = '';
      dom.btnClearSearch.style.display = 'none';
      UI.renderShortcuts(state.currentDeviceId);
      if (dom.widgetSearchInput) dom.widgetSearchInput.focus();
    });
  }

  if (dom.btnScopePage) {
    dom.btnScopePage.addEventListener('click', function() {
      if (state.searchScope === 'page') return;
      state.searchScope = 'page';
      dom.btnScopePage.classList.add('scope-btn--active');
      if (dom.btnScopeGlobal) dom.btnScopeGlobal.classList.remove('scope-btn--active');
      UI.renderShortcuts(state.currentDeviceId);
    });
  }

  if (dom.btnScopeGlobal) {
    dom.btnScopeGlobal.addEventListener('click', function() {
      if (state.searchScope === 'global') return;
      state.searchScope = 'global';
      dom.btnScopeGlobal.classList.add('scope-btn--active');
      if (dom.btnScopePage) dom.btnScopePage.classList.remove('scope-btn--active');
      UI.renderShortcuts(state.currentDeviceId);
    });
  }

  if (dom.btnRemotePcSearch) {
    dom.btnRemotePcSearch.addEventListener('click', function() {
      var device = state.devices[state.currentDeviceId];
      if (!device || !device.online) {
        UI.showToast({ message: 'Dispositivo host offline.', level: 'warn' });
        return;
      }
      if (!state.searchOpen) {
        Navigation.toggleSearch();
      }
      MqttLayer.publishCommand(device, 'remote_search_prompt');
      UI.showToast({ message: 'Digite a busca no teclado do PC...', level: 'info' });
    });
  }

  if (dom.filterChips) {
    dom.filterChips.forEach(function(chip) {
      chip.addEventListener('click', function() {
        var filterType = chip.getAttribute('data-filter') || 'all';
        if (state.searchFilter === filterType) return;
        state.searchFilter = filterType;
        dom.filterChips.forEach(function(c) {
          c.classList.toggle('filter-chip--active', c === chip);
        });
        UI.renderShortcuts(state.currentDeviceId);
      });
    });
  }
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
