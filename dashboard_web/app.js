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
  'music_note': '🎵', 'headphones': '🎧', 'radio': '📻', 'mic': '🎙️', 'mic_off': '🔇',
  'tv': '📺', 'graphic_eq': '🎛️', 'equalizer': '🎛️', 'tune': '🎚️',

  // Navegação & UI
  'arrow_back': '⬅️', 'arrow_forward': '➡️', 'arrow_upward': '⬆️', 'arrow_downward': '⬇️',
  'home': '🏠', 'dashboard': '📊', 'refresh': '🔄', 'search': '🔍', 'settings': '⚙️',
  'close': '❌', 'check': '✔️', 'add': '➕', 'remove': '➖', 'delete': '🗑️', 'push_pin': '📌',
  'location_on': '📍', 'link': '🔗', 'notifications': '🔔', 'notifications_off': '🔕',
  'lock': '🔒', 'lock_open': '🔓', 'visibility': '👁️', 'visibility_off': '🙈',
  'palette': '🎨', 'timer': '⏱️', 'alarm': '⏰', 'hourglass_empty': '⏳',
  'rocket_launch': '🚀', 'flash_on': '⚡',

  // Pastas & Arquivos
  'folder': '📁', 'folder_open': '📂', 'folder_zip': '📦', 'insert_drive_file': '📄',
  'cloud_upload': '☁️⬆️', 'cloud_download': '☁️⬇️', 'bar_chart': '📊',
  'show_chart': '📈', 'content_paste': '📋', 'inventory_2': '📦',

  // Dispositivos & Hardware
  'computer': '💻', 'desktop_windows': '🖥️', 'smartphone': '📱', 'watch': '⌚',
  'keyboard': '⌨️', 'mouse': '🖱️', 'print': '🖨️', 'battery_full': '🔋',
  'power': '🔌', 'power_settings_new': '⏻', 'restart_alt': '🔄', 'lightbulb': '💡',
  'flashlight_on': '🔦', 'photo_camera': '📷', 'screenshot': '📸', 'videocam': '📹',
  'videocam_off': '🚫📹', 'brightness_high': '☀️', 'brightness_low': '🔅',
  'fullscreen': '⛶', 'fullscreen_exit': '🗗', 'language': '🌐',

  // Comunicação & Apps
  'local_fire_department': '🔥', 'chat': '💬', 'smart_toy': '🤖',
  'sports_esports': '🎮', 'videogame_asset': '🕹️',
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
  toggleStatesCache: {},
  mediaCache: {},
  shortcutsCache: {},
  currentPageCache: {},
  statsCache: {},
  soundStateCache: {},
  layoutHashCache: {},
  eventsCache: {},
  unreadEvents: {},
  eventsDrawerOpen: false,
  mediaDrawerOpen: false,
  todoDrawerOpen: false,
  pomodoroCache: {},
  pomodoroTimer: null,
  todosCache: {},
  mediaTimelineTimer: null,
  mediaSeeking: false,
  mediaPosition: 0,
  mediaDuration: 0,
  mediaPlaybackRate: 1.0,
  mediaStatus: 'Stopped',
  searchOpen: false,
  searchQuery: '',
  searchScope: 'page', // 'page' | 'global'
  searchFilter: 'all', // 'all' | 'sound' | 'slider' | 'shortcut' | 'stat' | 'toggle' | 'pomodoro' | 'todo' | 'folder'
  ambientActive: false,
  ambientTimeoutSec: 0,
  ambientInactivityTimer: null,
  clockTimer: null,
  sidebarOpen: false,
  batteryDrawerOpen: false,
  clipboardDrawerOpen: false,
  batteriesCache: {},
  tabletBattery: null,
  micCache: {},
  audioOutputsCache: {},
  activeAppCache: {},
  pageRulesCache: {},
  autoSwitchEnabled: true,
  clipboardCache: {},
  screensaverCache: {},
  weatherCache: {},
  statsHistory: {},
  pageContainers: {},
  staticIconCache: {},
  lastGlobalTouchEndTime: 0,
  lastPageSwitchTime: 0,
  domCache: {
    sliders: {},
    masterSliders: [],
    appSliders: [],
    toggles: {},
    sounds: [],
    stats: {}
  },
};

/* =========================================================
   3. DOM REFS
   ========================================================= */
const dom = {
  appShell: document.getElementById('app-shell'),
  sidebarBackdrop: document.getElementById('sidebar-backdrop'),
  btnToggleSidebar: document.getElementById('btn-toggle-sidebar'),
  deviceTabs: document.getElementById('device-tabs'),
  brokerStatus: document.getElementById('broker-status'),
  deviceStatusDot: document.getElementById('device-status-dot'),
  deviceTitle: document.getElementById('device-title'),
  pageBreadcrumb: document.getElementById('page-breadcrumb'),
  pageBreadcrumbLabel: document.getElementById('page-breadcrumb-label'),
  pagePillsBar: document.getElementById('page-pills-bar'),
  deviceStatusBadge: document.getElementById('device-status-badge'),
  mainContent: document.getElementById('main-content'),
  offlineOverlay: document.getElementById('offline-overlay'),

  btnStopSoundPill: document.getElementById('btn-stop-sound-pill'),
  btnToggleAutoSwitch: document.getElementById('btn-toggle-autoswitch'),
  btnToggleBatteries: document.getElementById('btn-toggle-batteries'),
  headerBatteryLabel: document.getElementById('header-battery-label'),
  headerClock: document.getElementById('header-clock'),
  btnToggleMic: document.getElementById('btn-toggle-mic'),
  btnToggleClipboard: document.getElementById('btn-toggle-clipboard'),
  btnToggleMedia: document.getElementById('btn-toggle-media'),
  btnToggleAmbient: document.getElementById('btn-toggle-ambient'),
  btnToggleFullscreen: document.getElementById('btn-toggle-fullscreen'),
  ambientOverlay: document.getElementById('ambient-overlay'),
  ambientBgLayer: document.getElementById('ambient-bg-layer'),
  ambientBgImg: document.getElementById('ambient-bg-img'),
  ambientBgDim: document.getElementById('ambient-bg-dim'),
  ambientCanvas: document.getElementById('ambient-canvas'),
  ambientStage: document.getElementById('ambient-stage'),
  ambientFallback: document.getElementById('ambient-fallback'),
  ambientWakeHint: document.getElementById('ambient-wake-hint'),
  ambientClock: document.getElementById('ambient-clock'),
  ambientDate: document.getElementById('ambient-date'),
  ambientBattery: document.getElementById('ambient-battery'),
  ambientPomo: document.getElementById('ambient-pomo'),
  ambientMedia: document.getElementById('ambient-media'),
  ambientTimeoutSelect: document.getElementById('ambient-timeout-select'),

  mixerOutputsSection: document.getElementById('mixer-outputs-section'),
  mixerOutputsList: document.getElementById('mixer-outputs-list'),

  batteryDrawer: document.getElementById('battery-drawer'),
  batteryBackdrop: document.getElementById('battery-backdrop'),
  btnCloseBattery: document.getElementById('btn-close-battery'),
  batteryList: document.getElementById('battery-list'),

  clipboardDrawer: document.getElementById('clipboard-drawer'),
  clipboardBackdrop: document.getElementById('clipboard-backdrop'),
  btnCloseClipboard: document.getElementById('btn-close-clipboard'),
  btnClipPull: document.getElementById('btn-clip-pull'),
  clipPcPreview: document.getElementById('clip-pc-preview'),
  btnClipCopyLocal: document.getElementById('btn-clip-copy-local'),
  btnClipOpenLink: document.getElementById('btn-clip-open-link'),
  clipSendInput: document.getElementById('clip-send-input'),
  btnClipSend: document.getElementById('btn-clip-send'),
  btnClipPaste: document.getElementById('btn-clip-paste'),

  btnToggleSearch: document.getElementById('btn-toggle-search'),
  searchSection: document.getElementById('search-section'),
  widgetSearchInput: document.getElementById('widget-search-input'),
  btnClearSearch: document.getElementById('btn-clear-search'),
  btnScopePage: document.getElementById('btn-scope-page'),
  btnScopeGlobal: document.getElementById('btn-scope-global'),
  btnRemotePcSearch: document.getElementById('btn-remote-pc-search'),
  filterChips: document.querySelectorAll('.filter-chip'),

  btnToggleEvents: document.getElementById('btn-toggle-events'),
  eventsUnreadBadge: document.getElementById('events-unread-badge'),
  eventsDrawer: document.getElementById('events-drawer'),
  eventsBackdrop: document.getElementById('events-backdrop'),
  btnCloseEvents: document.getElementById('btn-close-events'),
  btnClearEvents: document.getElementById('btn-clear-events'),
  eventsList: document.getElementById('events-list'),
  eventsCountLabel: document.getElementById('events-count-label'),

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
  npTimeBadge: document.getElementById('np-time-badge'),
  npProgressFill: document.getElementById('np-progress-fill'),
  npQuickPlay: document.getElementById('np-quick-play'),
  npMiniEq: document.getElementById('np-mini-eq'),

  mediaDrawer: document.getElementById('media-drawer'),
  mediaBackdrop: document.getElementById('media-backdrop'),
  btnCloseMedia: document.getElementById('btn-close-media'),
  mediaStatusPill: document.getElementById('media-status-pill'),
  mediaDiscArt: document.getElementById('media-disc-art'),
  mediaDiscIcon: document.getElementById('media-disc-icon'),
  mediaModalTitle: document.getElementById('media-modal-title'),
  mediaModalArtist: document.getElementById('media-modal-artist'),
  mediaTimeCurrent: document.getElementById('media-time-current'),
  mediaTimeTotal: document.getElementById('media-time-total'),
  mediaSeekSlider: document.getElementById('media-seek-slider'),
  btnMediaRewind: document.getElementById('btn-media-rewind'),
  btnMediaPrev: document.getElementById('btn-media-prev'),
  btnMediaPlayPause: document.getElementById('btn-media-play-pause'),
  btnMediaNext: document.getElementById('btn-media-next'),
  btnMediaFastForward: document.getElementById('btn-media-fast-forward'),
  mediaVolumeSlider: document.getElementById('media-volume-slider'),
  mediaVolumeValue: document.getElementById('media-volume-value'),
  btnMediaVolumeMute: document.getElementById('btn-media-volume-mute'),

  todoDrawer: document.getElementById('todo-drawer'),
  todoBackdrop: document.getElementById('todo-backdrop'),
  btnCloseTodo: document.getElementById('btn-close-todo'),
  btnClearDoneTodo: document.getElementById('btn-clear-done-todo'),
  todoAddForm: document.getElementById('todo-add-form'),
  todoInputText: document.getElementById('todo-input-text'),
  btnAddTodo: document.getElementById('btn-add-todo'),
  btnTodoPcPrompt: document.getElementById('btn-todo-pc-prompt'),
  todoItemsList: document.getElementById('todo-items-list'),
  todoCountLabel: document.getElementById('todo-count-label'),
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
    state.mqttClient.subscribe('nodes/+/audio/mic');
    state.mqttClient.subscribe('nodes/+/audio/outputs');
    state.mqttClient.subscribe('nodes/+/media');
    state.mqttClient.subscribe('nodes/+/sound/state');
    state.mqttClient.subscribe('nodes/+/event');
    state.mqttClient.subscribe('nodes/+/state/+');
    state.mqttClient.subscribe('nodes/+/search');
    state.mqttClient.subscribe('nodes/+/stats/cpu');
    state.mqttClient.subscribe('nodes/+/stats/ram');
    state.mqttClient.subscribe('nodes/+/stats/disk');
    state.mqttClient.subscribe('nodes/+/stats/net');
    state.mqttClient.subscribe('nodes/+/stats/gpu');
    state.mqttClient.subscribe('nodes/+/stats/batteries');
    state.mqttClient.subscribe('nodes/+/active_app');
    state.mqttClient.subscribe('nodes/+/page_rules');
    state.mqttClient.subscribe('nodes/+/clipboard');
    state.mqttClient.subscribe('nodes/+/screensaver');
    state.mqttClient.subscribe('nodes/+/weather');
    state.mqttClient.subscribe('nodes/+/ui/screensaver');
  },

  handleMessage(topic, payloadBuffer) {
    try {
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
      if (state.currentDeviceId === device.id) {
        UI.updateAppSlidersInPlace(device.id);
      }
    }
    else if (topicType === 'audio/volume') {
      if (typeof data.value === 'number') {
        state.volumeCache[device.id] = data.value;
        if (state.currentDeviceId === device.id) {
          UI.updateSliderUI('master_volume', data.value);
          if (state.domCache && state.domCache.masterSliders) {
            for (var ms = 0; ms < state.domCache.masterSliders.length; ms++) {
              UI.updateSliderUI(state.domCache.masterSliders[ms], data.value);
            }
          }
        }
      }
    }
    else if (topicType === 'sound/state') {
      state.soundStateCache[device.id] = data;
      if (state.currentDeviceId === device.id) UI.updateSoundStateInPlace(device.id);
    }
    else if (topicType === 'event') {
      if (!state.eventsCache[device.id]) state.eventsCache[device.id] = [];

      var now = new Date();
      var hours = String(now.getHours());
      if (hours.length < 2) hours = '0' + hours;
      var mins = String(now.getMinutes());
      if (mins.length < 2) mins = '0' + mins;
      var secs = String(now.getSeconds());
      if (secs.length < 2) secs = '0' + secs;
      var timeStr = hours + ':' + mins + ':' + secs;

      var kind = (data && data.kind) ? String(data.kind).toLowerCase() : 'info';
      var message = (data && data.message) ? String(data.message) : '';

      var eventItem = {
        id: 'evt_' + now.getTime() + '_' + Math.random().toString(16).slice(2, 6),
        kind: kind,
        message: message,
        timestamp: now.getTime(),
        timeStr: timeStr
      };

      state.eventsCache[device.id].unshift(eventItem);
      if (state.eventsCache[device.id].length > 50) {
        state.eventsCache[device.id].pop();
      }

      if (state.currentDeviceId === device.id) {
        UI.showToast(data);

        if (state.eventsDrawerOpen) {
          UI.renderEventsList(device.id);
        } else {
          state.unreadEvents[device.id] = (state.unreadEvents[device.id] || 0) + 1;
          UI.updateEventsBadge();
        }
      } else {
        state.unreadEvents[device.id] = (state.unreadEvents[device.id] || 0) + 1;
      }
    }
    else if (topicType === 'search') {
      if (state.currentDeviceId === device.id) {
        var queryText = (data && typeof data.query === 'string') ? data.query : '';
        state.searchQuery = queryText;
        if (data && typeof data.filter === 'string' && data.filter) {
          state.searchFilter = data.filter;
          if (dom.filterChips) {
            dom.filterChips.forEach(function(c) {
              var f = c.getAttribute('data-filter') || 'all';
              c.classList.toggle('filter-chip--active', f === state.searchFilter);
            });
          }
        }
        if (data && typeof data.scope === 'string' && (data.scope === 'all' || data.scope === 'page')) {
          state.searchScope = data.scope;
          if (dom.btnSearchScope) {
            var isAll = state.searchScope === 'all';
            dom.btnSearchScope.textContent = isAll ? 'Todas' : 'Página';
            dom.btnSearchScope.classList.toggle('btn-pill--active', isAll);
          }
        }
        if (dom.widgetSearchInput) {
          dom.widgetSearchInput.value = queryText;
        }
        if (dom.btnClearSearch) {
          dom.btnClearSearch.style.display = queryText.length > 0 ? 'inline-block' : 'none';
        }
        if (!state.searchOpen && (data && data.active !== false)) {
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
    else if (topicType === 'screensaver') {
      if (data && typeof data === 'object') {
        state.screensaverCache[device.id] = data;
        if (state.ambientActive && state.currentDeviceId === device.id) {
          AmbientStudio.renderStage(device.id);
        }
      }
    }
    else if (topicType === 'weather') {
      if (data && typeof data === 'object') {
        state.weatherCache[device.id] = data;
        if (state.ambientActive && state.currentDeviceId === device.id) {
          AmbientStudio.updateByType('weather');
        }
      }
    }
    else if (topicType === 'ui/screensaver') {
      if (state.currentDeviceId === device.id && data && typeof data.action === 'string') {
        if (data.action === 'open') {
          Navigation.openAmbient();
        } else if (data.action === 'close') {
          Navigation.closeAmbient();
        }
      }
    }
    else if (topicType.startsWith('state/')) {
      const tileId = topicParts[3];
      const val = data.value;

      if (tileId === 'pomodoro') {
        state.pomodoroCache[device.id] = data;
        UI.handlePomodoroStateUpdate(device.id, data);
        if (state.currentDeviceId === device.id) {
          if (state.ambientActive) {
            AmbientStudio.updateByType('pomodoro');
          } else {
            UI.updatePomodoroInPlace(device.id);
          }
        }
      } else if (tileId === 'todos') {
        state.todosCache[device.id] = data;
        if (state.currentDeviceId === device.id) {
          if (state.ambientActive) {
            AmbientStudio.updateByType('todos');
          } else {
            UI.updateTodoCardInPlace(device.id);
            if (state.todoDrawerOpen) {
              UI.renderTodoList(device.id);
            }
          }
        }
      } else if (typeof val === 'number') {
        if (!state.slidersCache[device.id]) state.slidersCache[device.id] = {};
        state.slidersCache[device.id][tileId] = val;
        if (!state.ambientActive && state.currentDeviceId === device.id) UI.updateSliderUI(tileId, val);
      } else {
        if (!state.toggleStatesCache[device.id]) state.toggleStatesCache[device.id] = {};
        state.toggleStatesCache[device.id][tileId] = val;
        if (!state.ambientActive && state.currentDeviceId === device.id) UI.updateToggleUI(tileId, val);
      }
    }
    else if (topicType === 'stats/batteries') {
      state.batteriesCache[device.id] = (data && data.devices) ? data.devices : [];
      if (state.currentDeviceId === device.id) {
        if (state.ambientActive) {
          AmbientStudio.updateByType('batteries');
        } else {
          UI.updateBatteryPill();
          if (state.batteryDrawerOpen) UI.renderBatteryDrawer();
        }
      }
    }
    else if (topicType === 'audio/mic') {
      state.micCache[device.id] = data;
      if (!state.ambientActive && state.currentDeviceId === device.id) UI.updateMicButton();
    }
    else if (topicType === 'audio/outputs') {
      state.audioOutputsCache[device.id] = (data && data.devices) ? data.devices : [];
      if (!state.ambientActive && state.currentDeviceId === device.id) UI.renderAudioOutputs();
    }
    else if (topicType === 'page_rules') {
      state.pageRulesCache[device.id] = data || {};
      if (!state.ambientActive && state.currentDeviceId === device.id) UI.updateAutoSwitchButton();
    }
    else if (topicType === 'active_app') {
      state.activeAppCache[device.id] = data || {};
      if (!state.ambientActive && state.currentDeviceId === device.id) UI.applySmartProfileSwitch(device.id);
    }
    else if (topicType === 'clipboard') {
      var clipText = (data && typeof data.text === 'string') ? data.text : '';
      state.clipboardCache[device.id] = clipText;
      if (!state.ambientActive && state.currentDeviceId === device.id) {
        UI.renderClipboardPreview();
        if (!state.clipboardDrawerOpen && clipText) {
          UI.showToast({ message: 'Clipboard recebido do PC', level: 'info' });
        }
      }
    }
    else if (topicType.startsWith('stats/')) {
      const kind = topicParts[3];
      if (!state.statsCache[device.id]) state.statsCache[device.id] = {};
      state.statsCache[device.id][kind] = data;
      UI.pushStatHistory(device.id, kind, data);
      if (state.currentDeviceId === device.id) {
        if (state.ambientActive) {
          AmbientStudio.updateByType(kind === 'net' ? 'network' : 'pc_stats');
        } else {
          UI.scheduleStatsFlush(device.id, kind);
        }
      }
    }
    else if (topicType === 'media') {
      const oldMedia = state.mediaCache[device.id];
      const statusChanged = !oldMedia || oldMedia.status !== data.status;
      state.mediaCache[device.id] = data;
      if (state.ambientActive) {
        if (state.currentDeviceId === device.id) AmbientStudio.updateByType('media');
      } else {
        if (statusChanged) UI.renderDeviceTabs();
        if (state.currentDeviceId === device.id) UI.renderNowPlaying(data);
      }
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
        if (state.pageContainers) {
          state.pageContainers[device.id] = {};
        }
        var curPage = state.currentPageCache[device.id] || 'home';
        if (!pagesData[curPage]) {
          state.currentPageCache[device.id] = 'home';
        }
        if (state.currentDeviceId === device.id) UI.renderShortcuts(device.id);
      }
    }
  } catch (err) {
    if (window.logMsg) {
      window.logMsg('MQTT MSG ERR: ' + (err && err.message ? err.message : err), '#f55');
    }
    console.error('MQTT message error: ' + topic, err);
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

    if (dom.appShell) {
      var isSingle = devices.length <= 1;
      dom.appShell.classList.toggle('app-shell--single-device', isSingle);
      if (!isSingle) {
        state.sidebarOpen = false;
        dom.appShell.classList.remove('app-shell--sidebar-open');
      }
    }

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
      
      tab.addEventListener('click', () => {
        Navigation.selectDevice(device.id);
        Navigation.closeSidebar();
      });
      dom.deviceTabs.appendChild(tab);
    });
    this.parseEmojis(dom.deviceTabs);
  },

  setOfflineOverlay(isOffline) {
    dom.mainContent.classList.toggle('main-content--disabled', isOffline);
    dom.offlineOverlay.classList.toggle('offline-overlay--active', isOffline);
  },

  escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  },

  findMatchingApp(apps, targetApp) {
    if (!apps || !targetApp) return null;
    var rawTarget = String(targetApp).toLowerCase().trim();
    if (!rawTarget) return null;
    var cleanTarget = (rawTarget.slice(-4) === '.exe') ? rawTarget.slice(0, -4).trim() : rawTarget;
    if (!cleanTarget) return null;

    for (var i = 0; i < apps.length; i++) {
      var app = apps[i];
      var rawName = (app.name || '').toLowerCase().trim();
      var cleanName = (rawName.slice(-4) === '.exe') ? rawName.slice(0, -4).trim() : rawName;
      var rawId = (app.id || '').toLowerCase().trim();
      var cleanId = (rawId.slice(-4) === '.exe') ? rawId.slice(0, -4).trim() : rawId;

      if ((cleanName && (cleanName.indexOf(cleanTarget) !== -1 || cleanTarget.indexOf(cleanName) !== -1)) ||
          (cleanId && (cleanId.indexOf(cleanTarget) !== -1 || cleanTarget.indexOf(cleanId) !== -1))) {
        return app;
      }
    }
    return null;
  },

  iconFor(item) {
    const raw = (item && item.icon) ? String(item.icon).trim() : '';
    if (raw && (raw.indexOf('data:image/') === 0 || raw.indexOf('http://') === 0 || raw.indexOf('https://') === 0)) {
      return '';
    }
    return ICON_MAP[raw] || raw || '⚡';
  },

  renderTileIconHtml(item, customClass, isActive) {
    var raw = (item && item.icon) ? String(item.icon).trim() : '';
    var iconClass = customClass || 'shortcut-btn__icon';
    if (!raw) {
      return '<span class="' + iconClass + '">⚡</span>';
    }
    if (raw.indexOf('data:image/') === 0 || raw.indexOf('http://') === 0 || raw.indexOf('https://') === 0) {
      var defaultItemW = (item && (item.type === 'slider' || item.type === 'stat' || item.type === 'pomodoro')) ? 2 : 1;
      var effW = (item && typeof item.width === 'number') ? item.width : ((item && typeof item.w === 'number') ? item.w : defaultItemW);
      var effH = (item && typeof item.height === 'number') ? item.height : ((item && typeof item.h === 'number') ? item.h : 1);
      var is2x2 = Boolean(effW === 2 && effH === 2);
      var dim = is2x2 ? 68 : 44;
      var animMode = (item && item.animation_mode) ? item.animation_mode : 'always';
      var staticIcon = (item && item.static_icon) ? String(item.static_icon).trim() : '';
      var active = Boolean(isActive || (item && item._isActive));

      var isGif = (raw.indexOf('data:image/gif') === 0 || raw.indexOf('.gif') !== -1);
      var initialSrc = raw;

      if (isGif && (animMode === 'on_tap' || animMode === 'while_playing')) {
        var staticSrc = staticIcon;
        if (!staticSrc && state.staticIconCache && state.staticIconCache[raw]) {
          staticSrc = state.staticIconCache[raw];
        }
        if (animMode === 'while_playing' && active) {
          initialSrc = raw;
        } else {
          initialSrc = staticSrc || raw;
        }
      }

      var staticAttr = staticIcon ? ' data-static-src="' + staticIcon + '"' : '';
      var onloadAttr = (isGif && !staticIcon && (animMode === 'on_tap' || animMode === 'while_playing'))
        ? ' onload="UI.initGifFrame(this)"'
        : '';

      return '<img class="shortcut-btn__img" src="' + initialSrc + '" alt="" width="' + dim + '" height="' + dim + '"' +
        ' data-gif-src="' + raw + '"' +
        staticAttr +
        ' data-gif-mode="' + animMode + '"' +
        onloadAttr +
        ' style="width:' + dim + 'px;height:' + dim + 'px;max-width:' + dim + 'px;max-height:' + dim + 'px;min-width:' + dim + 'px;min-height:' + dim + 'px;display:block;flex-shrink:0;" />';
    }
    var mapped = ICON_MAP[raw] || raw;
    return '<span class="' + iconClass + '">' + UI.escapeHtml(mapped) + '</span>';
  },

  initGifFrame(img) {
    if (!img) return;
    var mode = img.getAttribute('data-gif-mode');
    if (!mode || mode === 'always') return;

    var staticSrc = img.getAttribute('data-static-src');
    if (staticSrc && staticSrc.length > 0) return;
    if (img._hasExtractedStatic) return;
    img._hasExtractedStatic = true;

    var raw = img.getAttribute('data-gif-src') || img.src;
    if (state.staticIconCache && state.staticIconCache[raw]) {
      img.setAttribute('data-static-src', state.staticIconCache[raw]);
      if (mode === 'on_tap' || (mode === 'while_playing' && !img.closest('.shortcut-btn--playing'))) {
        img.src = state.staticIconCache[raw];
      }
      return;
    }

    try {
      var canvas = document.createElement('canvas');
      var w = img.naturalWidth || img.width || 44;
      var h = img.naturalHeight || img.height || 44;
      canvas.width = w;
      canvas.height = h;
      if (w > 0 && h > 0) {
        var ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, w, h);
        var extractedStatic = canvas.toDataURL('image/png');
        if (state.staticIconCache) {
          state.staticIconCache[raw] = extractedStatic;
        }
        img.setAttribute('data-static-src', extractedStatic);
        if (mode === 'on_tap' || (mode === 'while_playing' && !img.closest('.shortcut-btn--playing'))) {
          img.src = extractedStatic;
        }
      }
    } catch (e) {}
  },

  addFastTapListener(el, callback) {
    if (!el || typeof callback !== 'function') return;
    var startX = 0;
    var startY = 0;
    var moved = false;
    var handledTouch = false;

    el.addEventListener('touchstart', function(e) {
      if (e.touches && e.touches.length === 1) {
        startX = e.touches[0].clientX;
        startY = e.touches[0].clientY;
        moved = false;
      }
    }, { passive: true });

    el.addEventListener('touchmove', function(e) {
      if (e.touches && e.touches.length === 1) {
        var dx = Math.abs(e.touches[0].clientX - startX);
        var dy = Math.abs(e.touches[0].clientY - startY);
        if (dx > 10 || dy > 10) {
          moved = true;
        }
      }
    }, { passive: true });

    el.addEventListener('touchend', function(e) {
      if (!moved) {
        state.lastGlobalTouchEndTime = Date.now();
        handledTouch = true;
        if (e.cancelable) {
          e.preventDefault();
        }
        callback(e);
        setTimeout(function() {
          handledTouch = false;
        }, 600);
      }
    });

    el.addEventListener('click', function(e) {
      var timeSinceTouch = Date.now() - (state.lastGlobalTouchEndTime || 0);
      if (handledTouch || timeSinceTouch < 600) {
        e.preventDefault();
        e.stopPropagation();
        return;
      }
      callback(e);
    });
  },

  triggerTapAnimation(container) {
    if (!container) return;
    var img = container.querySelector('img[data-gif-mode="on_tap"]');
    if (!img) return;
    var gifSrc = img.getAttribute('data-gif-src');
    var staticSrc = img.getAttribute('data-static-src') || (state.staticIconCache && state.staticIconCache[gifSrc]);
    if (!gifSrc) return;

    if (img._gifTimer) {
      clearTimeout(img._gifTimer);
      img._gifTimer = null;
    }

    img.src = '';
    img.src = gifSrc;

    if (staticSrc && staticSrc !== gifSrc) {
      img._gifTimer = setTimeout(function() {
        img.src = staticSrc;
        img._gifTimer = null;
      }, 1500);
    }
  },

  wakeGifsInContainer(container) {
    if (!container) return;
    try {
      var imgs = container.querySelectorAll('img.shortcut-btn__img');
      for (var i = 0; i < imgs.length; i++) {
        var img = imgs[i];
        var mode = img.getAttribute('data-gif-mode') || 'always';
        var gifSrc = img.getAttribute('data-gif-src') || img.src;
        if (mode === 'always' && gifSrc && (gifSrc.indexOf('data:image/gif') === 0 || gifSrc.indexOf('.gif') !== -1)) {
          var s = img.src;
          img.src = '';
          img.src = s;
        }
      }
    } catch (e) {}
  },

  updateBreadcrumb(deviceId) {
    var currentPageId = (state.currentPageCache && state.currentPageCache[deviceId]) || 'home';
    if (dom.pageBreadcrumb) {
      if (currentPageId !== 'home') {
        if (dom.pageBreadcrumbLabel) {
          dom.pageBreadcrumbLabel.textContent = currentPageId.toUpperCase();
        } else {
          dom.pageBreadcrumb.textContent = currentPageId.toUpperCase();
        }
        dom.pageBreadcrumb.style.display = 'inline-flex';
      } else {
        dom.pageBreadcrumb.style.display = 'none';
      }
    }
    this.renderPagePills(deviceId);
  },

  renderPagePills(deviceId) {
    if (!dom.pagePillsBar) return;
    var pages = (deviceId && state.shortcutsCache[deviceId]) ? state.shortcutsCache[deviceId] : null;
    if (!pages) {
      dom.pagePillsBar.style.display = 'none';
      return;
    }
    var keys = Object.keys(pages);
    if (keys.length <= 1) {
      dom.pagePillsBar.style.display = 'none';
      return;
    }
    var ordered = [];
    if (pages['home']) ordered.push('home');
    for (var i = 0; i < keys.length; i++) {
      if (keys[i] !== 'home') ordered.push(keys[i]);
    }
    var activePage = (state.currentPageCache && state.currentPageCache[deviceId]) || 'home';
    dom.pagePillsBar.style.display = 'flex';
    dom.pagePillsBar.innerHTML = '';
    for (var j = 0; j < ordered.length; j++) {
      (function(pageId) {
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'page-pill' + (pageId === activePage ? ' page-pill--active' : '');
        btn.textContent = pageId === 'home' ? 'Home' : pageId.replace(/_/g, ' ');
        UI.addFastTapListener(btn, function() {
          if (UI.isSearchActive()) {
            UI.resetSearchFilters(deviceId, false);
          }
          UI.switchToPage(deviceId, pageId);
        });
        dom.pagePillsBar.appendChild(btn);
      })(ordered[j]);
    }
  },

  updateSliderFill(input, value) {
    if (!input) return;
    var v = Number(value);
    if (isNaN(v)) v = 0;
    v = Math.max(0, Math.min(100, v));
    var fill = 'linear-gradient(to right, var(--accent-color) 0%, var(--accent-color) ' + v + '%, var(--ctp-crust) ' + v + '%, var(--ctp-crust) 100%)';
    input.style.background = fill;
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
    if (dom.deviceStatusBadge) {
      dom.deviceStatusBadge.textContent = online ? 'Online' : 'Offline';
      dom.deviceStatusBadge.classList.toggle('badge--online', online);
      dom.deviceStatusBadge.classList.toggle('badge--offline', !online);
    }
    if (dom.deviceStatusDot) {
      dom.deviceStatusDot.classList.toggle('status-dot--online', online);
      dom.deviceStatusDot.classList.toggle('status-dot--offline', !online);
      dom.deviceStatusDot.title = online ? 'Online' : 'Offline';
    }
  },

  updateSliderUI(id, value) {
    var cached = state.domCache && state.domCache.sliders && state.domCache.sliders[id];
    var list = [];
    if (cached) {
      list = Array.isArray(cached) ? cached : [cached];
    } else if (dom.shortcutsGrid) {
      var inputs = dom.shortcutsGrid.querySelectorAll('input[data-slider-id="' + id + '"]');
      for (var i = 0; i < inputs.length; i++) {
        var inp = inputs[i];
        var out = inp.parentElement ? inp.parentElement.querySelector('output[data-slider-value="' + id + '"]') : null;
        if (!out && dom.shortcutsGrid) out = dom.shortcutsGrid.querySelector('output[data-slider-value="' + id + '"]');
        list.push({ input: inp, output: out });
      }
    }
    if (!list.length) return;

    var now = Date.now();
    for (var k = 0; k < list.length; k++) {
      var entry = list[k];
      var input = entry.input;
      if (!input || input._isDragging) continue;
      if (input._lastUserInput && (now - input._lastUserInput < 850)) continue;
      if (document.activeElement === input) continue;

      var strVal = String(value);
      if (input.value !== strVal) {
        input.value = strVal;
      }
      UI.updateSliderFill(input, value);
      var label = entry.output;
      if (label) {
        var txt = value + '%';
        if (label.textContent !== txt) label.textContent = txt;
      }
    }
  },

  findTile(deviceId, id) {
    if (!deviceId || !id) return null;
    var pages = state.shortcutsCache[deviceId];
    if (!pages) return null;
    var pageKeys = Object.keys(pages);
    for (var p = 0; p < pageKeys.length; p++) {
      var list = pages[pageKeys[p]] || [];
      for (var i = 0; i < list.length; i++) {
        if (list[i].id === id) {
          return list[i];
        }
      }
    }
    return null;
  },

  updateToggleUI(id, value) {
    var cached = state.domCache && state.domCache.toggles && state.domCache.toggles[id];
    var buttons = [];
    if (cached) {
      buttons = Array.isArray(cached) ? cached : [cached];
    } else if (dom.shortcutsGrid) {
      buttons = dom.shortcutsGrid.querySelectorAll('[data-toggle-id="' + id + '"]');
    }
    if (!buttons || !buttons.length) return;

    const deviceId = state.currentDeviceId;
    const item = UI.findTile(deviceId, id);
    if (!item) return;

    const isB = (String(value).toLowerCase() === 'b' || value === true || value === 1);
    const stateConfig = isB ? item.state_b : item.state_a;
    const icon = stateConfig ? (stateConfig.icon || item.icon || '') : (item.icon || '');
    const label = stateConfig ? (stateConfig.label || item.label || '') : (item.label || '');

    for (var bIdx = 0; bIdx < buttons.length; bIdx++) {
      var btn = buttons[bIdx];
      btn.dataset.toggleState = isB ? 'b' : 'a';
      if (isB) {
        btn.classList.remove('shortcut-btn--toggle-a');
        btn.classList.add('shortcut-btn--toggle-b');
      } else {
        btn.classList.remove('shortcut-btn--toggle-b');
        btn.classList.add('shortcut-btn--toggle-a');
      }

      const existingImg = btn.querySelector('.shortcut-btn__img');
      const existingIcon = btn.querySelector('.shortcut-btn__icon');
      const iconTarget = existingImg || existingIcon;
      if (iconTarget) {
        iconTarget.outerHTML = UI.renderTileIconHtml({
          icon: icon,
          static_icon: item.static_icon,
          animation_mode: item.animation_mode
        });
      }
      const labelEl = btn.querySelector('.shortcut-btn__label');
      if (labelEl) labelEl.textContent = label || item.id;
      const badgeEl = btn.querySelector('.toggle-state-badge');
      if (badgeEl) badgeEl.textContent = isB ? 'B' : 'A';
    }
  },

  updateStatsInPlace(deviceId, targetKind) {
    const stats = state.statsCache[deviceId] || {};
    let cards = (state.domCache && state.domCache.stats && targetKind && state.domCache.stats[targetKind])
      ? state.domCache.stats[targetKind]
      : null;

    if (!cards) {
      const selector = targetKind 
        ? '.shortcut-btn--stat[data-stat-kind="' + targetKind + '"]'
        : '.shortcut-btn--stat';
      cards = dom.shortcutsGrid.querySelectorAll(selector);
    }

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

      const sparkEl = card.querySelector('.stat-sparkline');
      if (sparkEl) {
        UI.renderSparklineSvg(sparkEl, deviceId, kind);
      }
    });
  },

  pushStatHistory(deviceId, kind, payload) {
    if (!deviceId || !kind || !payload) return;
    var val = null;
    if (kind === 'cpu' && typeof payload.load === 'number') val = payload.load;
    else if (kind === 'ram' && typeof payload.percent === 'number') val = payload.percent;
    else if (kind === 'disk' && typeof payload.percent === 'number') val = payload.percent;
    else if (kind === 'net' && typeof payload.rx_kbps === 'number') val = payload.rx_kbps;
    else if (kind === 'gpu' && typeof payload.load === 'number') val = payload.load;
    if (val === null) return;

    if (!state.statsHistory[deviceId]) state.statsHistory[deviceId] = {};
    if (!state.statsHistory[deviceId][kind]) state.statsHistory[deviceId][kind] = [];
    var arr = state.statsHistory[deviceId][kind];
    arr.push(val);
    if (arr.length > 20) arr.shift();
  },

  renderSparklineSvg(svgEl, deviceId, kind) {
    if (!svgEl) return;
    var arr = (state.statsHistory[deviceId] && state.statsHistory[deviceId][kind]) ? state.statsHistory[deviceId][kind] : [];
    if (arr.length < 2) return;
    var maxVal = (kind === 'net') ? Math.max.apply(null, arr.concat([100])) : 100;
    if (maxVal <= 0) maxVal = 100;
    var w = 200;
    var h = 30;
    var pts = [];
    for (var i = 0; i < arr.length; i++) {
      var x = (i / (arr.length - 1)) * w;
      var y = h - 3 - ((Math.min(maxVal, Math.max(0, arr[i])) / maxVal) * (h - 6));
      pts.push(x.toFixed(1) + ',' + y.toFixed(1));
    }
    var poly = svgEl.querySelector('polyline');
    if (poly) poly.setAttribute('points', pts.join(' '));
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
    if (dom.btnStopSoundPill && deviceId === state.currentDeviceId) {
      dom.btnStopSoundPill.style.display = soundPlayback.isPlaying ? 'inline-flex' : 'none';
    }
    const soundButtons = (state.domCache && state.domCache.sounds && state.domCache.sounds.length > 0)
      ? state.domCache.sounds
      : dom.shortcutsGrid.querySelectorAll('.shortcut-btn--sound');

    for (var i = 0; i < soundButtons.length; i++) {
      var btn = soundButtons[i];
      var soundId = btn.dataset.soundId;
      var isThisPlaying = soundPlayback.isPlaying && (soundId === soundPlayback.soundId);
      var currentlyPlaying = btn.classList.contains('shortcut-btn--playing');
      if (currentlyPlaying !== isThisPlaying) {
        btn.classList.toggle('shortcut-btn--playing', isThisPlaying);
      }

      var img = btn.querySelector('img[data-gif-mode="while_playing"]');
      if (img) {
        var gifSrc = img.getAttribute('data-gif-src');
        var staticSrc = img.getAttribute('data-static-src') || (state.staticIconCache && state.staticIconCache[gifSrc]);
        var targetSrc = isThisPlaying ? gifSrc : (staticSrc || gifSrc);
        if (targetSrc && (!img._currentSrc || img._currentSrc !== targetSrc)) {
          img._currentSrc = targetSrc;
          img.src = targetSrc;
        }
      }
    }
  },

  updateAppSlidersInPlace(deviceId) {
    try {
      const apps = state.appsCache[deviceId] || [];
      if (!apps.length) return;
      var appSliders = state.domCache && state.domCache.appSliders;
      if (appSliders && appSliders.length > 0) {
        for (var i = 0; i < appSliders.length; i++) {
          var sInfo = appSliders[i];
          var foundApp = UI.findMatchingApp(apps, sInfo.match);
          if (foundApp && typeof foundApp.volume === 'number') {
            if (!state.slidersCache[deviceId]) state.slidersCache[deviceId] = {};
            state.slidersCache[deviceId][sInfo.id] = foundApp.volume;
            UI.updateSliderUI(sInfo.id, foundApp.volume);
          }
        }
        return;
      }

      const sliders = dom.shortcutsGrid.querySelectorAll('.shortcut-btn--slider');
      sliders.forEach(function(card) {
        const input = card.querySelector('input[data-slider-id]');
        if (!input || input._isDragging) return;
        const sliderId = input.getAttribute('data-slider-id');
        const item = UI.findTile(deviceId, sliderId);
        if (!item || !item.source || item.source.kind !== 'app_volume') return;

        var foundApp = UI.findMatchingApp(apps, item.source.match);
        if (foundApp && typeof foundApp.volume === 'number') {
          if (!state.slidersCache[deviceId]) state.slidersCache[deviceId] = {};
          state.slidersCache[deviceId][sliderId] = foundApp.volume;
          UI.updateSliderUI(sliderId, foundApp.volume);
        }
      });
    } catch (err) {
      if (window.logMsg) window.logMsg('ERR updateAppSliders: ' + err, '#f55');
    }
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
      const defaultW = (item.type === 'slider' || item.type === 'stat' || item.type === 'pomodoro') ? 2 : 1;
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
        if (state.searchFilter === 'toggle') return item.type === 'toggle';
        if (state.searchFilter === 'pomodoro') return item.type === 'pomodoro';
        if (state.searchFilter === 'todo') return item.type === 'todo';
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
        const stateALabel = (item.state_a && item.state_a.label ? item.state_a.label : '').toLowerCase();
        const stateBLabel = (item.state_b && item.state_b.label ? item.state_b.label : '').toLowerCase();
        return label.indexOf(q) !== -1 ||
               id.indexOf(q) !== -1 ||
               soundId.indexOf(q) !== -1 ||
               target.indexOf(q) !== -1 ||
               stateALabel.indexOf(q) !== -1 ||
               stateBLabel.indexOf(q) !== -1;
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
    if (!deviceId) deviceId = state.currentDeviceId;
    if (!deviceId) return;

    const pages = state.shortcutsCache[deviceId];
    if (!pages) {
      dom.shortcutsGrid.innerHTML = '<p class="shortcuts-empty">Sem atalhos configurados.</p>';
      this.updateBreadcrumb(deviceId);
      return;
    }

    const isSearching = this.isSearchActive();
    if (isSearching) {
      if (state.pageContainers && state.pageContainers[deviceId]) {
        var pKeys = Object.keys(state.pageContainers[deviceId]);
        for (var i = 0; i < pKeys.length; i++) {
          state.pageContainers[deviceId][pKeys[i]].classList.add('shortcuts-page--hidden');
        }
      }
      this.renderSearchResults(deviceId);
      this.updateBreadcrumb(deviceId);
      return;
    }

    // Remover container de busca se existir
    var searchContainer = dom.shortcutsGrid.querySelector('.shortcuts-page--search');
    if (searchContainer && searchContainer.parentNode) {
      searchContainer.parentNode.removeChild(searchContainer);
    }
    var emptyMsg = dom.shortcutsGrid.querySelector('.shortcuts-empty');
    if (emptyMsg && emptyMsg.parentNode) {
      emptyMsg.parentNode.removeChild(emptyMsg);
    }

    var currentPageId = state.currentPageCache[deviceId] || 'home';
    if (!pages[currentPageId]) {
      currentPageId = 'home';
      state.currentPageCache[deviceId] = 'home';
    }

    this.switchToPage(deviceId, currentPageId);
    this.schedulePreRender(deviceId);
  },

  switchToPage(deviceId, targetPageId) {
    if (!deviceId) deviceId = state.currentDeviceId;
    if (!deviceId) return;
    if (!targetPageId) targetPageId = 'home';
    state.lastPageSwitchTime = Date.now();
    state.currentPageCache[deviceId] = targetPageId;

    if (!state.pageContainers) state.pageContainers = {};
    if (!state.pageContainers[deviceId]) state.pageContainers[deviceId] = {};

    var targetContainer = state.pageContainers[deviceId][targetPageId];
    if (!targetContainer || !targetContainer.parentNode) {
      targetContainer = this.buildPageContainer(deviceId, targetPageId);
      state.pageContainers[deviceId][targetPageId] = targetContainer;
      dom.shortcutsGrid.appendChild(targetContainer);
    }

    var allPagesInDom = dom.shortcutsGrid.querySelectorAll('.shortcuts-page');
    for (var dIdx = 0; dIdx < allPagesInDom.length; dIdx++) {
      allPagesInDom[dIdx].classList.add('shortcuts-page--hidden');
    }
    targetContainer.classList.remove('shortcuts-page--hidden');
    this.wakeGifsInContainer(targetContainer);

    var searchContainer = dom.shortcutsGrid.querySelector('.shortcuts-page--search');
    if (searchContainer && searchContainer.parentNode) {
      searchContainer.parentNode.removeChild(searchContainer);
    }
    var emptyMsg = dom.shortcutsGrid.querySelector('.shortcuts-empty');
    if (emptyMsg && emptyMsg.parentNode) {
      emptyMsg.parentNode.removeChild(emptyMsg);
    }

    this.updateBreadcrumb(deviceId);
    this.updateSoundStateInPlace(deviceId);
  },

  schedulePreRender(deviceId) {
    var self = this;
    setTimeout(function() {
      var pages = state.shortcutsCache[deviceId];
      if (!pages) return;
      if (!state.pageContainers[deviceId]) state.pageContainers[deviceId] = {};
      var pageNames = Object.keys(pages);
      for (var i = 0; i < pageNames.length; i++) {
        var pName = pageNames[i];
        if (!state.pageContainers[deviceId][pName]) {
          var container = self.buildPageContainer(deviceId, pName);
          container.classList.add('shortcuts-page--hidden');
          state.pageContainers[deviceId][pName] = container;
          dom.shortcutsGrid.appendChild(container);
        }
      }
    }, 40);
  },

  buildPageContainer(deviceId, pageId) {
    var container = document.createElement('div');
    container.className = 'shortcuts-page';
    container.setAttribute('data-page-id', pageId);

    try {
      var pages = state.shortcutsCache[deviceId] || {};
      var items = pages[pageId] || [];
      var hasExplicitBack = items.some(function(item) { return item.type === 'back'; });
      var renderList = (pageId !== 'home' && !hasExplicitBack)
        ? [{ type: 'back', icon: '⬅️', label: 'Voltar', x: 0, y: 0 }].concat(items)
        : items;

      this.populateTiles(deviceId, container, renderList, false);
    } catch (err) {
      if (window.logMsg) {
        window.logMsg('BUILD PAGE ERR (' + pageId + '): ' + (err && err.message ? err.message : err), '#f55');
      }
      console.error('Build page error: ' + pageId, err);
    }
    return container;
  },

  renderSearchResults(deviceId) {
    var oldSearch = dom.shortcutsGrid.querySelector('.shortcuts-page--search');
    if (oldSearch && oldSearch.parentNode) {
      oldSearch.parentNode.removeChild(oldSearch);
    }
    var oldEmpty = dom.shortcutsGrid.querySelector('.shortcuts-empty');
    if (oldEmpty && oldEmpty.parentNode) {
      oldEmpty.parentNode.removeChild(oldEmpty);
    }

    var renderList = this.getFilteredItems(deviceId);
    if (renderList.length === 0) {
      var emptyDiv = document.createElement('div');
      emptyDiv.className = 'shortcuts-empty';
      emptyDiv.innerHTML = 
        '<p>Nenhum widget encontrado com os filtros selecionados.</p>' +
        '<button type="button" class="btn-reset-filters" id="btn-reset-filters">Limpar filtros</button>';
      dom.shortcutsGrid.appendChild(emptyDiv);
      var btnReset = document.getElementById('btn-reset-filters');
      if (btnReset) {
        UI.addFastTapListener(btnReset, function() {
          UI.resetSearchFilters(deviceId, true);
        });
      }
      return;
    }

    var searchContainer = document.createElement('div');
    searchContainer.className = 'shortcuts-page shortcuts-page--search';
    this.populateTiles(deviceId, searchContainer, renderList, true);
    dom.shortcutsGrid.appendChild(searchContainer);
  },

  populateTiles(deviceId, container, renderList, isSearching) {
    const placements = this.resolveGridPlacements(renderList, 6);
    const fragment = document.createDocumentFragment();

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
        const isMaster = (item.id === 'master_volume' || (item.source && item.source.kind === 'master_volume'));
        if (isMaster) {
          val = typeof state.volumeCache[deviceId] === 'number' ? state.volumeCache[deviceId] : 50;
        } else if (state.slidersCache[deviceId] && state.slidersCache[deviceId][item.id] !== undefined) {
          val = state.slidersCache[deviceId][item.id];
        } else if (item.source && item.source.kind === 'app_volume' && item.source.match) {
          var apps = state.appsCache[deviceId] || [];
          var matchingApp = UI.findMatchingApp(apps, item.source.match);
          if (matchingApp && typeof matchingApp.volume === 'number') {
            val = matchingApp.volume;
          }
        } else if (item.source && item.source.kind === 'sound_volume') {
          val = 100;
        }

        if (isVertical) {
          card.innerHTML = 
            '<div class="shortcut-slider__header shortcut-slider__header--vertical">' +
              UI.renderTileIconHtml(item, 'shortcut-slider__icon') +
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
                UI.renderTileIconHtml(item, 'shortcut-slider__icon') +
                '<span>' + UI.escapeHtml(item.label || item.id) + '</span>' +
              '</div>' +
              '<output class="shortcut-slider__value" data-slider-value="' + item.id + '">' + val + '%</output>' +
            '</div>' +
            '<input type="range" class="slider-horizontal" data-slider-id="' + item.id + '" min="0" max="100" value="' + val + '">';
        }

        const input = card.querySelector('input');
        const output = card.querySelector('output');
        let lastPublish = 0;
        let pendingVal = null;
        let publishTimer = null;

        UI.updateSliderFill(input, val);

        if (!state.domCache.sliders[item.id]) state.domCache.sliders[item.id] = [];
        state.domCache.sliders[item.id].push({ input: input, output: output, card: card });
        if (isMaster) {
          state.domCache.masterSliders.push(item.id);
        }
        if (item.source && item.source.kind === 'app_volume') {
          state.domCache.appSliders.push({ id: item.id, match: item.source.match });
        }

        const flushPending = function() {
          if (pendingVal === null) return;
          const v = pendingVal;
          pendingVal = null;
          lastPublish = Date.now();
          const device = state.devices[deviceId];
          if (!device) return;
          if (isMaster) {
            MqttLayer.publishMasterVolume(device, v);
          } else {
            MqttLayer.publishCommand(device, 'set_slider', { id: item.id, value: Number(v) });
          }
        };

        const markDragging = function() {
          input._isDragging = true;
          input._lastUserInput = Date.now();
        };

        const unmarkDragging = function() {
          input._isDragging = false;
          input._lastUserInput = Date.now();
          if (publishTimer) {
            clearTimeout(publishTimer);
            publishTimer = null;
          }
          flushPending();
        };

        input.addEventListener('touchstart', markDragging, { passive: true });
        input.addEventListener('touchend', unmarkDragging, { passive: true });
        input.addEventListener('touchcancel', unmarkDragging, { passive: true });
        input.addEventListener('mousedown', markDragging);
        input.addEventListener('mouseup', unmarkDragging);

        input.addEventListener('input', function(e) {
          input._lastUserInput = Date.now();
          const v = e.target.value;
          output.textContent = v + '%';
          UI.updateSliderFill(input, v);

          pendingVal = v;
          const now = Date.now();
          if (now - lastPublish > 120) {
            flushPending();
          } else if (!publishTimer) {
            publishTimer = setTimeout(function() {
              publishTimer = null;
              flushPending();
            }, 130);
          }
        });

        input.addEventListener('change', function(e) {
          input._lastUserInput = Date.now();
          pendingVal = e.target.value;
          flushPending();
        });

        if (showPageBadge) card.insertAdjacentHTML('afterbegin', pageBadgeHtml);
        fragment.appendChild(card);
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
              UI.renderTileIconHtml(item, 'stat-card__icon') +
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
          } else if (item.source.kind === 'net') {
            var rx = typeof payload.rx_kbps === 'number' ? payload.rx_kbps : 0;
            var tx = typeof payload.tx_kbps === 'number' ? payload.tx_kbps : 0;
            detailText = '↓ ' + rx + ' KB/s · ↑ ' + tx + ' KB/s';
          }
          const badgeLabel = (item.source.kind || 'STAT').toUpperCase();
          card.innerHTML = 
            '<div class="stat-card__pro-header">' +
              '<div class="stat-card__pro-title">' +
                UI.renderTileIconHtml(item, 'stat-card__icon') +
                '<span class="stat-card__label">' + UI.escapeHtml(item.label || item.id) + '</span>' +
              '</div>' +
              '<span class="stat-card__badge">' + UI.escapeHtml(badgeLabel) + '</span>' +
            '</div>' +
            '<div class="stat-card__value">' + UI.escapeHtml(String(display)) + UI.escapeHtml(item.source.unit || '') + '</div>' +
            '<div class="stat-card__detail">' + UI.escapeHtml(detailText) + '</div>' +
            '<svg class="stat-sparkline" viewBox="0 0 200 30" preserveAspectRatio="none"><polyline fill="none" stroke="var(--accent-color)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" points="0,27 200,27"></polyline></svg>' +
            '<div class="stat-card__bar">' +
              '<div class="stat-card__bar-fill" style="width: ' + pct + '%"></div>' +
            '</div>';
        } else {
          card.innerHTML = 
            '<div class="stat-card__header">' +
              UI.renderTileIconHtml(item, 'stat-card__icon') +
              '<span class="stat-card__label">' + UI.escapeHtml(item.label || item.id) + '</span>' +
            '</div>' +
            '<div class="stat-card__value">' + UI.escapeHtml(String(display)) + UI.escapeHtml(item.source.unit || '') + '</div>' +
            '<div class="stat-card__bar">' +
              '<div class="stat-card__bar-fill" style="width: ' + pct + '%"></div>' +
            '</div>';
        }

        if (showPageBadge) card.insertAdjacentHTML('afterbegin', pageBadgeHtml);
        fragment.appendChild(card);
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
          UI.renderTileIconHtml(item, null, isThisPlaying) +
          '<span>' + UI.escapeHtml(item.label || 'Som') + '</span>' +
          '<span class="sound-wave-badge" aria-hidden="true"><span></span><span></span><span></span></span>';

        UI.addFastTapListener(btn, function() {
          UI.triggerTapAnimation(btn);
          btn.classList.add('shortcut-btn--pulse');
          setTimeout(function() {
            btn.classList.remove('shortcut-btn--pulse');
          }, 200);

          const device = state.devices[deviceId];
          if (!device) return;

          MqttLayer.publishCommand(device, 'play_sound', { sound_id: item.sound_id });
        });

        state.domCache.sounds.push(btn);
        if (showPageBadge) btn.insertAdjacentHTML('afterbegin', pageBadgeHtml);
        fragment.appendChild(btn);
      }
      else if (item.type === 'toggle') {
        let toggleVal = 'a';
        if (state.toggleStatesCache[deviceId] && state.toggleStatesCache[deviceId][item.id] !== undefined) {
          toggleVal = state.toggleStatesCache[deviceId][item.id];
        } else if (item.initial_state) {
          toggleVal = item.initial_state;
        }

        const isB = (String(toggleVal).toLowerCase() === 'b' || toggleVal === true || toggleVal === 1);
        const stateConfig = isB ? item.state_b : item.state_a;
        const icon = stateConfig ? (stateConfig.icon || item.icon || '') : (item.icon || '');
        const label = stateConfig ? (stateConfig.label || item.label || '') : (item.label || '');

        const btn = document.createElement('button');
        btn.className = 'shortcut-btn shortcut-btn--toggle' + (isB ? ' shortcut-btn--toggle-b' : ' shortcut-btn--toggle-a') + dimClasses;
        btn.type = 'button';
        btn.style.setProperty('--i', index);
        btn.style.gridColumn = gridColumnStyle;
        btn.style.gridRow = gridRowStyle;
        btn.dataset.toggleId = item.id;
        btn.dataset.toggleState = isB ? 'b' : 'a';

        btn.innerHTML = 
          UI.renderTileIconHtml({ icon: icon, static_icon: item.static_icon, animation_mode: item.animation_mode }) +
          '<span class="shortcut-btn__label">' + UI.escapeHtml(label || item.id) + '</span>' +
          '<span class="toggle-state-badge" aria-hidden="true">' + (isB ? 'B' : 'A') + '</span>';

        UI.addFastTapListener(btn, function() {
          UI.triggerTapAnimation(btn);
          const device = state.devices[deviceId];
          if (!device) return;

          btn.classList.add('shortcut-btn--pulse');
          setTimeout(function() {
            btn.classList.remove('shortcut-btn--pulse');
          }, 200);

          MqttLayer.publishCommand(device, item.id);
        });

        if (!state.domCache.toggles[item.id]) state.domCache.toggles[item.id] = [];
        state.domCache.toggles[item.id].push(btn);

        if (showPageBadge) btn.insertAdjacentHTML('afterbegin', pageBadgeHtml);
        fragment.appendChild(btn);
      }
      else if (item.type === 'pomodoro') {
        var pomoData = state.pomodoroCache[deviceId] || {
          phase: 'idle',
          remaining_ms: (item.focus_duration_minutes || 25) * 60 * 1000,
          cycle: 1,
          total_cycles: item.cycles_before_long_break || 4,
          is_running: false
        };

        var card = document.createElement('div');
        card.className = 'shortcut-btn shortcut-btn--pomodoro' + dimClasses;
        card.style.setProperty('--i', index);
        card.style.gridColumn = gridColumnStyle;
        card.style.gridRow = gridRowStyle;
        card.dataset.pomodoroId = item.id;

        var phaseLabels = {
          'idle': 'Ocioso',
          'focus': 'Foco',
          'short_break': 'Pausa Curta',
          'long_break': 'Pausa Longa'
        };
        var phaseClass = 'pomodoro-badge--' + (pomoData.phase || 'idle').replace('_', '-');
        var phaseText = phaseLabels[pomoData.phase] || 'Foco';
        var formattedTime = UI.formatPomodoroTime(pomoData.remaining_ms);
        var isRunning = !!pomoData.is_running;

        var totalDots = Math.max(1, Math.min(10, pomoData.total_cycles || 4));
        var currDot = Math.max(1, Math.min(totalDots, pomoData.cycle || 1));
        var dotsHtml = '<div class="pomodoro-cycle-dots" data-pomo-dots="true">';
        for (var d = 1; d <= totalDots; d++) {
          dotsHtml += '<span class="pomodoro-dot' + (d <= currDot ? ' pomodoro-dot--active' : '') + '"></span>';
        }
        dotsHtml += '</div>';

        card.innerHTML = 
          '<div class="pomodoro-header">' +
            '<div class="pomodoro-title-group">' +
              UI.renderTileIconHtml(item, 'pomodoro-icon') +
              '<span>' + UI.escapeHtml(item.label || 'Pomodoro') + '</span>' +
            '</div>' +
            '<span class="pomodoro-badge ' + phaseClass + '" data-pomo-badge="true">' + phaseText + '</span>' +
          '</div>' +
          '<div class="pomodoro-body">' +
            '<div class="pomodoro-timer" data-pomo-timer="true">' + formattedTime + '</div>' +
            dotsHtml +
          '</div>' +
          '<div class="pomodoro-footer">' +
            '<span class="pomodoro-cycle" data-pomo-cycle="true">Ciclo ' + (pomoData.cycle || 1) + ' de ' + (pomoData.total_cycles || 4) + '</span>' +
            '<div class="pomodoro-actions">' +
              '<button type="button" class="btn-pomodoro-action btn-pomodoro-play" title="Iniciar / Pausar">' + (isRunning ? '⏸️' : '▶️') + '</button>' +
              '<button type="button" class="btn-pomodoro-action btn-pomodoro-skip" title="Pular fase">⏭️</button>' +
              '<button type="button" class="btn-pomodoro-action btn-pomodoro-reset" title="Reiniciar">🔄</button>' +
            '</div>' +
          '</div>';

        var btnPlay = card.querySelector('.btn-pomodoro-play');
        var btnSkip = card.querySelector('.btn-pomodoro-skip');
        var btnReset = card.querySelector('.btn-pomodoro-reset');

        if (btnPlay) {
          UI.addFastTapListener(btnPlay, function(e) {
            if (e && e.stopPropagation) e.stopPropagation();
            var device = state.devices[deviceId];
            if (device) MqttLayer.publishCommand(device, 'pomodoro_toggle');
          });
        }

        if (btnSkip) {
          UI.addFastTapListener(btnSkip, function(e) {
            if (e && e.stopPropagation) e.stopPropagation();
            var device = state.devices[deviceId];
            if (device) MqttLayer.publishCommand(device, 'pomodoro_skip');
          });
        }

        if (btnReset) {
          UI.addFastTapListener(btnReset, function(e) {
            if (e && e.stopPropagation) e.stopPropagation();
            var device = state.devices[deviceId];
            if (device) MqttLayer.publishCommand(device, 'pomodoro_reset');
          });
        }

        UI.addFastTapListener(card, function() {
          var device = state.devices[deviceId];
          if (device) MqttLayer.publishCommand(device, 'pomodoro_toggle');
        });

        if (showPageBadge) card.insertAdjacentHTML('afterbegin', pageBadgeHtml);
        fragment.appendChild(card);
      }
      else if (item.type === 'todo') {
        var todoData = state.todosCache[deviceId] || { pending: 0, total: 0, items: [] };
        var btn = document.createElement('button');
        btn.className = 'shortcut-btn shortcut-btn--todo' + dimClasses;
        btn.type = 'button';
        btn.style.setProperty('--i', index);
        btn.style.gridColumn = gridColumnStyle;
        btn.style.gridRow = gridRowStyle;
        btn.dataset.todoId = item.id;

        var pendingCount = (typeof todoData.pending === 'number') ? todoData.pending : 0;
        var totalCount = (typeof todoData.total === 'number') ? todoData.total : 0;
        var badgeText = '';
        var badgeClass = 'todo-badge';

        if (pendingCount > 0) {
          badgeText = pendingCount + (pendingCount === 1 ? ' pendente' : ' pendentes');
        } else if (totalCount > 0) {
          badgeText = 'Tudo feito! ✔️';
        } else {
          badgeText = 'Nenhuma tarefa';
          badgeClass += ' todo-badge--empty';
        }

        btn.innerHTML = 
          UI.renderTileIconHtml(item) +
          '<span>' + UI.escapeHtml(item.label || 'Tarefas') + '</span>' +
          '<span class="' + badgeClass + '" data-todo-badge="true">' + badgeText + '</span>';

        UI.addFastTapListener(btn, function() {
          UI.triggerTapAnimation(btn);
          UI.openTodoDrawer();
        });

        if (showPageBadge) btn.insertAdjacentHTML('afterbegin', pageBadgeHtml);
        fragment.appendChild(btn);
      }
      else {
        const btn = document.createElement('button');
        btn.className = 'shortcut-btn' + dimClasses;
        btn.type = 'button';
        btn.style.setProperty('--i', index);
        btn.style.gridColumn = gridColumnStyle;
        btn.style.gridRow = gridRowStyle;
        btn.innerHTML = 
          UI.renderTileIconHtml(item) +
          '<span>' + UI.escapeHtml(item.label || item.id || 'Sem Nome') + '</span>';

        if (showPageBadge) btn.insertAdjacentHTML('afterbegin', pageBadgeHtml);

        UI.addFastTapListener(btn, function() {
          UI.triggerTapAnimation(btn);
          if (item.type === 'folder' && item.target) {
            if (UI.isSearchActive()) {
              UI.resetSearchFilters(deviceId, false);
            }
            UI.switchToPage(deviceId, item.target);
          } else if (item.type === 'back') {
            if (UI.isSearchActive()) {
              UI.resetSearchFilters(deviceId, false);
            }
            UI.switchToPage(deviceId, 'home');
          } else if (item.id) {
            btn.classList.add('shortcut-btn--pulse');
            setTimeout(function() {
              btn.classList.remove('shortcut-btn--pulse');
            }, 200);
            const device = state.devices[deviceId];
            if (device) MqttLayer.publishCommand(device, item.id);
          }
        });
        fragment.appendChild(btn);
      }
    });

    container.appendChild(fragment);
  },

  formatTime(seconds) {
    if (typeof seconds !== 'number' || isNaN(seconds) || seconds < 0) return '00:00';
    var totalSec = Math.floor(seconds);
    var hrs = Math.floor(totalSec / 3600);
    var mins = Math.floor((totalSec % 3600) / 60);
    var secs = totalSec % 60;
    var strMins = (mins < 10 ? '0' : '') + mins;
    var strSecs = (secs < 10 ? '0' : '') + secs;
    if (hrs > 0) {
      return hrs + ':' + strMins + ':' + strSecs;
    }
    return strMins + ':' + strSecs;
  },

  updateMediaProgressUI() {
    var pos = Math.max(0, state.mediaPosition || 0);
    var dur = Math.max(0, state.mediaDuration || 0);

    // 1. Mini Badge & Barra de progresso no Now Playing
    if (dur > 0 && dom.npTimeBadge && dom.npProgressFill) {
      dom.npTimeBadge.textContent = this.formatTime(pos) + ' / ' + this.formatTime(dur);
      dom.npTimeBadge.style.display = 'inline-block';
      var pct = Math.max(0, Math.min(100, (pos / dur) * 100));
      dom.npProgressFill.style.width = pct + '%';
    } else {
      if (dom.npTimeBadge) dom.npTimeBadge.style.display = 'none';
      if (dom.npProgressFill) dom.npProgressFill.style.width = '0%';
    }

    // 2. Timeline do Media Drawer
    if (dom.mediaTimeCurrent) dom.mediaTimeCurrent.textContent = this.formatTime(pos);
    if (dom.mediaTimeTotal) dom.mediaTimeTotal.textContent = this.formatTime(dur);

    if (dom.mediaSeekSlider && !state.mediaSeeking) {
      dom.mediaSeekSlider.max = String(dur > 0 ? dur : 100);
      dom.mediaSeekSlider.value = String(Math.floor(pos));
      var pctSeek = dur > 0 ? Math.max(0, Math.min(100, (pos / dur) * 100)) : 0;
      dom.mediaSeekSlider.style.background = 'linear-gradient(to right, var(--accent-color) 0%, var(--accent-color) ' + pctSeek + '%, var(--ctp-crust) ' + pctSeek + '%, var(--ctp-crust) 100%)';
    }
  },

  startMediaTimeline() {
    this.stopMediaTimeline();
    var self = this;
    state.mediaTimelineTimer = setInterval(function() {
      if (state.mediaStatus !== 'Playing') {
        self.stopMediaTimeline();
        return;
      }
      var dur = state.mediaDuration || 0;
      var rate = state.mediaPlaybackRate || 1.0;
      var cur = state.mediaPosition || 0;
      var next = cur + rate;
      if (dur > 0 && next >= dur) {
        next = dur;
      }
      state.mediaPosition = next;
      self.updateMediaProgressUI();
    }, 1000);
  },

  stopMediaTimeline() {
    if (state.mediaTimelineTimer) {
      clearInterval(state.mediaTimelineTimer);
      state.mediaTimelineTimer = null;
    }
  },

  syncMediaSpeedChips(rate) {
    var chips = document.querySelectorAll('.btn-speed-chip');
    if (!chips || !chips.length) return;
    var targetSpeed = Number(rate) || 1.0;
    for (var i = 0; i < chips.length; i++) {
      var chip = chips[i];
      var s = Number(chip.getAttribute('data-speed'));
      var match = Math.abs(s - targetSpeed) < 0.05;
      chip.classList.toggle('btn-speed-chip--active', match);
    }
  },

  renderNowPlaying(data) {
    if (!dom.nowPlaying) return;
    if (!data || data.status === 'Stopped') {
      state.mediaStatus = 'Stopped';
      state.mediaPosition = 0;
      state.mediaDuration = 0;
      this.stopMediaTimeline();

      dom.npTitle.textContent = 'Nenhuma mídia tocando';
      dom.npArtist.textContent = '-';
      dom.npIcon.textContent = '\u{1F3B5}';
      dom.nowPlaying.classList.add('now-playing--empty');
      dom.nowPlaying.classList.remove('now-playing--playing');
      if (dom.npTimeBadge) dom.npTimeBadge.style.display = 'none';
      if (dom.npProgressFill) dom.npProgressFill.style.width = '0%';
      if (dom.npQuickPlay) dom.npQuickPlay.textContent = '\u25B6\uFE0F';
      this.parseEmojis(dom.npIcon);
      this.syncMediaDrawer(data);
      this.updateAmbientInfo();
      return;
    }

    const isPlaying = (data.status === 'Playing');
    state.mediaStatus = data.status;
    state.mediaPosition = (typeof data.position === 'number') ? data.position : 0;
    state.mediaDuration = (typeof data.duration === 'number') ? data.duration : 0;
    state.mediaPlaybackRate = (typeof data.playback_rate === 'number' && data.playback_rate > 0) ? data.playback_rate : 1.0;

    dom.npTitle.textContent = data.title || 'Mídia em reprodução';
    dom.npArtist.textContent = data.artist || 'Desconhecido';
    dom.npIcon.textContent = '\u{1F3B5}';
    dom.nowPlaying.classList.remove('now-playing--empty');
    dom.nowPlaying.classList.toggle('now-playing--playing', isPlaying);

    if (dom.npQuickPlay) {
      dom.npQuickPlay.textContent = isPlaying ? '\u23F8\uFE0F' : '\u25B6\uFE0F';
      this.parseEmojis(dom.npQuickPlay);
    }

    this.updateMediaProgressUI();

    if (isPlaying) {
      this.startMediaTimeline();
    } else {
      this.stopMediaTimeline();
    }

    this.parseEmojis(dom.npIcon);
    this.syncMediaDrawer(data);
    this.updateAmbientInfo();
  },

  syncMediaDrawer(data) {
    if (!dom.mediaDrawer) return;
    var isPlaying = Boolean(data && data.status === 'Playing');
    var isPaused = Boolean(data && data.status === 'Paused');

    dom.mediaDrawer.classList.toggle('media-drawer--playing', isPlaying);

    if (dom.mediaStatusPill) {
      dom.mediaStatusPill.className = 'media-status-pill ' + 
        (isPlaying ? 'media-status-pill--playing' : (isPaused ? 'media-status-pill--paused' : 'media-status-pill--stopped'));
      dom.mediaStatusPill.textContent = isPlaying ? 'Reproduzindo' : (isPaused ? 'Pausado' : 'Parado');
    }

    if (dom.mediaModalTitle) {
      dom.mediaModalTitle.textContent = (data && data.title) ? data.title : 'Nenhuma mídia reproduzindo';
    }
    if (dom.mediaModalArtist) {
      dom.mediaModalArtist.textContent = (data && data.artist) ? data.artist : '-';
    }

    if (dom.btnMediaPlayPause) {
      dom.btnMediaPlayPause.textContent = isPlaying ? '\u23F8\uFE0F' : '\u25B6\uFE0F';
      this.parseEmojis(dom.btnMediaPlayPause);
    }

    this.syncMediaSpeedChips(state.mediaPlaybackRate);
    this.syncMediaDrawerVolume();
  },

  syncMediaDrawerVolume() {
    if (!dom.mediaVolumeSlider) return;
    var devId = state.currentDeviceId;
    var curVol = 50;
    if (devId && typeof state.volumeCache[devId] === 'number') {
      curVol = state.volumeCache[devId];
    }
    if (!dom.mediaVolumeSlider._isDragging && document.activeElement !== dom.mediaVolumeSlider) {
      dom.mediaVolumeSlider.value = String(curVol);
      UI.updateSliderFill(dom.mediaVolumeSlider, curVol);
      if (dom.mediaVolumeValue) dom.mediaVolumeValue.textContent = curVol + '%';
    }
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

  updateEventsBadge() {
    if (!dom.eventsUnreadBadge) return;
    var count = (state.currentDeviceId && state.unreadEvents[state.currentDeviceId])
      ? state.unreadEvents[state.currentDeviceId]
      : 0;
    if (count > 0) {
      dom.eventsUnreadBadge.textContent = count > 99 ? '99+' : String(count);
      dom.eventsUnreadBadge.style.display = 'inline-flex';
    } else {
      dom.eventsUnreadBadge.style.display = 'none';
    }
  },

  renderEventsList(deviceId) {
    if (!dom.eventsList) return;
    var events = (deviceId && state.eventsCache[deviceId]) ? state.eventsCache[deviceId] : [];

    if (dom.eventsCountLabel) {
      dom.eventsCountLabel.textContent = '(' + events.length + ')';
    }

    if (events.length === 0) {
      dom.eventsList.innerHTML = '<p class="events-empty-msg">Nenhum evento registrado para este dispositivo.</p>';
      return;
    }

    var iconMap = {
      'info': 'ℹ️',
      'success': '✅',
      'warning': '⚠️',
      'error': '❌'
    };

    var labelMap = {
      'info': 'Info',
      'success': 'Sucesso',
      'warning': 'Aviso',
      'error': 'Erro'
    };

    var html = '';
    for (var i = 0; i < events.length; i++) {
      var evt = events[i];
      var kind = evt.kind || 'info';
      var icon = iconMap[kind] || 'ℹ️';
      var label = labelMap[kind] || kind.toUpperCase();

      html += '<div class="event-item event-item--' + kind + '">' +
        '<div class="event-item__header">' +
          '<span class="event-item__type"><span class="event-item__icon">' + icon + '</span>' + label + '</span>' +
          '<span class="event-item__time">' + UI.escapeHtml(evt.timeStr) + '</span>' +
        '</div>' +
        '<div class="event-item__message">' + UI.escapeHtml(evt.message) + '</div>' +
      '</div>';
    }

    dom.eventsList.innerHTML = html;
    UI.parseEmojis(dom.eventsList);
  },

  clearEvents(deviceId) {
    if (!deviceId) return;
    state.eventsCache[deviceId] = [];
    state.unreadEvents[deviceId] = 0;
    UI.updateEventsBadge();
    UI.renderEventsList(deviceId);
  },

  formatPomodoroTime(ms) {
    if (typeof ms !== 'number' || isNaN(ms) || ms < 0) return '00:00';
    var totalSec = Math.floor(ms / 1000);
    var mins = Math.floor(totalSec / 60);
    var secs = totalSec % 60;
    var strMins = (mins < 10 ? '0' : '') + mins;
    var strSecs = (secs < 10 ? '0' : '') + secs;
    return strMins + ':' + strSecs;
  },

  handlePomodoroStateUpdate(deviceId, data) {
    if (state.pomodoroTimer) {
      clearInterval(state.pomodoroTimer);
      state.pomodoroTimer = null;
    }
    if (data && data.is_running && data.remaining_ms > 0) {
      state.pomodoroTimer = setInterval(function() {
        var currentData = state.pomodoroCache[state.currentDeviceId];
        if (!currentData || !currentData.is_running) {
          if (state.pomodoroTimer) {
            clearInterval(state.pomodoroTimer);
            state.pomodoroTimer = null;
          }
          return;
        }
        if (currentData.remaining_ms > 1000) {
          currentData.remaining_ms -= 1000;
        } else {
          currentData.remaining_ms = 0;
          currentData.is_running = false;
          if (state.pomodoroTimer) {
            clearInterval(state.pomodoroTimer);
            state.pomodoroTimer = null;
          }
        }
        UI.updatePomodoroInPlace(state.currentDeviceId);
      }, 1000);
    }
  },

  updatePomodoroInPlace(deviceId) {
    var data = state.pomodoroCache[deviceId];
    if (!data) return;

    var phaseLabels = {
      'idle': 'Ocioso',
      'focus': 'Foco',
      'short_break': 'Pausa Curta',
      'long_break': 'Pausa Longa'
    };
    var phaseClass = 'pomodoro-badge--' + (data.phase || 'idle').replace('_', '-');
    var phaseText = phaseLabels[data.phase] || 'Foco';
    var formattedTime = this.formatPomodoroTime(data.remaining_ms);
    var isRunning = !!data.is_running;

    var pomoCards = document.querySelectorAll('.shortcut-btn--pomodoro');
    for (var i = 0; i < pomoCards.length; i++) {
      var card = pomoCards[i];
      var badge = card.querySelector('[data-pomo-badge]');
      var timerEl = card.querySelector('[data-pomo-timer]');
      var cycleEl = card.querySelector('[data-pomo-cycle]');
      var playBtn = card.querySelector('.btn-pomodoro-play');

      if (badge) {
        badge.className = 'pomodoro-badge ' + phaseClass;
        badge.textContent = phaseText;
      }
      if (timerEl) {
        timerEl.textContent = formattedTime;
      }
      if (cycleEl) {
        cycleEl.textContent = 'Ciclo ' + (data.cycle || 1) + ' de ' + (data.total_cycles || 4);
      }
      var dotsEl = card.querySelector('[data-pomo-dots]');
      if (dotsEl) {
        var dots = dotsEl.querySelectorAll('.pomodoro-dot');
        var curr = data.cycle || 1;
        for (var d = 0; d < dots.length; d++) {
          dots[d].className = (d < curr) ? 'pomodoro-dot pomodoro-dot--active' : 'pomodoro-dot';
        }
      }
      if (playBtn) {
        playBtn.textContent = isRunning ? '⏸️' : '▶️';
      }
    }
    this.updateAmbientInfo();
  },

  startClock() {
    var updateClock = function() {
      var now = new Date();
      var hh = (now.getHours() < 10 ? '0' : '') + now.getHours();
      var mm = (now.getMinutes() < 10 ? '0' : '') + now.getMinutes();
      var timeStr = hh + ':' + mm;
      if (dom.headerClock && dom.headerClock.textContent !== timeStr) {
        dom.headerClock.textContent = timeStr;
      }
      if (dom.ambientClock && dom.ambientClock.textContent !== timeStr) {
        dom.ambientClock.textContent = timeStr;
      }
      if (dom.ambientDate) {
        var days = ['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado'];
        var months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
        var dateStr = days[now.getDay()] + ', ' + now.getDate() + ' de ' + months[now.getMonth()];
        if (dom.ambientDate.textContent !== dateStr) {
          dom.ambientDate.textContent = dateStr;
        }
      }
    };
    updateClock();
    if (state.clockTimer) clearInterval(state.clockTimer);
    state.clockTimer = setInterval(updateClock, 5000);
  },

  _pendingStatsQueue: null,
  _pendingStatsRaf: null,

  scheduleStatsFlush(deviceId, kind) {
    if (!this._pendingStatsQueue) this._pendingStatsQueue = {};
    this._pendingStatsQueue[kind] = deviceId;
    if (this._pendingStatsRaf) return;
    var self = this;
    var raf = window.requestAnimationFrame || function(cb) { return setTimeout(cb, 16); };
    this._pendingStatsRaf = raf(function() {
      self._pendingStatsRaf = null;
      if (state.ambientActive || !self._pendingStatsQueue) {
        self._pendingStatsQueue = null;
        return;
      }
      var q = self._pendingStatsQueue;
      self._pendingStatsQueue = null;
      var kinds = Object.keys(q);
      for (var i = 0; i < kinds.length; i++) {
        var k = kinds[i];
        var dId = q[k];
        if (state.currentDeviceId === dId) {
          UI.updateStatsInPlace(dId, k);
        }
      }
    });
  },

  updateAmbientInfo() {
    var devId = state.currentDeviceId;
    if (dom.ambientPomo) {
      var pomo = devId ? state.pomodoroCache[devId] : null;
      if (pomo && pomo.phase && pomo.phase !== 'idle' && (pomo.is_running || pomo.remaining_ms > 0)) {
        var labels = { 'focus': 'Foco', 'short_break': 'Pausa Curta', 'long_break': 'Pausa Longa' };
        dom.ambientPomo.textContent = (labels[pomo.phase] || 'Foco') + ' · ' + UI.formatPomodoroTime(pomo.remaining_ms);
        dom.ambientPomo.style.display = 'inline-block';
      } else {
        dom.ambientPomo.style.display = 'none';
      }
    }
    if (dom.ambientMedia) {
      var media = devId ? state.mediaCache[devId] : null;
      if (media && media.status === 'Playing' && media.title) {
        dom.ambientMedia.textContent = media.title + (media.artist ? ' — ' + media.artist : '');
        dom.ambientMedia.style.display = 'block';
      } else {
        dom.ambientMedia.style.display = 'none';
      }
    }
    if (dom.ambientBattery) {
      var tb = state.tabletBattery;
      if (tb && typeof tb.percent === 'number') {
        dom.ambientBattery.textContent = 'Tablet ' + tb.percent + '%' + (tb.charging ? ' ⚡' : '');
        dom.ambientBattery.style.display = 'block';
      } else {
        dom.ambientBattery.style.display = 'none';
      }
    }
    if (state.ambientActive && typeof AmbientStudio !== 'undefined') {
      AmbientStudio.updateByType('batteries');
    }
  },

  initTabletBattery() {
    if (typeof navigator === 'undefined' || typeof navigator.getBattery !== 'function') return;
    navigator.getBattery().then(function(bat) {
      var sync = function() {
        state.tabletBattery = {
          id: 'tablet_self',
          name: 'Este Tablet',
          kind: 'tablet',
          percent: Math.round((bat.level || 0) * 100),
          charging: !!bat.charging
        };
        UI.updateBatteryPill();
        if (state.batteryDrawerOpen) UI.renderBatteryDrawer();
        UI.updateAmbientInfo();
      };
      sync();
      bat.addEventListener('levelchange', sync);
      bat.addEventListener('chargingchange', sync);
    }).catch(function() {});
  },

  getAllBatteries() {
    var list = [];
    if (state.tabletBattery) list.push(state.tabletBattery);
    var pcBats = state.currentDeviceId ? (state.batteriesCache[state.currentDeviceId] || []) : [];
    for (var i = 0; i < pcBats.length; i++) list.push(pcBats[i]);
    return list;
  },

  updateBatteryPill() {
    if (!dom.btnToggleBatteries || !dom.headerBatteryLabel) return;
    var all = UI.getAllBatteries();
    var primary = state.tabletBattery || (all.length > 0 ? all[0] : null);
    var anyLow = false;
    for (var i = 0; i < all.length; i++) {
      if (!all[i].charging && all[i].percent <= 20) anyLow = true;
    }
    if (primary) {
      dom.headerBatteryLabel.textContent = primary.percent + '%' + (primary.charging ? '⚡' : '');
      dom.btnToggleBatteries.classList.toggle('btn-battery-pill--charging', !!primary.charging);
    } else {
      dom.headerBatteryLabel.textContent = '--%';
      dom.btnToggleBatteries.classList.remove('btn-battery-pill--charging');
    }
    dom.btnToggleBatteries.classList.toggle('btn-battery-pill--low', anyLow);
  },

  renderBatteryDrawer() {
    if (!dom.batteryList) return;
    var all = UI.getAllBatteries();
    if (all.length === 0) {
      dom.batteryList.innerHTML = '<p class="mixer-empty-msg">Nenhuma bateria detectada nos dispositivos conectados.</p>';
      return;
    }
    var kindIcon = {
      'tablet': '📱',
      'laptop': '💻',
      'headphones': '🎧',
      'mouse': '🖱️',
      'keyboard': '⌨️',
      'gamepad': '🎮',
      'other': '🔋'
    };
    var html = '';
    for (var i = 0; i < all.length; i++) {
      var b = all[i];
      var pct = Math.max(0, Math.min(100, Number(b.percent) || 0));
      var fillCls = 'battery-card__bar-fill';
      if (pct <= 20) fillCls += ' battery-card__bar-fill--low';
      else if (pct <= 45) fillCls += ' battery-card__bar-fill--mid';
      var icon = kindIcon[b.kind] || '🔋';
      html +=
        '<div class="battery-card">' +
          '<div class="battery-card__row">' +
            '<span class="battery-card__title"><span>' + icon + '</span><span>' + UI.escapeHtml(b.name) + '</span></span>' +
            '<span class="battery-card__pct">' + pct + '%' + (b.charging ? ' ⚡' : '') + '</span>' +
          '</div>' +
          '<div class="battery-card__bar"><div class="' + fillCls + '" style="width:' + pct + '%"></div></div>' +
        '</div>';
    }
    dom.batteryList.innerHTML = html;
  },

  updateMicButton() {
    if (!dom.btnToggleMic) return;
    var mic = state.currentDeviceId ? state.micCache[state.currentDeviceId] : null;
    var muted = !!(mic && mic.muted);
    dom.btnToggleMic.classList.toggle('btn-icon-hdr--danger', muted);
    dom.btnToggleMic.title = muted ? 'Microfone MUTADO (toque para ativar)' : 'Microfone ativo (toque para silenciar)';
  },

  renderAudioOutputs() {
    if (!dom.mixerOutputsSection || !dom.mixerOutputsList) return;
    var list = state.currentDeviceId ? (state.audioOutputsCache[state.currentDeviceId] || []) : [];
    if (!list || list.length <= 1) {
      dom.mixerOutputsSection.style.display = 'none';
      return;
    }
    dom.mixerOutputsSection.style.display = 'flex';
    dom.mixerOutputsList.innerHTML = '';
    for (var i = 0; i < list.length; i++) {
      (function(dev) {
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'output-chip' + (dev.is_default ? ' output-chip--active' : '');
        btn.textContent = dev.name || dev.id;
        UI.addFastTapListener(btn, function() {
          var host = state.devices[state.currentDeviceId];
          if (host) {
            MqttLayer.publishCommand(host, 'set_audio_output', { device: dev.name || dev.id });
          }
        });
        dom.mixerOutputsList.appendChild(btn);
      })(list[i]);
    }
  },

  updateAutoSwitchButton() {
    if (!dom.btnToggleAutoSwitch) return;
    var rules = state.currentDeviceId ? (state.pageRulesCache[state.currentDeviceId] || {}) : {};
    var hasRules = Object.keys(rules).length > 0;
    dom.btnToggleAutoSwitch.style.display = hasRules ? 'inline-flex' : 'none';
    dom.btnToggleAutoSwitch.classList.toggle('btn-autoswitch--locked', !state.autoSwitchEnabled);
    dom.btnToggleAutoSwitch.textContent = state.autoSwitchEnabled ? 'Auto' : 'Fixo';
  },

  applySmartProfileSwitch(deviceId) {
    if (!state.autoSwitchEnabled || !deviceId || deviceId !== state.currentDeviceId) return;
    var active = state.activeAppCache[deviceId];
    var rules = state.pageRulesCache[deviceId];
    var pages = state.shortcutsCache[deviceId];
    if (!active || !active.process || !rules || !pages) return;

    var proc = String(active.process).toLowerCase().replace(/\.exe$/, '');
    var matchedPage = null;
    var pageIds = Object.keys(rules);
    for (var i = 0; i < pageIds.length; i++) {
      var pId = pageIds[i];
      var triggers = rules[pId] || [];
      for (var j = 0; j < triggers.length; j++) {
        var trg = String(triggers[j]).toLowerCase().replace(/\.exe$/, '');
        if (trg && (proc === trg || proc.indexOf(trg) !== -1)) {
          matchedPage = pId;
          break;
        }
      }
      if (matchedPage) break;
    }

    if (matchedPage && pages[matchedPage]) {
      var curPage = state.currentPageCache[deviceId] || 'home';
      if (curPage !== matchedPage && !UI.isSearchActive()) {
        UI.switchToPage(deviceId, matchedPage);
      }
    }
  },

  renderClipboardPreview() {
    if (!dom.clipPcPreview) return;
    var text = state.currentDeviceId ? (state.clipboardCache[state.currentDeviceId] || '') : '';
    if (!text) {
      dom.clipPcPreview.textContent = 'Toque em "Puxar do PC" para trazer o texto copiado.';
      if (dom.btnClipOpenLink) dom.btnClipOpenLink.style.display = 'none';
      return;
    }
    dom.clipPcPreview.textContent = text;
    var isUrl = /^https?:\/\/\S+/i.test(text.trim());
    if (dom.btnClipOpenLink) {
      dom.btnClipOpenLink.style.display = isUrl ? 'inline-flex' : 'none';
    }
  },

  updateTodoCardInPlace(deviceId) {
    var data = state.todosCache[deviceId] || { pending: 0, total: 0, items: [] };
    var pendingCount = (typeof data.pending === 'number') ? data.pending : 0;
    var totalCount = (typeof data.total === 'number') ? data.total : 0;
    var badgeText = '';
    var badgeClass = 'todo-badge';

    if (pendingCount > 0) {
      badgeText = pendingCount + (pendingCount === 1 ? ' pendente' : ' pendentes');
    } else if (totalCount > 0) {
      badgeText = 'Tudo feito! ✔️';
    } else {
      badgeText = 'Nenhuma tarefa';
      badgeClass += ' todo-badge--empty';
    }

    var todoCards = document.querySelectorAll('.shortcut-btn--todo');
    for (var i = 0; i < todoCards.length; i++) {
      var badge = todoCards[i].querySelector('[data-todo-badge]');
      if (badge) {
        badge.className = badgeClass;
        badge.textContent = badgeText;
      }
    }
  },

  openTodoDrawer() {
    Navigation.openTodoDrawer();
  },

  closeTodoDrawer() {
    Navigation.closeTodoDrawer();
  },

  renderTodoList(deviceId) {
    if (!dom.todoItemsList) return;
    var data = state.todosCache[deviceId] || { pending: 0, total: 0, items: [] };
    var items = data.items || [];
    var pending = (typeof data.pending === 'number') ? data.pending : 0;

    if (dom.todoCountLabel) {
      dom.todoCountLabel.textContent = '(' + pending + (pending === 1 ? ' pendente)' : ' pendentes)');
    }

    if (items.length === 0) {
      dom.todoItemsList.innerHTML = '<p class="todo-empty-msg">Nenhuma tarefa cadastrada.</p>';
      return;
    }

    var html = '';
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      var isDone = !!item.done;
      var doneClass = isDone ? ' todo-item--done' : '';
      var checkChar = isDone ? '✔' : '';

      html += 
        '<div class="todo-item' + doneClass + '" data-item-id="' + UI.escapeHtml(item.id) + '">' +
          '<div class="todo-item__left">' +
            '<div class="todo-item__checkbox" data-action="toggle">' + checkChar + '</div>' +
            '<span class="todo-item__text" data-action="toggle">' + UI.escapeHtml(item.text) + '</span>' +
          '</div>' +
          '<button type="button" class="todo-item__btn-remove" data-action="remove" title="Excluir tarefa">&times;</button>' +
        '</div>';
    }
    dom.todoItemsList.innerHTML = html;

    var itemEls = dom.todoItemsList.querySelectorAll('.todo-item');
    for (var j = 0; j < itemEls.length; j++) {
      (function(el) {
        var itemId = el.getAttribute('data-item-id');
        var toggleArea = el.querySelector('.todo-item__left');
        var btnRemove = el.querySelector('.todo-item__btn-remove');

        if (toggleArea) {
          UI.addFastTapListener(toggleArea, function() {
            var device = state.devices[deviceId];
            if (device) {
              MqttLayer.publishCommand(device, 'todo_toggle', { item_id: itemId });
            }
          });
        }
        if (btnRemove) {
          UI.addFastTapListener(btnRemove, function() {
            var device = state.devices[deviceId];
            if (device) {
              MqttLayer.publishCommand(device, 'todo_remove', { item_id: itemId });
            }
          });
        }
      })(itemEls[j]);
    }
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
    if (state.eventsDrawerOpen) {
      UI.renderEventsList(deviceId);
    }
    UI.updateEventsBadge();
    UI.renderShortcuts(deviceId);
    UI.renderNowPlaying(state.mediaCache[deviceId] || null);
    UI.renderDeviceTabs();
    UI.updateBatteryPill();
    UI.updateMicButton();
    UI.updateAutoSwitchButton();
    UI.renderAudioOutputs();
    UI.renderClipboardPreview();
    Navigation.closeMixerDrawer();
  },
  openMixerDrawer() {
    Navigation.closeEventsDrawer();
    Navigation.closeMediaDrawer();
    Navigation.closeTodoDrawer();
    Navigation.closeBatteryDrawer();
    Navigation.closeClipboardDrawer();
    dom.mixerDrawer.classList.add('mixer-drawer--open');
    if (state.currentDeviceId) {
      UI.renderAudioOutputs();
      UI.renderAppMixer(state.appsCache[state.currentDeviceId] || []);
    }
  },
  closeMixerDrawer() { dom.mixerDrawer.classList.remove('mixer-drawer--open'); },

  openBatteryDrawer() {
    state.batteryDrawerOpen = true;
    Navigation.closeMixerDrawer();
    Navigation.closeEventsDrawer();
    Navigation.closeMediaDrawer();
    Navigation.closeTodoDrawer();
    Navigation.closeClipboardDrawer();
    if (dom.batteryDrawer) dom.batteryDrawer.classList.add('side-drawer--open');
    UI.renderBatteryDrawer();
  },
  closeBatteryDrawer() {
    state.batteryDrawerOpen = false;
    if (dom.batteryDrawer) dom.batteryDrawer.classList.remove('side-drawer--open');
  },

  openClipboardDrawer() {
    state.clipboardDrawerOpen = true;
    Navigation.closeMixerDrawer();
    Navigation.closeEventsDrawer();
    Navigation.closeMediaDrawer();
    Navigation.closeTodoDrawer();
    Navigation.closeBatteryDrawer();
    if (dom.clipboardDrawer) dom.clipboardDrawer.classList.add('side-drawer--open');
    UI.renderClipboardPreview();
  },
  closeClipboardDrawer() {
    state.clipboardDrawerOpen = false;
    if (dom.clipboardDrawer) dom.clipboardDrawer.classList.remove('side-drawer--open');
  },

  openEventsDrawer() {
    state.eventsDrawerOpen = true;
    Navigation.closeMixerDrawer();
    Navigation.closeMediaDrawer();
    Navigation.closeTodoDrawer();
    if (dom.eventsDrawer) dom.eventsDrawer.classList.add('events-drawer--open');
    if (dom.btnToggleEvents) {
      dom.btnToggleEvents.classList.add('btn-pill--active');
      dom.btnToggleEvents.setAttribute('aria-expanded', 'true');
    }
    if (state.currentDeviceId) {
      state.unreadEvents[state.currentDeviceId] = 0;
      UI.updateEventsBadge();
      UI.renderEventsList(state.currentDeviceId);
    }
  },

  closeEventsDrawer() {
    state.eventsDrawerOpen = false;
    if (dom.eventsDrawer) dom.eventsDrawer.classList.remove('events-drawer--open');
    if (dom.btnToggleEvents) {
      dom.btnToggleEvents.classList.remove('btn-pill--active');
      dom.btnToggleEvents.setAttribute('aria-expanded', 'false');
    }
  },

  openMediaDrawer() {
    state.mediaDrawerOpen = true;
    Navigation.closeMixerDrawer();
    Navigation.closeEventsDrawer();
    Navigation.closeTodoDrawer();
    if (dom.mediaDrawer) dom.mediaDrawer.classList.add('media-drawer--open');
    if (state.currentDeviceId) {
      UI.syncMediaDrawer(state.mediaCache[state.currentDeviceId] || null);
    }
  },

  closeMediaDrawer() {
    state.mediaDrawerOpen = false;
    if (dom.mediaDrawer) dom.mediaDrawer.classList.remove('media-drawer--open');
  },

  openTodoDrawer() {
    state.todoDrawerOpen = true;
    Navigation.closeMixerDrawer();
    Navigation.closeEventsDrawer();
    Navigation.closeMediaDrawer();
    if (dom.todoDrawer) dom.todoDrawer.classList.add('todo-drawer--open');
    if (state.currentDeviceId) {
      UI.renderTodoList(state.currentDeviceId);
    }
    // Sempre iniciar pelo teclado do PC (teclado do tablet opcional)
    var device = state.devices[state.currentDeviceId];
    if (device && device.online) {
      MqttLayer.publishCommand(device, 'remote_todo_prompt');
      UI.showToast({ message: 'Digite a tarefa no teclado do PC...', level: 'info' });
    }
  },

  closeTodoDrawer() {
    state.todoDrawerOpen = false;
    if (dom.todoDrawer) dom.todoDrawer.classList.remove('todo-drawer--open');
    if (dom.todoInputText) {
      dom.todoInputText.blur();
    }
  },

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
      // Sempre iniciar pelo teclado do PC (teclado do tablet opcional)
      var device = state.devices[state.currentDeviceId];
      if (device && device.online) {
        MqttLayer.publishCommand(device, 'remote_search_prompt');
        UI.showToast({ message: 'Digite a busca no teclado do PC...', level: 'info' });
      }
    } else {
      if (state.searchQuery || state.searchFilter !== 'all' || state.searchScope !== 'page') {
        UI.resetSearchFilters(state.currentDeviceId, true);
      }
    }
  },

  toggleSidebar() {
    if (!dom.appShell) return;
    if (!dom.appShell.classList.contains('app-shell--single-device')) return;
    state.sidebarOpen = !state.sidebarOpen;
    dom.appShell.classList.toggle('app-shell--sidebar-open', state.sidebarOpen);
  },

  closeSidebar() {
    if (!dom.appShell) return;
    state.sidebarOpen = false;
    dom.appShell.classList.remove('app-shell--sidebar-open');
  },

  openAmbient() {
    if (state.ambientActive) return;
    state.ambientActive = true;
    UI.updateAmbientInfo();
    if (dom.appShell) {
      dom.appShell.classList.add('app-shell--suspended');
    }
    if (state.mediaTimelineTimer) {
      clearInterval(state.mediaTimelineTimer);
      state.mediaTimelineTimer = null;
    }
    if (dom.ambientOverlay) {
      dom.ambientOverlay.classList.add('ambient-overlay--active');
    }
    AmbientStudio.start(state.currentDeviceId);
    if (state.ambientInactivityTimer) {
      clearTimeout(state.ambientInactivityTimer);
      state.ambientInactivityTimer = null;
    }
  },

  closeAmbient() {
    if (!state.ambientActive) return;
    state.ambientActive = false;
    AmbientStudio.stop();
    if (dom.ambientOverlay) {
      dom.ambientOverlay.classList.remove('ambient-overlay--active');
    }
    if (dom.appShell) {
      dom.appShell.classList.remove('app-shell--suspended');
    }
    // Re-sincroniza o dashboard principal com os caches recebidos durante o descanso
    var devId = state.currentDeviceId;
    if (devId) {
      var raf = window.requestAnimationFrame || function(cb) { return setTimeout(cb, 16); };
      raf(function() {
        UI.updateBatteryPill();
        UI.updateMicButton();
        UI.updatePomodoroInPlace(devId);
        UI.updateTodoCardInPlace(devId);
        if (state.mediaCache[devId]) UI.renderNowPlaying(state.mediaCache[devId]);
        var st = state.statsCache[devId];
        if (st) {
          if (st.cpu) UI.updateStatsInPlace(devId, 'cpu');
          if (st.ram) UI.updateStatsInPlace(devId, 'ram');
          if (st.disk) UI.updateStatsInPlace(devId, 'disk');
          if (st.net) UI.updateStatsInPlace(devId, 'net');
        }
      });
    }
    Navigation.resetAmbientTimer();
  },

  resetAmbientTimer() {
    if (state.ambientInactivityTimer) {
      clearTimeout(state.ambientInactivityTimer);
      state.ambientInactivityTimer = null;
    }
    if (state.ambientTimeoutSec > 0 && !state.ambientActive) {
      state.ambientInactivityTimer = setTimeout(function() {
        Navigation.openAmbient();
      }, state.ambientTimeoutSec * 1000);
    }
  },

  toggleFullscreen() {
    try {
      var docEl = document.documentElement;
      var isFs = !!(document.fullscreenElement || document.webkitFullscreenElement);
      if (!isFs) {
        if (docEl.requestFullscreen) docEl.requestFullscreen();
        else if (docEl.webkitRequestFullscreen) docEl.webkitRequestFullscreen();
      } else {
        if (document.exitFullscreen) document.exitFullscreen();
        else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
      }
    } catch (e) {}
  },

  switchAdjacentPage(delta) {
    var deviceId = state.currentDeviceId;
    if (!deviceId) return;
    var pages = state.shortcutsCache[deviceId];
    if (!pages) return;
    var keys = Object.keys(pages);
    if (keys.length <= 1) return;
    var ordered = [];
    if (pages['home']) ordered.push('home');
    for (var i = 0; i < keys.length; i++) {
      if (keys[i] !== 'home') ordered.push(keys[i]);
    }
    var cur = (state.currentPageCache && state.currentPageCache[deviceId]) || 'home';
    var idx = ordered.indexOf(cur);
    if (idx < 0) idx = 0;
    var nextIdx = idx + delta;
    if (nextIdx < 0 || nextIdx >= ordered.length) return;
    if (UI.isSearchActive()) UI.resetSearchFilters(deviceId, false);
    UI.switchToPage(deviceId, ordered[nextIdx]);
  },
};

/* =========================================================
   6. EVENT BINDINGS
   ========================================================= */
function bindEvents() {
  if (dom.shortcutsGrid) {
    // Escudo contra ghost clicks / touch bleed-through após toque rápido ou troca de página
    var suppressGhostEvents = function(e) {
      var timeSinceSwitch = Date.now() - (state.lastPageSwitchTime || 0);
      var timeSinceTouch = Date.now() - (state.lastGlobalTouchEndTime || 0);
      if (timeSinceSwitch < 500 && timeSinceTouch < 700) {
        e.preventDefault();
        e.stopPropagation();
        if (typeof e.stopImmediatePropagation === 'function') {
          e.stopImmediatePropagation();
        }
      }
    };
    dom.shortcutsGrid.addEventListener('click', suppressGhostEvents, true);
    dom.shortcutsGrid.addEventListener('mousedown', suppressGhostEvents, true);
    dom.shortcutsGrid.addEventListener('mouseup', suppressGhostEvents, true);
  }

  if (dom.pageBreadcrumb) {
    UI.addFastTapListener(dom.pageBreadcrumb, function() {
      if (state.currentDeviceId) {
        if (UI.isSearchActive()) {
          UI.resetSearchFilters(state.currentDeviceId, false);
        }
        UI.switchToPage(state.currentDeviceId, 'home');
      }
    });
  }

  // Eventos do Now Playing e Media Drawer
  if (dom.nowPlaying) {
    UI.addFastTapListener(dom.nowPlaying, function(e) {
      if (e.target && (e.target.id === 'np-quick-play' || e.target.closest('#np-quick-play'))) {
        return;
      }
      Navigation.openMediaDrawer();
    });
  }

  if (dom.npQuickPlay) {
    UI.addFastTapListener(dom.npQuickPlay, function(e) {
      e.stopPropagation();
      var device = state.devices[state.currentDeviceId];
      if (device) MqttLayer.publishCommand(device, 'play_pause');
    });
  }

  if (dom.btnCloseMedia) {
    UI.addFastTapListener(dom.btnCloseMedia, Navigation.closeMediaDrawer);
  }
  if (dom.mediaBackdrop) {
    UI.addFastTapListener(dom.mediaBackdrop, Navigation.closeMediaDrawer);
  }

  if (dom.btnMediaPlayPause) {
    UI.addFastTapListener(dom.btnMediaPlayPause, function() {
      var device = state.devices[state.currentDeviceId];
      if (device) MqttLayer.publishCommand(device, 'play_pause');
    });
  }

  if (dom.btnMediaNext) {
    UI.addFastTapListener(dom.btnMediaNext, function() {
      var device = state.devices[state.currentDeviceId];
      if (device) MqttLayer.publishCommand(device, 'next');
    });
  }

  if (dom.btnMediaPrev) {
    UI.addFastTapListener(dom.btnMediaPrev, function() {
      var device = state.devices[state.currentDeviceId];
      if (device) MqttLayer.publishCommand(device, 'prev');
    });
  }

  if (dom.btnMediaRewind) {
    UI.addFastTapListener(dom.btnMediaRewind, function() {
      var device = state.devices[state.currentDeviceId];
      if (device) MqttLayer.publishCommand(device, 'rewind', { value: 10 });
    });
  }

  if (dom.btnMediaFastForward) {
    UI.addFastTapListener(dom.btnMediaFastForward, function() {
      var device = state.devices[state.currentDeviceId];
      if (device) MqttLayer.publishCommand(device, 'fast_forward', { value: 10 });
    });
  }

  if (dom.mediaSeekSlider) {
    var seekDebounceTimer = null;
    var onSeekStart = function() {
      state.mediaSeeking = true;
    };
    var onSeekEnd = function(e) {
      state.mediaSeeking = false;
      var targetSec = Number(e.target.value);
      var device = state.devices[state.currentDeviceId];
      if (device) {
        MqttLayer.publishCommand(device, 'seek', { value: targetSec });
      }
    };

    dom.mediaSeekSlider.addEventListener('mousedown', onSeekStart);
    dom.mediaSeekSlider.addEventListener('touchstart', onSeekStart, { passive: true });
    dom.mediaSeekSlider.addEventListener('mouseup', onSeekEnd);
    dom.mediaSeekSlider.addEventListener('touchend', onSeekEnd);

    dom.mediaSeekSlider.addEventListener('input', function(e) {
      var v = Number(e.target.value);
      if (dom.mediaTimeCurrent) dom.mediaTimeCurrent.textContent = UI.formatTime(v);
      var max = Number(e.target.max) || 100;
      var pct = max > 0 ? Math.max(0, Math.min(100, (v / max) * 100)) : 0;
      e.target.style.background = 'linear-gradient(to right, var(--accent-color) 0%, var(--accent-color) ' + pct + '%, var(--ctp-crust) ' + pct + '%, var(--ctp-crust) 100%)';

      if (seekDebounceTimer) clearTimeout(seekDebounceTimer);
      seekDebounceTimer = setTimeout(function() {
        var device = state.devices[state.currentDeviceId];
        if (device) {
          MqttLayer.publishCommand(device, 'seek', { value: v });
        }
      }, 250);
    });
  }

  if (dom.mediaVolumeSlider) {
    dom.mediaVolumeSlider.addEventListener('mousedown', function() { dom.mediaVolumeSlider._isDragging = true; });
    dom.mediaVolumeSlider.addEventListener('touchstart', function() { dom.mediaVolumeSlider._isDragging = true; }, { passive: true });
    var endVolDrag = function() { dom.mediaVolumeSlider._isDragging = false; };
    dom.mediaVolumeSlider.addEventListener('mouseup', endVolDrag);
    dom.mediaVolumeSlider.addEventListener('touchend', endVolDrag);

    dom.mediaVolumeSlider.addEventListener('input', function(e) {
      var v = Number(e.target.value);
      if (dom.mediaVolumeValue) dom.mediaVolumeValue.textContent = v + '%';
      UI.updateSliderFill(dom.mediaVolumeSlider, v);
      var device = state.devices[state.currentDeviceId];
      if (device) {
        MqttLayer.publishMasterVolume(device, v);
      }
    });
  }

  if (dom.btnMediaVolumeMute) {
    UI.addFastTapListener(dom.btnMediaVolumeMute, function() {
      var devId = state.currentDeviceId;
      var curVol = (devId && typeof state.volumeCache[devId] === 'number') ? state.volumeCache[devId] : 50;
      var targetVol = (curVol > 0) ? 0 : 50;
      var device = state.devices[devId];
      if (device) {
        MqttLayer.publishMasterVolume(device, targetVol);
      }
    });
  }

  // Configuração dos chips de velocidade de mídia
  var speedChips = document.querySelectorAll('.btn-speed-chip');
  if (speedChips && speedChips.length > 0) {
    for (var sIdx = 0; sIdx < speedChips.length; sIdx++) {
      (function(chip) {
        UI.addFastTapListener(chip, function() {
          var speed = Number(chip.getAttribute('data-speed')) || 1.0;
          state.mediaPlaybackRate = speed;
          UI.syncMediaSpeedChips(speed);
          var device = state.devices[state.currentDeviceId];
          if (device) {
            MqttLayer.publishCommand(device, 'set_playback_rate', { rate: speed });
          }
        });
      })(speedChips[sIdx]);
    }
  }

  if (dom.btnToggleMixer) {
    dom.btnToggleMixer.addEventListener('click', Navigation.openMixerDrawer);
  }
  dom.btnCloseMixer.addEventListener('click', Navigation.closeMixerDrawer);
  dom.mixerBackdrop.addEventListener('click', Navigation.closeMixerDrawer);

  if (dom.btnToggleEvents) {
    dom.btnToggleEvents.addEventListener('click', function() {
      if (state.eventsDrawerOpen) {
        Navigation.closeEventsDrawer();
      } else {
        Navigation.openEventsDrawer();
      }
    });
  }
  if (dom.btnCloseEvents) {
    dom.btnCloseEvents.addEventListener('click', Navigation.closeEventsDrawer);
  }
  if (dom.eventsBackdrop) {
    dom.eventsBackdrop.addEventListener('click', Navigation.closeEventsDrawer);
  }
  if (dom.btnClearEvents) {
    dom.btnClearEvents.addEventListener('click', function() {
      if (state.currentDeviceId) {
        UI.clearEvents(state.currentDeviceId);
      }
    });
  }

  // Eventos do Drawer de Tarefas (Todo)
  if (dom.btnCloseTodo) {
    UI.addFastTapListener(dom.btnCloseTodo, Navigation.closeTodoDrawer);
  }
  if (dom.todoBackdrop) {
    UI.addFastTapListener(dom.todoBackdrop, Navigation.closeTodoDrawer);
  }
  if (dom.btnClearDoneTodo) {
    UI.addFastTapListener(dom.btnClearDoneTodo, function() {
      var device = state.devices[state.currentDeviceId];
      if (device) {
        MqttLayer.publishCommand(device, 'todo_clear_done');
      }
    });
  }
  if (dom.btnAddTodo) {
    UI.addFastTapListener(dom.btnAddTodo, function() {
      if (!dom.todoInputText) return;
      var text = dom.todoInputText.value;
      if (!text || !text.trim()) {
        var device = state.devices[state.currentDeviceId];
        if (!device || !device.online) {
          UI.showToast({ message: 'Dispositivo host offline.', level: 'warn' });
          return;
        }
        MqttLayer.publishCommand(device, 'remote_todo_prompt');
        UI.showToast({ message: 'Digite a tarefa no teclado do PC...', level: 'info' });
        return;
      }
      var device = state.devices[state.currentDeviceId];
      if (device) {
        MqttLayer.publishCommand(device, 'todo_add', { text: text.trim() });
        dom.todoInputText.value = '';
      }
    });
  }
  if (dom.btnTodoPcPrompt) {
    UI.addFastTapListener(dom.btnTodoPcPrompt, function() {
      var device = state.devices[state.currentDeviceId];
      if (!device || !device.online) {
        UI.showToast({ message: 'Dispositivo host offline.', level: 'warn' });
        return;
      }
      MqttLayer.publishCommand(device, 'remote_todo_prompt');
      UI.showToast({ message: 'Digite a tarefa no teclado do PC...', level: 'info' });
    });
  }
  if (dom.todoAddForm) {
    dom.todoAddForm.addEventListener('submit', function(e) {
      if (e && e.preventDefault) e.preventDefault();
      if (!dom.todoInputText) return;
      var text = dom.todoInputText.value;
      if (!text || !text.trim()) return;
      var device = state.devices[state.currentDeviceId];
      if (device) {
        MqttLayer.publishCommand(device, 'todo_add', { text: text.trim() });
        dom.todoInputText.value = '';
      }
    });
  }

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

  // Sidebar overlay (modo 1 dispositivo)
  if (dom.btnToggleSidebar) {
    UI.addFastTapListener(dom.btnToggleSidebar, Navigation.toggleSidebar);
  }
  if (dom.sidebarBackdrop) {
    UI.addFastTapListener(dom.sidebarBackdrop, Navigation.closeSidebar);
  }

  // Botão rápido de mídia no header
  if (dom.btnToggleMedia) {
    UI.addFastTapListener(dom.btnToggleMedia, function() {
      if (state.mediaDrawerOpen) {
        Navigation.closeMediaDrawer();
      } else {
        Navigation.openMediaDrawer();
      }
    });
  }

  // Pill global "Parar Som"
  if (dom.btnStopSoundPill) {
    UI.addFastTapListener(dom.btnStopSoundPill, function() {
      var device = state.devices[state.currentDeviceId];
      if (device) MqttLayer.publishCommand(device, 'stop_sound');
    });
  }

  // Relógio e Modo Ambiente / Screensaver OLED
  if (dom.headerClock) {
    UI.addFastTapListener(dom.headerClock, Navigation.openAmbient);
  }
  if (dom.btnToggleAmbient) {
    UI.addFastTapListener(dom.btnToggleAmbient, Navigation.openAmbient);
  }
  if (dom.ambientOverlay) {
    UI.addFastTapListener(dom.ambientOverlay, function(e) {
      if (e && e.target && e.target.closest && e.target.closest('.ss-interactive')) {
        return;
      }
      if (e && e.preventDefault) e.preventDefault();
      if (e && e.stopPropagation) e.stopPropagation();
      Navigation.closeAmbient();
    });
  }
  if (dom.ambientTimeoutSelect) {
    dom.ambientTimeoutSelect.addEventListener('change', function(e) {
      var secs = parseInt(e.target.value, 10) || 0;
      state.ambientTimeoutSec = secs;
      try { localStorage.setItem('hub_ambient_timeout', String(secs)); } catch (err) {}
      Navigation.resetAmbientTimer();
    });
  }

  // Fullscreen toggle
  if (dom.btnToggleFullscreen) {
    UI.addFastTapListener(dom.btnToggleFullscreen, Navigation.toggleFullscreen);
  }

  // Bateria pill & drawer
  if (dom.btnToggleBatteries) {
    UI.addFastTapListener(dom.btnToggleBatteries, function() {
      if (state.batteryDrawerOpen) Navigation.closeBatteryDrawer();
      else Navigation.openBatteryDrawer();
    });
  }
  if (dom.btnCloseBattery) UI.addFastTapListener(dom.btnCloseBattery, Navigation.closeBatteryDrawer);
  if (dom.batteryBackdrop) UI.addFastTapListener(dom.batteryBackdrop, Navigation.closeBatteryDrawer);

  // Microfone Live toggle
  if (dom.btnToggleMic) {
    UI.addFastTapListener(dom.btnToggleMic, function() {
      var device = state.devices[state.currentDeviceId];
      if (device) MqttLayer.publishCommand(device, 'toggle_mic_mute');
    });
  }

  // Auto-Switch toggle (Auto / Fixo)
  if (dom.btnToggleAutoSwitch) {
    UI.addFastTapListener(dom.btnToggleAutoSwitch, function() {
      state.autoSwitchEnabled = !state.autoSwitchEnabled;
      UI.updateAutoSwitchButton();
      UI.showToast({
        message: state.autoSwitchEnabled ? 'Auto-Switch por app ativado' : 'Página fixada (Auto-Switch pausado)',
        level: 'info'
      });
    });
  }

  // Clipboard Bridge drawer & ações
  if (dom.btnToggleClipboard) {
    UI.addFastTapListener(dom.btnToggleClipboard, function() {
      if (state.clipboardDrawerOpen) Navigation.closeClipboardDrawer();
      else Navigation.openClipboardDrawer();
    });
  }
  if (dom.btnCloseClipboard) UI.addFastTapListener(dom.btnCloseClipboard, Navigation.closeClipboardDrawer);
  if (dom.clipboardBackdrop) UI.addFastTapListener(dom.clipboardBackdrop, Navigation.closeClipboardDrawer);
  if (dom.btnClipPull) {
    UI.addFastTapListener(dom.btnClipPull, function() {
      var device = state.devices[state.currentDeviceId];
      if (device) MqttLayer.publishCommand(device, 'clipboard_sync_to_tablet');
    });
  }
  if (dom.btnClipCopyLocal) {
    UI.addFastTapListener(dom.btnClipCopyLocal, function() {
      var text = state.currentDeviceId ? (state.clipboardCache[state.currentDeviceId] || '') : '';
      if (!text) return;
      try {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
        UI.showToast({ message: 'Copiado no tablet!', level: 'success' });
      } catch (e) {}
    });
  }
  if (dom.btnClipOpenLink) {
    UI.addFastTapListener(dom.btnClipOpenLink, function() {
      var text = state.currentDeviceId ? (state.clipboardCache[state.currentDeviceId] || '').trim() : '';
      if (/^https?:\/\/\S+/i.test(text)) {
        window.open(text, '_blank');
      }
    });
  }
  if (dom.btnClipSend) {
    UI.addFastTapListener(dom.btnClipSend, function() {
      var device = state.devices[state.currentDeviceId];
      var text = dom.clipSendInput ? dom.clipSendInput.value : '';
      if (!device || !text || !text.trim()) return;
      MqttLayer.publishCommand(device, 'clipboard_set_pc', { text: text, paste: false });
      dom.clipSendInput.value = '';
      UI.showToast({ message: 'Copiado no PC!', level: 'success' });
    });
  }
  if (dom.btnClipPaste) {
    UI.addFastTapListener(dom.btnClipPaste, function() {
      var device = state.devices[state.currentDeviceId];
      var text = dom.clipSendInput ? dom.clipSendInput.value : '';
      if (!device || !text || !text.trim()) return;
      MqttLayer.publishCommand(device, 'clipboard_set_pc', { text: text, paste: true });
      dom.clipSendInput.value = '';
      UI.showToast({ message: 'Colado no PC!', level: 'success' });
    });
  }

  // Resetar timer de inatividade em qualquer toque/clique
  var onUserActivity = function() {
    if (!state.ambientActive && state.ambientTimeoutSec > 0) {
      Navigation.resetAmbientTimer();
    }
  };
  document.addEventListener('touchstart', onUserActivity, { passive: true });
  document.addEventListener('mousedown', onUserActivity);

  // Swipe horizontal na grade para alternar páginas (ignorando sliders)
  if (dom.shortcutsGrid) {
    var swipeStartX = 0;
    var swipeStartY = 0;
    var swipeValid = false;
    dom.shortcutsGrid.addEventListener('touchstart', function(e) {
      if (!e.touches || e.touches.length !== 1) { swipeValid = false; return; }
      var target = e.target;
      if (target && (target.tagName === 'INPUT' || target.closest('.shortcut-btn--slider'))) {
        swipeValid = false;
        return;
      }
      swipeStartX = e.touches[0].clientX;
      swipeStartY = e.touches[0].clientY;
      swipeValid = true;
    }, { passive: true });

    dom.shortcutsGrid.addEventListener('touchend', function(e) {
      if (!swipeValid || !e.changedTouches || !e.changedTouches.length) return;
      swipeValid = false;
      var dx = e.changedTouches[0].clientX - swipeStartX;
      var dy = e.changedTouches[0].clientY - swipeStartY;
      if (Math.abs(dx) > 80 && Math.abs(dx) > Math.abs(dy) * 1.8) {
        Navigation.switchAdjacentPage(dx < 0 ? 1 : -1);
      }
    }, { passive: true });
  }
}

/* =========================================================
   6.5 AMBIENT STUDIO — MOTOR OTIMIZADO PARA ANDROID 5/6
   ========================================================= */
var AmbientStudio = {
  _tickTimer: null,
  _shiftTimer: null,
  _shiftStep: 0,
  _canvasRaf: null,
  _canvasLastTs: 0,
  _canvasItems: [],
  _canvasMode: null,
  _deviceId: null,
  _widgetNodes: {},
  _daysPt: ['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado'],
  _monthsPt: ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'],

  start: function(deviceId) {
    this._deviceId = deviceId;
    this.renderStage(deviceId);
    var self = this;
    if (this._tickTimer) clearInterval(this._tickTimer);
    // Tick leve de 1s: toca APENAS em relógio (segundos/minutos) e pomodoro
    this._tickTimer = setInterval(function() {
      if (state.ambientActive) self._tickClockAndPomodoro();
    }, 1000);
    this._startBurnInShift();
  },

  stop: function() {
    if (this._tickTimer) {
      clearInterval(this._tickTimer);
      this._tickTimer = null;
    }
    if (this._shiftTimer) {
      clearInterval(this._shiftTimer);
      this._shiftTimer = null;
    }
    this._stopCanvas();
    if (dom.ambientStage) {
      dom.ambientStage.style.webkitTransform = '';
      dom.ambientStage.style.transform = '';
    }
  },

  _startBurnInShift: function() {
    if (this._shiftTimer) clearInterval(this._shiftTimer);
    var cfg = this._deviceId ? state.screensaverCache[this._deviceId] : null;
    if (!cfg || cfg.burn_in_protection === false || !dom.ambientStage) return;
    var offsets = [
      [0, 0], [5, 3], [7, -2], [3, -5], [-4, -4], [-7, 2], [-3, 5], [2, 4]
    ];
    var self = this;
    this._shiftTimer = setInterval(function() {
      if (!state.ambientActive || !dom.ambientStage) return;
      self._shiftStep = (self._shiftStep + 1) % offsets.length;
      var pt = offsets[self._shiftStep];
      var tr = 'translate3d(' + pt[0] + 'px,' + pt[1] + 'px,0)';
      dom.ambientStage.style.webkitTransform = tr;
      dom.ambientStage.style.transform = tr;
    }, 60000);
  },

  renderStage: function(deviceId) {
    this._deviceId = deviceId;
    var cfg = deviceId ? state.screensaverCache[deviceId] : null;
    if (!dom.ambientOverlay || !dom.ambientStage) return;

    if (!cfg || !cfg.widgets || !cfg.widgets.length) {
      if (dom.ambientFallback) dom.ambientFallback.style.display = 'flex';
      dom.ambientStage.style.display = 'none';
      dom.ambientOverlay.style.background = '#000000';
      this._stopCanvas();
      return;
    }

    if (dom.ambientFallback) dom.ambientFallback.style.display = 'none';
    dom.ambientStage.style.display = 'block';

    var bgStyle = cfg.background_style || 'aurora';
    var bgColor = cfg.background_color || '#06070d';
    var accent = cfg.accent_color || '#cba6f7';
    var speed = cfg.animation_speed || 'normal';

    dom.ambientOverlay.style.background = bgColor;
    dom.ambientOverlay.style.setProperty('--ss-accent', accent);
    dom.ambientOverlay.className = 'ambient-overlay ambient-overlay--active ambient-overlay--bg-' + bgStyle + ' ambient-overlay--speed-' + speed;

    if (dom.ambientWakeHint) {
      dom.ambientWakeHint.style.display = cfg.show_wake_hint === false ? 'none' : 'block';
    }

    if (dom.ambientBgImg && dom.ambientBgDim) {
      if (bgStyle === 'image' && cfg.background_image) {
        dom.ambientBgImg.src = cfg.background_image;
        dom.ambientBgImg.style.objectFit = cfg.background_fit === 'contain' ? 'contain' : 'cover';
        dom.ambientBgImg.style.display = 'block';
        dom.ambientBgDim.style.opacity = String(typeof cfg.background_dim === 'number' ? cfg.background_dim : 0.35);
        dom.ambientBgDim.style.display = 'block';
      } else {
        dom.ambientBgImg.style.display = 'none';
        dom.ambientBgDim.style.display = 'none';
      }
    }

    // Fundos animados rodam no Canvas 2D leve (rAF + alpha:false + escala reduzida)
    if (bgStyle === 'starfield' || bgStyle === 'particles' || bgStyle === 'matrix_rain' || bgStyle === 'aurora' || bgStyle === 'mesh_glow') {
      this._startCanvas(bgStyle, bgColor, accent, speed);
    } else {
      this._stopCanvas();
    }

    // Constrói os esqueletos DOM UMA ÚNICA VEZ
    dom.ambientStage.innerHTML = '';
    this._widgetNodes = {};

    var widgets = cfg.widgets.slice().sort(function(a, b) {
      return (a.z_index || 1) - (b.z_index || 1);
    });

    for (var i = 0; i < widgets.length; i++) {
      var w = widgets[i];
      var built = this._createWidgetNode(w);
      dom.ambientStage.appendChild(built.el);
      this._widgetNodes[w.id] = built;
    }

    if (typeof UI !== 'undefined' && UI.wakeGifsInContainer) {
      UI.wakeGifsInContainer(dom.ambientOverlay);
    }
    this.updateLiveData();
  },

  _createWidgetNode: function(w) {
    var el = document.createElement('div');
    var cardStyle = w.card_style || 'glass';
    var align = w.align || 'center';
    el.className = 'ss-widget ss-widget--' + cardStyle + ' ss-widget--align-' + align + ' ss-widget--' + w.type;
    el.style.left = (w.x || 0) + '%';
    el.style.top = (w.y || 0) + '%';
    el.style.width = (w.w || 30) + '%';
    el.style.height = (w.h || 20) + '%';
    el.style.zIndex = String(w.z_index || 1);
    if (typeof w.opacity === 'number') el.style.opacity = String(w.opacity);
    if (w.accent_color) el.style.setProperty('--w-accent', w.accent_color);

    var cfg = w.config || {};
    var refs = {};

    if (w.type === 'clock') {
      var style = cfg.clock_style || 'digital';
      var scale = typeof w.scale === 'number' ? w.scale : 1.0;
      if (style === 'analog') {
        el.innerHTML =
          '<svg class="ss-clock__analog" viewBox="0 0 100 100" style="transform:scale(' + scale + ')">' +
          '<circle cx="50" cy="50" r="46" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="2.5"/>' +
          '<line data-r="h" x1="50" y1="50" x2="50" y2="24" stroke="#ffffff" stroke-width="3.2" stroke-linecap="round"/>' +
          '<line data-r="m" x1="50" y1="50" x2="50" y2="15" stroke="rgba(255,255,255,0.8)" stroke-width="2.2" stroke-linecap="round"/>' +
          (cfg.show_seconds !== false ? '<line data-r="s" x1="50" y1="54" x2="50" y2="12" stroke="var(--w-accent, var(--ss-accent))" stroke-width="1.3" stroke-linecap="round"/>' : '') +
          '<circle cx="50" cy="50" r="3" fill="var(--w-accent, var(--ss-accent))"/>' +
          '</svg>' +
          (cfg.show_date !== false ? '<div class="ss-clock__date" data-r="date"></div>' : '');
        refs.analog = true;
        refs.h = el.querySelector('[data-r="h"]');
        refs.m = el.querySelector('[data-r="m"]');
        refs.s = el.querySelector('[data-r="s"]');
        refs.date = el.querySelector('[data-r="date"]');
      } else {
        el.innerHTML =
          '<div class="ss-clock--' + style + '" style="transform:scale(' + scale + ')">' +
          '<div class="ss-clock__time-row">' +
          '<span class="ss-clock__main" data-r="main">--:--</span>' +
          (cfg.show_seconds !== false ? '<span class="ss-clock__sec" data-r="sec">00</span>' : '') +
          '</div>' +
          (cfg.show_date !== false ? '<div class="ss-clock__date" data-r="date"></div>' : '') +
          '</div>';
        refs.main = el.querySelector('[data-r="main"]');
        refs.sec = el.querySelector('[data-r="sec"]');
        refs.date = el.querySelector('[data-r="date"]');
      }
    } else if (w.type === 'pc_stats') {
      var layout = cfg.layout || 'rings';
      var defs = [];
      if (cfg.show_cpu !== false) defs.push({ key: 'cpu', label: 'CPU', color: '#cba6f7' });
      if (cfg.show_ram !== false) defs.push({ key: 'ram', label: 'RAM', color: '#89b4fa' });
      if (cfg.show_disk !== false) defs.push({ key: 'disk', label: 'Disco', color: '#a6e3a1' });
      refs.layout = layout;
      refs.metrics = [];
      if (layout === 'bars') {
        var bHtml = '<div class="ss-bars">';
        for (var bi = 0; bi < defs.length; bi++) {
          bHtml += '<div>' +
            '<div class="ss-bar__row"><span data-lbl="' + bi + '">' + defs[bi].label + '</span><span data-val="' + bi + '">0%</span></div>' +
            '<div class="ss-bar__track"><div class="ss-bar__fill" data-fill="' + bi + '" style="width:0%;background:' + defs[bi].color + ';"></div></div>' +
            '</div>';
        }
        bHtml += '</div>';
        el.innerHTML = bHtml;
      } else {
        var circ = 2 * Math.PI * 26;
        refs.circ = circ;
        var rHtml = '<div class="ss-stats__grid">';
        for (var ri = 0; ri < defs.length; ri++) {
          rHtml += '<div class="ss-ring">' +
            '<svg class="ss-ring__svg" viewBox="0 0 64 64">' +
            '<circle class="ss-ring__bg" cx="32" cy="32" r="26"/>' +
            '<circle class="ss-ring__fg" data-fill="' + ri + '" cx="32" cy="32" r="26" stroke="' + defs[ri].color + '" stroke-dasharray="' + circ.toFixed(1) + '" stroke-dashoffset="' + circ.toFixed(1) + '"/>' +
            '</svg>' +
            '<div class="ss-ring__val" data-val="' + ri + '">0%</div>' +
            '<div class="ss-ring__lbl" data-lbl="' + ri + '">' + defs[ri].label + '</div>' +
            '</div>';
        }
        rHtml += '</div>';
        el.innerHTML = rHtml;
      }
      for (var mi = 0; mi < defs.length; mi++) {
        refs.metrics.push({
          key: defs[mi].key,
          baseLabel: defs[mi].label,
          valEl: el.querySelector('[data-val="' + mi + '"]'),
          lblEl: el.querySelector('[data-lbl="' + mi + '"]'),
          fillEl: el.querySelector('[data-fill="' + mi + '"]')
        });
      }
    } else if (w.type === 'media') {
      el.innerHTML = this._mediaSkeleton(cfg);
      this._bindMediaControls(el);
      refs.title = el.querySelector('[data-role="title"]');
      refs.artist = el.querySelector('[data-role="artist"]');
      refs.vinyl = el.querySelector('[data-role="vinyl"]');
      refs.playbtn = el.querySelector('[data-role="playbtn"]');
    } else if (w.type === 'pomodoro') {
      el.innerHTML = '<div class="ss-pomo__phase" data-r="phase">Pomodoro</div><div class="ss-pomo__time" data-r="time">25:00</div>';
      refs.phase = el.querySelector('[data-r="phase"]');
      refs.time = el.querySelector('[data-r="time"]');
    } else if (w.type === 'network') {
      el.innerHTML = '<div class="ss-net__row"><span data-r="rx">↓ 0 KB/s</span><span data-r="tx">↑ 0 KB/s</span></div>';
      refs.rx = el.querySelector('[data-r="rx"]');
      refs.tx = el.querySelector('[data-r="tx"]');
    } else if (w.type === 'image') {
      var anim = cfg.floating_anim || 'none';
      if (anim === 'float') el.classList.add('ss-anim-float');
      else if (anim === 'pulse') el.classList.add('ss-anim-pulse');
      var radius = typeof cfg.border_radius === 'number' ? cfg.border_radius : 16;
      el.style.borderRadius = radius + 'px';
      if (cfg.image_data) {
        var img = document.createElement('img');
        img.className = 'ss-widget__img';
        img.src = cfg.image_data;
        img.style.objectFit = cfg.fit === 'contain' ? 'contain' : 'cover';
        img.style.borderRadius = radius + 'px';
        el.appendChild(img);
      }
    } else if (w.type === 'text') {
      var txt = document.createElement('div');
      txt.className = 'ss-text__content';
      txt.style.fontSize = (cfg.font_size || 20) + 'px';
      txt.textContent = cfg.content || '';
      el.appendChild(txt);
    }

    return { el: el, def: w, refs: refs, lastKey: '' };
  },

  _mediaSkeleton: function(cfg) {
    var html = '<div class="ss-media__row">';
    if (cfg.show_vinyl !== false) {
      html += '<div class="ss-media__vinyl" data-role="vinyl"></div>';
    }
    html += '<div class="ss-media__info">' +
      '<div class="ss-media__title" data-role="title">Nenhuma mídia</div>' +
      '<div class="ss-media__artist" data-role="artist"></div>' +
      '</div>';
    if (cfg.show_controls !== false) {
      html += '<div class="ss-media__controls ss-interactive">' +
        '<button type="button" class="ss-media__btn ss-interactive" data-media-cmd="prev">⏮</button>' +
        '<button type="button" class="ss-media__btn ss-interactive" data-media-cmd="play_pause" data-role="playbtn">⏯</button>' +
        '<button type="button" class="ss-media__btn ss-interactive" data-media-cmd="next">⏭</button>' +
        '</div>';
    }
    html += '</div>';
    return html;
  },

  _bindMediaControls: function(el) {
    var btns = el.querySelectorAll('[data-media-cmd]');
    for (var i = 0; i < btns.length; i++) {
      (function(btn) {
        UI.addFastTapListener(btn, function(e) {
          if (e && e.stopPropagation) e.stopPropagation();
          var cmd = btn.getAttribute('data-media-cmd');
          var dev = state.devices[state.currentDeviceId];
          if (dev && cmd) MqttLayer.publishCommand(dev, cmd);
        });
      })(btns[i]);
    }
  },

  _tickClockAndPomodoro: function() {
    var devId = this._deviceId || state.currentDeviceId;
    var keys = Object.keys(this._widgetNodes);
    if (!keys.length) return;
    var now = new Date();
    var pomo = devId ? state.pomodoroCache[devId] : null;
    for (var i = 0; i < keys.length; i++) {
      var entry = this._widgetNodes[keys[i]];
      if (!entry) continue;
      if (entry.def.type === 'clock') {
        this._updateClock(entry, now);
      } else if (entry.def.type === 'pomodoro') {
        this._updatePomodoro(entry, pomo);
      }
    }
  },

  updateByType: function(type) {
    if (!state.ambientActive) return;
    var devId = this._deviceId || state.currentDeviceId;
    var keys = Object.keys(this._widgetNodes);
    if (!keys.length) return;
    for (var i = 0; i < keys.length; i++) {
      var entry = this._widgetNodes[keys[i]];
      if (!entry || entry.def.type !== type) continue;
      this._updateEntry(entry, devId, null);
    }
  },

  updateLiveData: function() {
    var devId = this._deviceId || state.currentDeviceId;
    var keys = Object.keys(this._widgetNodes);
    if (!keys.length) return;
    var now = new Date();
    for (var i = 0; i < keys.length; i++) {
      var entry = this._widgetNodes[keys[i]];
      if (entry) this._updateEntry(entry, devId, now);
    }
  },

  _updateEntry: function(entry, devId, now) {
    var t = entry.def.type;
    if (t === 'clock') {
      this._updateClock(entry, now || new Date());
    } else if (t === 'weather') {
      this._updateWeather(entry, devId ? state.weatherCache[devId] : null);
    } else if (t === 'pc_stats') {
      this._updatePcStats(entry, devId ? state.statsCache[devId] : null);
    } else if (t === 'media') {
      this._updateMedia(entry, devId ? state.mediaCache[devId] : null);
    } else if (t === 'batteries') {
      this._updateBatteries(entry, devId ? (state.batteriesCache[devId] || []) : []);
    } else if (t === 'pomodoro') {
      this._updatePomodoro(entry, devId ? state.pomodoroCache[devId] : null);
    } else if (t === 'todos') {
      this._updateTodos(entry, devId ? state.todosCache[devId] : null);
    } else if (t === 'network') {
      this._updateNetwork(entry, devId ? state.statsCache[devId] : null);
    }
  },

  _updateClock: function(entry, now) {
    var cfg = entry.def.config || {};
    var showSec = cfg.show_seconds !== false;
    var h = now.getHours();
    var m = now.getMinutes();
    var s = now.getSeconds();
    var key = showSec ? (h + ':' + m + ':' + s) : (h + ':' + m);
    if (entry.lastKey === key) return;
    entry.lastKey = key;

    var refs = entry.refs;
    if (refs.analog) {
      if (refs.h) refs.h.setAttribute('transform', 'rotate(' + (((h % 12) + m / 60) * 30).toFixed(1) + ' 50 50)');
      if (refs.m) refs.m.setAttribute('transform', 'rotate(' + (m * 6) + ' 50 50)');
      if (refs.s) refs.s.setAttribute('transform', 'rotate(' + (s * 6) + ' 50 50)');
    } else {
      var hhmm = (h < 10 ? '0' : '') + h + ':' + (m < 10 ? '0' : '') + m;
      if (refs.main && refs.main.textContent !== hhmm) refs.main.textContent = hhmm;
      if (refs.sec) refs.sec.textContent = (s < 10 ? '0' : '') + s;
    }

    if (refs.date) {
      var dateKey = now.getDate() + '-' + now.getMonth();
      if (refs._lastDateKey !== dateKey) {
        refs._lastDateKey = dateKey;
        refs.date.textContent = this._daysPt[now.getDay()] + ', ' + now.getDate() + ' de ' + this._monthsPt[now.getMonth()];
      }
    }
  },

  _weatherIconSvg: function(icon) {
    if (icon === 'clear_day') {
      return '<svg class="ss-weather__icon" viewBox="0 0 48 48"><circle cx="24" cy="24" r="10" fill="#f9e2af"/><g stroke="#f9e2af" stroke-width="3" stroke-linecap="round"><line x1="24" y1="4" x2="24" y2="9"/><line x1="24" y1="39" x2="24" y2="44"/><line x1="4" y1="24" x2="9" y2="24"/><line x1="39" y1="24" x2="44" y2="24"/><line x1="10" y1="10" x2="14" y2="14"/><line x1="34" y1="34" x2="38" y2="38"/><line x1="38" y1="10" x2="34" y2="14"/><line x1="14" y1="34" x2="10" y2="38"/></g></svg>';
    }
    if (icon === 'clear_night') {
      return '<svg class="ss-weather__icon" viewBox="0 0 48 48"><path d="M31 29a13 13 0 0 1-14-18 14 14 0 1 0 18 18z" fill="#b4befe"/></svg>';
    }
    if (icon === 'rain' || icon === 'drizzle') {
      return '<svg class="ss-weather__icon" viewBox="0 0 48 48"><path d="M14 29h21a7 7 0 0 0 1-14 10 10 0 0 0-19-2 8 8 0 0 0-3 16z" fill="#9399b2"/><g stroke="#89b4fa" stroke-width="2.6" stroke-linecap="round"><line x1="17" y1="33" x2="15" y2="41"/><line x1="24" y1="33" x2="22" y2="41"/><line x1="31" y1="33" x2="29" y2="41"/></g></svg>';
    }
    if (icon === 'storm') {
      return '<svg class="ss-weather__icon" viewBox="0 0 48 48"><path d="M14 27h21a7 7 0 0 0 1-14 10 10 0 0 0-19-2 8 8 0 0 0-3 16z" fill="#7f849c"/><polygon points="25,28 19,38 24,38 22,46 31,34 26,34" fill="#f9e2af"/></svg>';
    }
    return '<svg class="ss-weather__icon" viewBox="0 0 48 48"><circle cx="18" cy="18" r="7" fill="#f9e2af"/><path d="M16 34h19a7 7 0 0 0 1-14 9 9 0 0 0-17-2 7 7 0 0 0-3 16z" fill="#cdd6f4"/></svg>';
  },

  _updateWeather: function(entry, w) {
    var key = w ? (w.updated_at + '|' + w.temp + '|' + w.city) : 'empty';
    if (entry.lastKey === key) return;
    entry.lastKey = key;

    var cfg = entry.def.config || {};
    if (!w) {
      entry.el.innerHTML = '<div class="ss-weather__meta">Aguardando clima do PC...</div>';
      return;
    }
    var subParts = [];
    if (cfg.show_feels_like !== false && typeof w.feels_like === 'number') subParts.push('Sensação ' + w.feels_like + '°');
    if (cfg.show_humidity !== false && typeof w.humidity === 'number') subParts.push('Umid. ' + w.humidity + '%');
    if (cfg.show_wind && typeof w.wind_kmh === 'number') subParts.push('Vento ' + w.wind_kmh + ' km/h');

    var html = '<div class="ss-weather__top">' +
      this._weatherIconSvg(w.icon) +
      '<div>' +
      '<div class="ss-weather__temp">' + w.temp + '°' + (w.unit || 'C') + '</div>' +
      '<div class="ss-weather__meta">' + (w.city || '') + ' · ' + (w.condition || '') + '</div>' +
      '</div></div>';

    if (subParts.length) {
      html += '<div class="ss-weather__sub">' + subParts.join(' · ') + '</div>';
    }
    if (cfg.show_forecast !== false && w.forecast && w.forecast.length) {
      html += '<div class="ss-weather__forecast">';
      for (var i = 0; i < w.forecast.length && i < 3; i++) {
        var d = w.forecast[i];
        html += '<div class="ss-weather__day">' +
          '<div class="ss-weather__day-name">' + d.day + '</div>' +
          '<div class="ss-weather__day-temps">' + d.max + '° / ' + d.min + '°</div>' +
          '</div>';
      }
      html += '</div>';
    }
    entry.el.innerHTML = html;
  },

  _updatePcStats: function(entry, stats) {
    var cpu = (stats && stats.cpu && typeof stats.cpu.load === 'number') ? stats.cpu.load : 0;
    var temp = (stats && stats.cpu && typeof stats.cpu.temp === 'number') ? stats.cpu.temp : null;
    var ram = (stats && stats.ram && typeof stats.ram.percent === 'number') ? stats.ram.percent : 0;
    var disk = (stats && stats.disk && typeof stats.disk.percent === 'number') ? stats.disk.percent : 0;

    var key = cpu + '|' + temp + '|' + ram + '|' + disk;
    if (entry.lastKey === key) return;
    entry.lastKey = key;

    var cfg = entry.def.config || {};
    var refs = entry.refs;
    var values = { cpu: cpu, ram: ram, disk: disk };

    for (var i = 0; i < refs.metrics.length; i++) {
      var m = refs.metrics[i];
      var pct = values[m.key] || 0;
      if (m.valEl) m.valEl.textContent = pct + '%';
      if (m.key === 'cpu' && m.lblEl) {
        m.lblEl.textContent = 'CPU' + (cfg.show_temp && temp !== null ? ' ' + temp + '°' : '');
      }
      if (m.fillEl) {
        if (refs.layout === 'bars') {
          m.fillEl.style.width = pct + '%';
        } else {
          var offset = refs.circ - (pct / 100) * refs.circ;
          m.fillEl.setAttribute('stroke-dashoffset', offset.toFixed(1));
        }
      }
    }
  },

  _updateMedia: function(entry, media) {
    var playing = !!(media && media.status === 'Playing');
    var title = (media && media.title) ? media.title : 'Nenhuma mídia tocando';
    var artist = (media && media.artist) ? media.artist : '';
    var key = playing + '|' + title + '|' + artist;
    if (entry.lastKey === key) return;
    entry.lastKey = key;

    var refs = entry.refs;
    if (refs.title) refs.title.textContent = title;
    if (refs.artist) refs.artist.textContent = artist;
    if (refs.vinyl) refs.vinyl.classList.toggle('ss-media__vinyl--spinning', playing);
    if (refs.playbtn) refs.playbtn.textContent = playing ? '⏸' : '▶';
  },

  _updateBatteries: function(entry, pcBats) {
    var cfg = entry.def.config || {};
    var list = [];
    if (cfg.show_tablet !== false && state.tabletBattery) {
      list.push('Tablet ' + state.tabletBattery.percent + '%' + (state.tabletBattery.charging ? ' ⚡' : ''));
    }
    for (var i = 0; i < pcBats.length; i++) {
      var b = pcBats[i];
      if (b.kind === 'system' && cfg.show_pc === false) continue;
      if (b.kind !== 'system' && cfg.show_bluetooth === false) continue;
      list.push((b.name || 'Disp.') + ' ' + b.percent + '%' + (b.charging ? ' ⚡' : ''));
    }
    var key = list.join('|');
    if (entry.lastKey === key) return;
    entry.lastKey = key;

    if (!list.length) {
      entry.el.innerHTML = '<div class="ss-bat__row"><span class="ss-bat__pill">Sem baterias detectadas</span></div>';
      return;
    }
    var html = '<div class="ss-bat__row">';
    for (var j = 0; j < list.length; j++) {
      html += '<span class="ss-bat__pill">' + list[j] + '</span>';
    }
    html += '</div>';
    entry.el.innerHTML = html;
  },

  _updatePomodoro: function(entry, pomo) {
    var labels = { 'focus': 'Foco', 'short_break': 'Pausa Curta', 'long_break': 'Pausa Longa', 'idle': 'Pomodoro' };
    var phase = (pomo && pomo.phase) ? (labels[pomo.phase] || 'Foco') : 'Pomodoro';
    var time = (pomo && typeof pomo.remaining_ms === 'number') ? UI.formatPomodoroTime(pomo.remaining_ms) : '25:00';
    var key = phase + '|' + time;
    if (entry.lastKey === key) return;
    entry.lastKey = key;

    if (entry.refs.phase) entry.refs.phase.textContent = phase;
    if (entry.refs.time) entry.refs.time.textContent = time;
  },

  _updateTodos: function(entry, todos) {
    var cfg = entry.def.config || {};
    var maxItems = cfg.max_items || 4;
    var items = (todos && todos.items) ? todos.items.filter(function(t) { return !t.done; }) : [];
    var parts = [];
    for (var i = 0; i < items.length && i < maxItems; i++) parts.push(items[i].text);
    var key = parts.join('|');
    if (entry.lastKey === key) return;
    entry.lastKey = key;

    if (!parts.length) {
      entry.el.innerHTML = '<div class="ss-todos__list"><div class="ss-todos__item">✓ Tudo concluído</div></div>';
      return;
    }
    var html = '<div class="ss-todos__list">';
    for (var j = 0; j < parts.length; j++) {
      html += '<div class="ss-todos__item">○ ' + parts[j] + '</div>';
    }
    html += '</div>';
    entry.el.innerHTML = html;
  },

  _updateNetwork: function(entry, stats) {
    var rx = (stats && stats.net && typeof stats.net.rx_kbps === 'number') ? stats.net.rx_kbps : 0;
    var tx = (stats && stats.net && typeof stats.net.tx_kbps === 'number') ? stats.net.tx_kbps : 0;
    var key = Math.round(rx) + '|' + Math.round(tx);
    if (entry.lastKey === key) return;
    entry.lastKey = key;

    var fmt = function(kb) {
      return kb >= 1024 ? (kb / 1024).toFixed(1) + ' MB/s' : Math.round(kb) + ' KB/s';
    };
    if (entry.refs.rx) entry.refs.rx.textContent = '↓ ' + fmt(rx);
    if (entry.refs.tx) entry.refs.tx.textContent = '↑ ' + fmt(tx);
  },

  _hexToRgb: function(hex) {
    var clean = String(hex || '#cba6f7').replace('#', '');
    if (clean.length === 3) clean = clean[0] + clean[0] + clean[1] + clean[1] + clean[2] + clean[2];
    var num = parseInt(clean, 16);
    if (isNaN(num)) return [203, 166, 247];
    return [(num >> 16) & 255, (num >> 8) & 255, num & 255];
  },

  _makeDotSprite: function(color, radius) {
    var c = document.createElement('canvas');
    var sz = Math.ceil(radius * 2 + 2);
    c.width = sz;
    c.height = sz;
    var g = c.getContext('2d');
    if (g) {
      g.fillStyle = color;
      g.beginPath();
      g.arc(sz / 2, sz / 2, radius, 0, Math.PI * 2);
      g.fill();
    }
    return c;
  },

  _startCanvas: function(mode, bgColor, accent, speed) {
    this._stopCanvas();
    var canvas = dom.ambientCanvas;
    if (!canvas || !canvas.getContext) return;
    canvas.style.display = 'block';

    var isAurora = (mode === 'aurora' || mode === 'mesh_glow');
    var scale = isAurora ? 0.18 : 0.5;
    var rawW = window.innerWidth || 800;
    var rawH = window.innerHeight || 480;
    var w = canvas.width = isAurora ? 160 : Math.max(320, Math.round(rawW * scale));
    var h = canvas.height = isAurora ? 100 : Math.max(200, Math.round(rawH * scale));

    var ctx = canvas.getContext('2d', { alpha: false }) || canvas.getContext('2d');
    if (!ctx) return;

    this._canvasMode = mode;
    var rgb = this._hexToRgb(accent);
    var rgbStr = rgb[0] + ',' + rgb[1] + ',' + rgb[2];
    var speedMult = speed === 'slow' ? 0.55 : (speed === 'vivid' ? 1.65 : 1.0);
    var targetFps = isAurora ? 18 : (speed === 'slow' ? 20 : (speed === 'vivid' ? 38 : 30));
    var minInterval = 1000 / targetFps;

    var items = [];
    var dotSprite = null;
    var nearStroke = 'rgba(' + rgbStr + ',0.30)';
    var farStroke = 'rgba(' + rgbStr + ',0.12)';
    var starColors = ['rgba(255,255,255,0.28)', 'rgba(255,255,255,0.58)', 'rgba(255,255,255,0.92)'];
    var auroraPhase = 0;

    if (mode === 'starfield') {
      for (var i = 0; i < 48; i++) {
        items.push({
          x: Math.random() * w,
          y: Math.random() * h,
          s: (i % 5 === 0) ? 2 : 1,
          v: (10 + Math.random() * 24) * speedMult,
          b: i % 3
        });
      }
    } else if (mode === 'particles') {
      dotSprite = this._makeDotSprite(accent, 2.2);
      for (var p = 0; p < 18; p++) {
        items.push({
          x: Math.random() * w,
          y: Math.random() * h,
          vx: (Math.random() - 0.5) * 34 * speedMult,
          vy: (Math.random() - 0.5) * 34 * speedMult
        });
      }
    } else if (mode === 'matrix_rain') {
      var step = 14;
      var cols = Math.floor(w / step);
      for (var c = 0; c < cols; c++) {
        items.push({
          x: c * step + 4,
          y: Math.random() * h,
          v: (42 + Math.random() * 68) * speedMult
        });
      }
      ctx.fillStyle = bgColor;
      ctx.fillRect(0, 0, w, h);
      ctx.font = '10px monospace';
    }
    this._canvasItems = items;

    var self = this;
    var raf = window.requestAnimationFrame || function(cb) { return setTimeout(function() { cb(Date.now()); }, 33); };
    this._canvasLastTs = 0;

    var frame = function(ts) {
      if (!state.ambientActive || self._canvasMode !== mode) {
        self._stopCanvas();
        return;
      }
      self._canvasRaf = raf(frame);

      if (self._canvasLastTs && (ts - self._canvasLastTs) < minInterval) {
        return;
      }
      var dt = self._canvasLastTs ? Math.min(0.1, (ts - self._canvasLastTs) / 1000) : 0.033;
      self._canvasLastTs = ts;

      if (isAurora) {
        auroraPhase += dt * 0.35 * speedMult;
        ctx.fillStyle = bgColor;
        ctx.fillRect(0, 0, w, h);

        var x1 = w * (0.28 + 0.18 * Math.sin(auroraPhase));
        var y1 = h * (0.30 + 0.16 * Math.cos(auroraPhase * 0.8));
        var g1 = ctx.createRadialGradient(x1, y1, 4, x1, y1, w * 0.62);
        g1.addColorStop(0, 'rgba(' + rgbStr + ',' + (mode === 'mesh_glow' ? '0.42' : '0.32') + ')');
        g1.addColorStop(1, 'rgba(' + rgbStr + ',0)');
        ctx.fillStyle = g1;
        ctx.fillRect(0, 0, w, h);

        var x2 = w * (0.74 + 0.16 * Math.cos(auroraPhase * 0.7));
        var y2 = h * (0.72 + 0.14 * Math.sin(auroraPhase * 0.9));
        var g2 = ctx.createRadialGradient(x2, y2, 4, x2, y2, w * 0.58);
        g2.addColorStop(0, 'rgba(137,180,250,0.28)');
        g2.addColorStop(1, 'rgba(137,180,250,0)');
        ctx.fillStyle = g2;
        ctx.fillRect(0, 0, w, h);
        return;
      }

      if (mode === 'matrix_rain') {
        ctx.fillStyle = 'rgba(0,0,0,0.16)';
        ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = accent;
        for (var k = 0; k < items.length; k++) {
          var col = items[k];
          ctx.fillText(String.fromCharCode(48 + ((ts + k * 7) % 42)), col.x, col.y);
          col.y += col.v * dt;
          if (col.y > h) col.y = -8;
        }
        return;
      }

      // Fundo sólido opaco (sem alpha blending)
      ctx.fillStyle = bgColor;
      ctx.fillRect(0, 0, w, h);

      if (mode === 'starfield') {
        for (var bIdx = 0; bIdx < 3; bIdx++) {
          ctx.fillStyle = starColors[bIdx];
          for (var s = 0; s < items.length; s++) {
            var st = items[s];
            if (st.b !== bIdx) continue;
            st.y -= st.v * dt;
            if (st.y < 0) { st.y = h; st.x = Math.random() * w; }
            ctx.fillRect(st.x | 0, st.y | 0, st.s, st.s);
          }
        }
      } else if (mode === 'particles') {
        var maxDistSq = 6400; // 80px na escala 0.5x (= 160px reais)
        var nearDistSq = 2500;
        var halfSp = dotSprite.width * 0.5;

        // 1. Atualiza posições e desenha bolinhas via sprite pré-renderizado
        for (var a = 0; a < items.length; a++) {
          var pt = items[a];
          pt.x += pt.vx * dt;
          pt.y += pt.vy * dt;
          if (pt.x < 0) { pt.x = 0; pt.vx = -pt.vx; }
          else if (pt.x > w) { pt.x = w; pt.vx = -pt.vx; }
          if (pt.y < 0) { pt.y = 0; pt.vy = -pt.vy; }
          else if (pt.y > h) { pt.y = h; pt.vy = -pt.vy; }
          ctx.drawImage(dotSprite, (pt.x - halfSp) | 0, (pt.y - halfSp) | 0);
        }

        // 2. Desenha todas as conexões em apenas 2 batches (near e far)
        ctx.lineWidth = 1;
        ctx.strokeStyle = nearStroke;
        ctx.beginPath();
        for (var i1 = 0; i1 < items.length; i1++) {
          var p1 = items[i1];
          for (var j1 = i1 + 1; j1 < items.length; j1++) {
            var p2 = items[j1];
            var dx = p1.x - p2.x;
            var dy = p1.y - p2.y;
            var d2 = dx * dx + dy * dy;
            if (d2 < nearDistSq) {
              ctx.moveTo(p1.x, p1.y);
              ctx.lineTo(p2.x, p2.y);
            }
          }
        }
        ctx.stroke();

        ctx.strokeStyle = farStroke;
        ctx.beginPath();
        for (var i2 = 0; i2 < items.length; i2++) {
          var q1 = items[i2];
          for (var j2 = i2 + 1; j2 < items.length; j2++) {
            var q2 = items[j2];
            var dx2 = q1.x - q2.x;
            var dy2 = q1.y - q2.y;
            var d22 = dx2 * dx2 + dy2 * dy2;
            if (d22 >= nearDistSq && d22 < maxDistSq) {
              ctx.moveTo(q1.x, q1.y);
              ctx.lineTo(q2.x, q2.y);
            }
          }
        }
        ctx.stroke();
      }
    };

    this._canvasRaf = raf(frame);
  },

  _stopCanvas: function() {
    this._canvasMode = null;
    if (this._canvasRaf) {
      if (window.cancelAnimationFrame) window.cancelAnimationFrame(this._canvasRaf);
      else clearTimeout(this._canvasRaf);
      this._canvasRaf = null;
    }
    if (dom.ambientCanvas) {
      dom.ambientCanvas.style.display = 'none';
    }
  }
};

/* =========================================================
   7. INIT
   ========================================================= */
function init() {
  try {
    var savedTimeout = parseInt(localStorage.getItem('hub_ambient_timeout') || '0', 10) || 0;
    state.ambientTimeoutSec = savedTimeout;
    if (dom.ambientTimeoutSelect) {
      dom.ambientTimeoutSelect.value = String(savedTimeout);
    }
  } catch (e) {}

  UI.renderDeviceTabs();
  UI.startClock();
  UI.initTabletBattery();
  bindEvents();
  Navigation.resetAmbientTimer();
  UI.parseEmojis(document.body);
  MqttLayer.connect();
}
document.addEventListener('DOMContentLoaded', init);
