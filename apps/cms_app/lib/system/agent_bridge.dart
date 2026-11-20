import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';

import 'global_hotkey_service.dart';

/// Abstração única consumida pela UI do `cms_app`.
///
/// Possui duas implementações:
/// - [DaemonAgentBridge]: conecta ao `hub_agent_daemon` via IPC loopback
///   (zero MQTT, zero monitors de hardware no processo Flutter; ao fechar a
///   janela, o Flutter encerra com `exit(0)` liberando 100% da RAM gráfica).
/// - [InProcessAgentBridge]: encapsula um [AgentRuntime] local (usado em modo
///   `--standalone` e em testes de widget).
abstract interface class AgentBridge {
  bool get isDaemonMode;
  AgentConfig get currentConfig;
  String get mqttHost;
  int get mqttPort;
  String get mqttDeviceId;

  Stream<AgentConnectionState> get connectionState;

  bool get isLayoutLoaded;
  Layout get currentLayout;
  Stream<Layout> get layoutChanges;
  void saveLayout(Layout layout);
  Future<void> flushLayout({bool forcePublish = false});

  ScreensaverConfig get currentScreensaver;
  void updateScreensaver(ScreensaverConfig config);
  Future<void> flushScreensaver();
  Future<void> previewScreensaverOnTablet();

  WeatherState? get currentWeather;
  Stream<WeatherState> get weatherUpdates;
  Future<WeatherState?> configureWeather({required String city, String? unit});

  Map<String, List<String>> get pageRules;
  Future<void> setPageTriggers(String pageId, List<String> processes);

  List<AppVolume> get audioApps;
  Stream<List<AppVolume>> get audioAppsChanges;
  Future<void> refreshAudioApps();
  Future<void> setAppVolumeByName(String match, int value);

  SoundPlaybackState get soundState;
  Stream<SoundPlaybackState> get soundStateChanges;
  Future<List<AudioOutputDevice>> listSoundDevices();
  Future<void> playSound(String soundId, {String? targetDevice});
  Future<void> stopSound();
  Future<void> playTestSound({String? targetDevice});
  Future<void> setSoundTargetDevice(String? device);
  Future<void> invalidateSoundCache();

  Future<void> dispatchCommand(AgentCommand cmd);
  Future<void> triggerAction(String action);
  Future<List<CommandResult>> testCommandChain(List<List<String>> cmds);
  Future<CommandResult> testCommand(List<String> argv);
  Future<bool> commandExists(String binary);
  Future<bool> sendKeyCombo(String combo);

  Future<void> setOsdConfig({bool? enabled, String? position});
  Future<void> testOsd({String? position});

  Future<void> addTodoItem(String text);
  Future<void> publishSearchQuery(
    String query, {
    bool active = true,
    String filter = 'all',
    String scope = 'all',
  });

  Future<void> reconnectMqtt();
  Future<void> saveConfigAndApply(
    AgentConfig updated, {
    required bool reconnectNow,
  });

  String get hotkeyCombo;
  GlobalHotkeyStatus get hotkeyStatus;
  Future<GlobalHotkeyStatus> updateHotkey(String combo);

  Stream<void> get remoteSearchPrompts;
  Stream<void> get remoteTodoPrompts;
  Stream<void> get focusRequests;

  Future<void> dispose();
}

/// Implementação embarcada (modo `--standalone` e testes de widget).
class InProcessAgentBridge implements AgentBridge {
  final AgentRuntime runtime;
  final Directory? supportDir;
  AgentConfig _config;
  final _focusCtl = StreamController<void>.broadcast();

  InProcessAgentBridge({
    required this.runtime,
    required AgentConfig config,
    this.supportDir,
  }) : _config = config;

  @override
  bool get isDaemonMode => false;
  @override
  AgentConfig get currentConfig => _config;
  @override
  String get mqttHost => runtime.mqtt.host;
  @override
  int get mqttPort => runtime.mqtt.port;
  @override
  String get mqttDeviceId => runtime.mqtt.deviceId;

  @override
  Stream<AgentConnectionState> get connectionState => runtime.connectionState;

  @override
  bool get isLayoutLoaded => runtime.repository.isLoaded;
  @override
  Layout get currentLayout => runtime.repository.current;
  @override
  Stream<Layout> get layoutChanges => runtime.layoutChanges;

  @override
  void saveLayout(Layout layout) => runtime.repository.save(layout);

  @override
  Future<void> flushLayout({bool forcePublish = false}) async {
    await runtime.repository.flush();
    if (forcePublish && runtime.repository.isLoaded) {
      runtime.mqtt.publishLayout(runtime.repository.current, force: true);
    }
  }

  @override
  ScreensaverConfig get currentScreensaver => runtime.screensaver.current;
  @override
  void updateScreensaver(ScreensaverConfig config) =>
      runtime.screensaver.update(config);
  @override
  Future<void> flushScreensaver() => runtime.screensaver.flush();
  @override
  Future<void> previewScreensaverOnTablet() async {
    await runtime.screensaver.flush();
    runtime.mqtt.publishScreensaverCommand('open');
  }

  @override
  WeatherState? get currentWeather => runtime.weather.current;
  @override
  Stream<WeatherState> get weatherUpdates => runtime.weather.updates;
  @override
  Future<WeatherState?> configureWeather({
    required String city,
    String? unit,
  }) =>
      runtime.weather.configure(city: city, unit: unit);

  @override
  Map<String, List<String>> get pageRules => runtime.pageRules.current;
  @override
  Future<void> setPageTriggers(String pageId, List<String> processes) =>
      runtime.pageRules.setTriggersForPage(pageId, processes);

  @override
  List<AppVolume> get audioApps => runtime.audio.apps;
  @override
  Stream<List<AppVolume>> get audioAppsChanges => runtime.appVolumeChanges;
  @override
  Future<void> refreshAudioApps() => runtime.audio.refresh();
  @override
  Future<void> setAppVolumeByName(String match, int value) =>
      runtime.audio.setAppVolumeByName(match, value);

  @override
  SoundPlaybackState get soundState =>
      runtime.sound?.current ?? SoundPlaybackState.idle;
  @override
  Stream<SoundPlaybackState> get soundStateChanges =>
      runtime.sound?.stateChanges ?? const Stream.empty();
  @override
  Future<List<AudioOutputDevice>> listSoundDevices() =>
      runtime.sound?.listDevices() ?? Future.value(const []);
  @override
  Future<void> playSound(String soundId, {String? targetDevice}) async {
    await runtime.sound?.play(soundId, targetDevice: targetDevice);
  }

  @override
  Future<void> stopSound() async => runtime.sound?.stop();
  @override
  Future<void> playTestSound({String? targetDevice}) async =>
      runtime.sound?.playTestSound(targetDevice: targetDevice);
  @override
  Future<void> setSoundTargetDevice(String? device) async {
    runtime.sound?.targetDevice = device;
  }

  @override
  Future<void> invalidateSoundCache() async {
    runtime.dispatcher.invalidateSoundCache();
  }

  @override
  Future<void> dispatchCommand(AgentCommand cmd) =>
      runtime.dispatcher.dispatch(cmd);
  @override
  Future<void> triggerAction(String action) => runtime.triggerAction(action);
  @override
  Future<List<CommandResult>> testCommandChain(List<List<String>> cmds) =>
      runtime.dispatcher.testChain(cmds);
  @override
  Future<CommandResult> testCommand(List<String> argv) =>
      runtime.dispatcher.test(argv);
  @override
  Future<bool> commandExists(String binary) =>
      runtime.dispatcher.exists(binary);
  @override
  Future<bool> sendKeyCombo(String combo) =>
      runtime.dispatcher.keySender.send(combo);

  @override
  Future<void> setOsdConfig({bool? enabled, String? position}) async {
    runtime.osd.setConfig(enabled: enabled, position: position);
  }

  @override
  Future<void> testOsd({String? position}) async {
    runtime.osd.setConfig(enabled: true, position: position);
    await runtime.osd.showSlider(
      title: 'Hub Agent OSD',
      value: 74,
      icon: 'volume',
    );
  }

  @override
  Future<void> addTodoItem(String text) => runtime.todo.addItem(text);

  @override
  Future<void> publishSearchQuery(
    String query, {
    bool active = true,
    String filter = 'all',
    String scope = 'all',
  }) async =>
      runtime.publishSearchQuery(
        query,
        active: active,
        filter: filter,
        scope: scope,
      );

  @override
  Future<void> reconnectMqtt() => runtime.reconnectMqtt();

  @override
  Future<void> saveConfigAndApply(
    AgentConfig updated, {
    required bool reconnectNow,
  }) async {
    final brokerChanged = updated.host != runtime.mqtt.host ||
        updated.port != runtime.mqtt.port ||
        updated.deviceId != runtime.mqtt.deviceId;
    _config = updated;
    await updated.save(supportDir: supportDir);
    runtime.sound?.targetDevice = updated.soundOutputDevice;
    runtime.osd.setConfig(
      enabled: updated.osdEnabled,
      position: updated.osdPosition,
    );
    await GlobalHotkeyService.instance.updateHotkey(updated.searchHotkey);
    if (reconnectNow || brokerChanged) {
      await runtime.reconfigureMqtt(
        host: updated.host,
        port: updated.port,
        deviceId: updated.deviceId,
      );
    }
  }

  @override
  String get hotkeyCombo => GlobalHotkeyService.instance.currentCombo;
  @override
  GlobalHotkeyStatus get hotkeyStatus => GlobalHotkeyService.instance.status;
  @override
  Future<GlobalHotkeyStatus> updateHotkey(String combo) =>
      GlobalHotkeyService.instance.updateHotkey(combo);

  @override
  Stream<void> get remoteSearchPrompts => runtime.remoteSearchPrompts;
  @override
  Stream<void> get remoteTodoPrompts => runtime.remoteTodoPrompts;
  @override
  Stream<void> get focusRequests => _focusCtl.stream;

  @override
  Future<void> dispose() async {
    await _focusCtl.close();
  }
}

/// Implementação cliente IPC conectada ao `hub_agent_daemon` (Fase 4).
class DaemonAgentBridge implements AgentBridge {
  final DaemonIpcClient client;
  AgentConfig _config;
  AgentConnectionState _connState;
  Layout _layout;
  ScreensaverConfig _screensaver;
  WeatherState? _weather;
  Map<String, List<String>> _pageRules;
  List<AppVolume> _audioApps;
  SoundPlaybackState _soundState;
  String _hotkeyCombo;
  GlobalHotkeyStatus _hotkeyStatus;

  final _connCtl = StreamController<AgentConnectionState>.broadcast();
  final _layoutCtl = StreamController<Layout>.broadcast();
  final _weatherCtl = StreamController<WeatherState>.broadcast();
  final _appsCtl = StreamController<List<AppVolume>>.broadcast();
  final _soundCtl = StreamController<SoundPlaybackState>.broadcast();
  final _searchPromptCtl = StreamController<void>.broadcast();
  final _todoPromptCtl = StreamController<void>.broadcast();
  final _focusCtl = StreamController<void>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _eventsSub;
  Future<void> _saveQueue = Future.value();

  DaemonAgentBridge._({
    required this.client,
    required AgentConfig config,
    required AgentConnectionState connState,
    required Layout layout,
    required ScreensaverConfig screensaver,
    required WeatherState? weather,
    required Map<String, List<String>> pageRules,
    required List<AppVolume> audioApps,
    required SoundPlaybackState soundState,
    required String hotkeyCombo,
    required GlobalHotkeyStatus hotkeyStatus,
  })  : _config = config,
        _connState = connState,
        _layout = layout,
        _screensaver = screensaver,
        _weather = weather,
        _pageRules = pageRules,
        _audioApps = audioApps,
        _soundState = soundState,
        _hotkeyCombo = hotkeyCombo,
        _hotkeyStatus = hotkeyStatus {
    _eventsSub = client.events.listen(_handleEvent);
  }

  static Future<DaemonAgentBridge?> connect(DaemonIpcClient client) async {
    final snap = await client.get('/v1/state');
    if (snap == null || snap['ok'] != true) return null;

    await client.connectEvents();

    final cfgMap = snap['config'] is Map
        ? (snap['config'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final cfg = AgentConfig.fromJson(cfgMap);

    final layoutMap = snap['layout'] is Map
        ? (snap['layout'] as Map).cast<String, dynamic>()
        : null;
    final layout =
        layoutMap != null ? Layout.fromJson(layoutMap) : Layout.initial(cfg.deviceId);

    final ssMap = snap['screensaver'] is Map
        ? (snap['screensaver'] as Map).cast<String, dynamic>()
        : null;
    final ss = ssMap != null
        ? ScreensaverConfig.fromJson(ssMap)
        : ScreensaverPresets.auroraDesk();

    final wMap = snap['weather'] is Map
        ? (snap['weather'] as Map).cast<String, dynamic>()
        : null;
    final weather = wMap != null ? _parseWeather(wMap) : null;

    final rules = _parsePageRules(snap['page_rules']);
    final apps = _parseApps(snap['audio_apps']);
    final soundState = snap['sound_state'] is Map
        ? SoundPlaybackState.fromJson(
            (snap['sound_state'] as Map).cast<String, dynamic>(),
          )
        : SoundPlaybackState.idle;

    return DaemonAgentBridge._(
      client: client,
      config: cfg,
      connState: _parseConn(snap['connection_state']?.toString()),
      layout: layout,
      screensaver: ss,
      weather: weather,
      pageRules: rules,
      audioApps: apps,
      soundState: soundState,
      hotkeyCombo: snap['hotkey_combo']?.toString() ?? cfg.searchHotkey,
      hotkeyStatus: GlobalHotkeyStatus.parse(snap['hotkey_status']?.toString()),
    );
  }

  static AgentConnectionState _parseConn(String? raw) => switch (raw) {
        'connected' => AgentConnectionState.connected,
        'connecting' => AgentConnectionState.connecting,
        _ => AgentConnectionState.disconnected,
      };

  static Map<String, List<String>> _parsePageRules(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, List<String>>{};
    for (final e in raw.entries) {
      if (e.value is List) {
        out[e.key.toString()] =
            (e.value as List).map((x) => x.toString()).toList();
      }
    }
    return Map.unmodifiable(out);
  }

  static List<AppVolume> _parseApps(Object? raw) {
    if (raw is! List) return const [];
    final out = <AppVolume>[];
    for (final item in raw) {
      if (item is Map) {
        final id = item['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          out.add(AppVolume(
            id: id,
            name: item['name']?.toString() ?? id,
            volume: (item['volume'] as num?)?.toInt() ?? 0,
          ));
        }
      }
    }
    return List.unmodifiable(out);
  }

  static WeatherState? _parseWeather(Map<String, dynamic> j) {
    final temp = (j['temp'] as num?)?.toDouble();
    if (temp == null) return null;
    final fc = <WeatherForecastDay>[];
    if (j['forecast'] is List) {
      for (final item in j['forecast'] as List) {
        if (item is Map) {
          fc.add(WeatherForecastDay(
            day: item['day']?.toString() ?? '',
            minTemp: (item['min'] as num?)?.toDouble() ?? temp,
            maxTemp: (item['max'] as num?)?.toDouble() ?? temp,
            icon: item['icon']?.toString() ?? 'cloudy',
          ));
        }
      }
    }
    return WeatherState(
      city: j['city']?.toString() ?? '',
      unit: j['unit']?.toString() ?? 'C',
      temp: temp,
      feelsLike: (j['feels_like'] as num?)?.toDouble() ?? temp,
      minTemp: (j['min'] as num?)?.toDouble() ?? temp,
      maxTemp: (j['max'] as num?)?.toDouble() ?? temp,
      humidity: (j['humidity'] as num?)?.toInt() ?? 0,
      windKmh: (j['wind_kmh'] as num?)?.toDouble() ?? 0,
      condition: j['condition']?.toString() ?? '',
      icon: j['icon']?.toString() ?? 'cloudy',
      isDay: j['is_day'] as bool? ?? true,
      forecast: fc,
      updatedAtMs: (j['updated_at'] as num?)?.toInt() ?? 0,
    );
  }

  void _handleEvent(Map<String, dynamic> msg) {
    final ev = msg['event']?.toString();
    switch (ev) {
      case 'connection_state':
        final next = _parseConn(msg['state']?.toString());
        if (next != _connState) {
          _connState = next;
          if (!_connCtl.isClosed) _connCtl.add(next);
        }
      case 'layout_changed':
        if (msg['layout'] is Map) {
          try {
            final next =
                Layout.fromJson((msg['layout'] as Map).cast<String, dynamic>());
            if (next != _layout) {
              _layout = next;
              if (!_layoutCtl.isClosed) _layoutCtl.add(next);
            }
          } catch (_) {}
        }
      case 'audio_apps':
        _audioApps = _parseApps(msg['apps']);
        if (!_appsCtl.isClosed) _appsCtl.add(_audioApps);
      case 'sound_state':
        if (msg['state'] is Map) {
          _soundState = SoundPlaybackState.fromJson(
            (msg['state'] as Map).cast<String, dynamic>(),
          );
          if (!_soundCtl.isClosed) _soundCtl.add(_soundState);
        }
      case 'weather_updated':
        if (msg['weather'] is Map) {
          final w = _parseWeather((msg['weather'] as Map).cast<String, dynamic>());
          if (w != null) {
            _weather = w;
            if (!_weatherCtl.isClosed) _weatherCtl.add(w);
          }
        }
      case 'page_rules_changed':
        _pageRules = _parsePageRules(msg['rules']);
      case 'open_search':
        if (!_searchPromptCtl.isClosed) _searchPromptCtl.add(null);
      case 'open_todo':
        if (!_todoPromptCtl.isClosed) _todoPromptCtl.add(null);
      case 'focus':
        if (!_focusCtl.isClosed) _focusCtl.add(null);
    }
  }

  @override
  bool get isDaemonMode => true;
  @override
  AgentConfig get currentConfig => _config;
  @override
  String get mqttHost => _config.host;
  @override
  int get mqttPort => _config.port;
  @override
  String get mqttDeviceId => _config.deviceId;

  @override
  Stream<AgentConnectionState> get connectionState async* {
    yield _connState;
    yield* _connCtl.stream;
  }

  @override
  bool get isLayoutLoaded => true;
  @override
  Layout get currentLayout => _layout;
  @override
  Stream<Layout> get layoutChanges => _layoutCtl.stream;

  @override
  void saveLayout(Layout layout) {
    _layout = layout;
    _saveQueue = _saveQueue.then((_) async {
      await client.put('/v1/layout', body: {'layout': layout.toDiskJson()});
    });
  }

  @override
  Future<void> flushLayout({bool forcePublish = false}) async {
    await _saveQueue;
    await client.put(
      '/v1/layout',
      body: {'layout': _layout.toDiskJson(), 'force': forcePublish},
    );
    if (forcePublish) {
      await client.post('/v1/layout/flush');
    }
  }

  @override
  ScreensaverConfig get currentScreensaver => _screensaver;
  @override
  void updateScreensaver(ScreensaverConfig config) {
    _screensaver = config;
    unawaited(client.put('/v1/screensaver', body: {'config': config.toJson()}));
  }

  @override
  Future<void> flushScreensaver() async {
    await client.put('/v1/screensaver', body: {'config': _screensaver.toJson()});
    await client.post('/v1/screensaver/flush');
  }

  @override
  Future<void> previewScreensaverOnTablet() async {
    await client.put('/v1/screensaver', body: {'config': _screensaver.toJson()});
    await client.post('/v1/screensaver/preview');
  }

  @override
  WeatherState? get currentWeather => _weather;
  @override
  Stream<WeatherState> get weatherUpdates => _weatherCtl.stream;
  @override
  Future<WeatherState?> configureWeather({
    required String city,
    String? unit,
  }) async {
    final res = await client.post(
      '/v1/weather/configure',
      body: {'city': city, if (unit != null) 'unit': unit},
      timeout: const Duration(seconds: 10),
    );
    if (res?['weather'] is Map) {
      final w = _parseWeather((res!['weather'] as Map).cast<String, dynamic>());
      if (w != null) _weather = w;
      return w;
    }
    return null;
  }

  @override
  Map<String, List<String>> get pageRules => _pageRules;
  @override
  Future<void> setPageTriggers(String pageId, List<String> processes) async {
    final res = await client.put(
      '/v1/page-rules',
      body: {'page_id': pageId, 'processes': processes},
    );
    if (res?['rules'] is Map) {
      _pageRules = _parsePageRules(res!['rules']);
    }
  }

  @override
  List<AppVolume> get audioApps => _audioApps;
  @override
  Stream<List<AppVolume>> get audioAppsChanges => _appsCtl.stream;
  @override
  Future<void> refreshAudioApps() async {
    final res = await client.post('/v1/audio/refresh');
    if (res?['apps'] is List) {
      _audioApps = _parseApps(res!['apps']);
      if (!_appsCtl.isClosed) _appsCtl.add(_audioApps);
    }
  }

  @override
  Future<void> setAppVolumeByName(String match, int value) async {
    await client.post('/v1/audio/app-volume', body: {
      'match': match,
      'value': value,
    });
  }

  @override
  SoundPlaybackState get soundState => _soundState;
  @override
  Stream<SoundPlaybackState> get soundStateChanges => _soundCtl.stream;

  @override
  Future<List<AudioOutputDevice>> listSoundDevices() async {
    final res = await client.get('/v1/sound/devices');
    final raw = res?['devices'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => AudioOutputDevice.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> playSound(String soundId, {String? targetDevice}) async {
    await client.post('/v1/sound/play', body: {
      'sound_id': soundId,
      if (targetDevice != null) 'target_device': targetDevice,
    });
  }

  @override
  Future<void> stopSound() async {
    await client.post('/v1/sound/stop');
  }

  @override
  Future<void> playTestSound({String? targetDevice}) async {
    await client.post('/v1/sound/test', body: {
      if (targetDevice != null) 'target_device': targetDevice,
    });
  }

  @override
  Future<void> setSoundTargetDevice(String? device) async {
    await client.put('/v1/sound/device', body: {'device': device ?? ''});
  }

  @override
  Future<void> invalidateSoundCache() async {
    await client.post('/v1/sound/invalidate-cache');
  }

  @override
  Future<void> dispatchCommand(AgentCommand cmd) async {
    await client.post('/v1/actions/dispatch', body: cmd.raw);
  }

  @override
  Future<void> triggerAction(String action) =>
      dispatchCommand(AgentCommand(action, {'action': action}));

  @override
  Future<List<CommandResult>> testCommandChain(List<List<String>> cmds) async {
    final res = await client.post(
      '/v1/actions/test-chain',
      body: {'cmds': cmds},
      timeout: const Duration(seconds: 30),
    );
    final raw = res?['results'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => CommandResult(
              started: m['started'] == true,
              exitCode: (m['exit_code'] as num?)?.toInt() ?? -1,
              stdout: m['stdout']?.toString() ?? '',
              stderr: m['stderr']?.toString() ?? '',
              error: m['error']?.toString(),
            ))
        .toList();
  }

  @override
  Future<CommandResult> testCommand(List<String> argv) async {
    final results = await testCommandChain([argv]);
    if (results.isEmpty) {
      return const CommandResult(
        started: false,
        error: 'Sem resposta do daemon',
      );
    }
    return results.first;
  }

  @override
  Future<bool> commandExists(String binary) async {
    final res = await client.post('/v1/actions/exists', body: {'binary': binary});
    return res?['exists'] == true;
  }

  @override
  Future<bool> sendKeyCombo(String combo) async {
    final res =
        await client.post('/v1/actions/send-keys', body: {'combo': combo});
    return res?['sent'] == true;
  }

  @override
  Future<void> setOsdConfig({bool? enabled, String? position}) async {
    await client.post('/v1/osd/config', body: {
      if (enabled != null) 'enabled': enabled,
      if (position != null) 'position': position,
    });
  }

  @override
  Future<void> testOsd({String? position}) async {
    await client.post('/v1/osd/test', body: {
      if (position != null) 'position': position,
    });
  }

  @override
  Future<void> addTodoItem(String text) async {
    await client.post('/v1/todo/add', body: {'text': text});
  }

  @override
  Future<void> publishSearchQuery(
    String query, {
    bool active = true,
    String filter = 'all',
    String scope = 'all',
  }) async {
    await client.post('/v1/search/query', body: {
      'query': query,
      'active': active,
      'filter': filter,
      'scope': scope,
    });
  }

  @override
  Future<void> reconnectMqtt() async {
    await client.post('/v1/mqtt/reconnect');
  }

  @override
  Future<void> saveConfigAndApply(
    AgentConfig updated, {
    required bool reconnectNow,
  }) async {
    _config = updated;
    await client.put('/v1/config', body: {
      'config': updated.toJson(),
      'reconnect': reconnectNow,
    });
  }

  @override
  String get hotkeyCombo => _hotkeyCombo;
  @override
  GlobalHotkeyStatus get hotkeyStatus => _hotkeyStatus;

  @override
  Future<GlobalHotkeyStatus> updateHotkey(String combo) async {
    _hotkeyCombo = combo.trim().toLowerCase();
    final res = await client.put('/v1/hotkey', body: {'combo': _hotkeyCombo});
    _hotkeyStatus = GlobalHotkeyStatus.parse(res?['status']?.toString());
    return _hotkeyStatus;
  }

  @override
  Stream<void> get remoteSearchPrompts => _searchPromptCtl.stream;
  @override
  Stream<void> get remoteTodoPrompts => _todoPromptCtl.stream;
  @override
  Stream<void> get focusRequests => _focusCtl.stream;

  @override
  Future<void> dispose() async {
    await _saveQueue;
    await _eventsSub?.cancel();
    await client.dispose();
    await _connCtl.close();
    await _layoutCtl.close();
    await _weatherCtl.close();
    await _appsCtl.close();
    await _soundCtl.close();
    await _searchPromptCtl.close();
    await _todoPromptCtl.close();
    await _focusCtl.close();
  }
}
