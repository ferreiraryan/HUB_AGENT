// packages/agent_core/lib/src/services/mqtt_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/agent_event.dart';
import '../models/audio_output_device.dart';
import '../models/audio_state.dart';
import '../models/battery_state.dart';
import '../models/layout.dart';
import '../models/media_state.dart';
import '../models/pomodoro_state.dart';
import '../models/screensaver_config.dart';
import '../models/sound_playback_state.dart';
import '../models/todo_state.dart';
import '../models/weather_state.dart';
import '../util/notifier.dart';
import 'audio/audio_controller.dart';
import 'stats/stats_service.dart';
import 'window/active_window_monitor.dart';

class AgentTopics {
  final String deviceId;
  final String prefix;

  const AgentTopics(this.deviceId, {this.prefix = 'nodes'});

  String get base => '$prefix/$deviceId';
  String get status => '$base/status';
  String get layout => '$base/layout';
  String get volume => '$base/audio/volume';
  String get apps => '$base/audio/apps';
  String get media => '$base/media';
  String get soundState => '$base/sound/state';
  String get pomodoro => '$base/state/pomodoro';
  String get todos => '$base/state/todos';
  String get event => '$base/event';
  String get search => '$base/search';
  String get screensaver => '$base/screensaver';
  String get weather => '$base/weather';
  String get uiScreensaver => '$base/ui/screensaver';
  String get cmd => '$base/cmd';
}

enum AgentConnectionState { disconnected, connecting, connected }

class AgentCommand {
  final String action;
  final Map<String, dynamic> raw;

  const AgentCommand(this.action, this.raw);

  int? get value {
    final v = raw['value'];
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String? get appId => raw['app_id']?.toString();
  String? get shortcutId => raw['id']?.toString();
  String? get sliderId => raw['id']?.toString();
  String? get soundId => raw['sound_id']?.toString() ?? raw['id']?.toString();
  String? get kind => raw['kind']?.toString();
  String? get message => raw['message']?.toString();
  int? get duration {
    final d = raw['duration'];
    if (d is num) return d.round();
    if (d is String) return int.tryParse(d);
    return null;
  }

  static AgentCommand? tryParse(String payload) {
    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic>) return null;
      final action = json['action'];
      if (action is! String || action.isEmpty) return null;
      return AgentCommand(action, json);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'AgentCommand($action, ${jsonEncode(raw)})';
}

class MqttService {
  String _host;
  int _port;
  String _deviceId;
  AgentTopics _topics;
  final String? username;
  final String? password;

  String get host => _host;
  int get port => _port;
  String get deviceId => _deviceId;
  AgentTopics get topics => _topics;

  late MqttServerClient _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;

  final stateNotifier =
      AgentNotifier<AgentConnectionState>(AgentConnectionState.disconnected);
  final _stateChanges = StreamController<AgentConnectionState>.broadcast();
  final _commands = StreamController<AgentCommand>.broadcast();

  Layout? _lastLayout;
  String? _lastLayoutJson;
  final Map<String, String> _lastRetainedPayloads = {};
  bool _intentional = false;
  bool _disposed = false;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  String? _lastError;

  String? get lastError => _lastError;

  MqttService({
    required String host,
    required String deviceId,
    int port = 1883,
    this.username,
    this.password,
    AgentTopics? topics,
  })  : _host = host,
        _port = port,
        _deviceId = deviceId,
        _topics = topics ?? AgentTopics(deviceId) {
    stateNotifier.addListener((v) => _stateChanges.add(v));
    _client = _buildClient();
  }

  MqttServerClient _buildClient() {
    return MqttServerClient.withPort(_host, 'node-$_deviceId', _port)
      ..keepAlivePeriod = 20
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false)
      ..onConnected = _onConnected
      ..onDisconnected = _onDisconnected
      ..onAutoReconnected = _onConnected;
  }

  Stream<AgentConnectionState> get connectionState => _notifierStream();

  Stream<AgentConnectionState> _notifierStream() async* {
    yield stateNotifier.value;
    yield* _stateChanges.stream;
  }

  Stream<AgentCommand> get commands => _commands.stream;

  bool get isConnected =>
      _client.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect() async {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _intentional = false;
    stateNotifier.value = AgentConnectionState.connecting;

    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('node-$_deviceId')
        .withWillTopic(_topics.status)
        .withWillMessage(jsonEncode({'online': false}))
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .startClean();

    try {
      await _client.connect(username, password);
      _lastError = null;
      _retryAttempt = 0;
    } catch (e) {
      _lastError = '$e';
      stderr.writeln('MQTT: falha ao conectar em $_host:$_port -> $e');
      try {
        _client.disconnect();
      } catch (_) {}
      stateNotifier.value = AgentConnectionState.disconnected;
      _scheduleRetry();
      return;
    }

    await _updatesSub?.cancel();
    _updatesSub = _client.updates?.listen(_onMessage);
  }

  void _scheduleRetry() {
    if (_disposed || _intentional) return;
    _retryTimer?.cancel();
    final delays = [2, 4, 8, 15];
    final sec = delays[_retryAttempt.clamp(0, delays.length - 1)];
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: sec), () {
      if (!_disposed && !_intentional && !isConnected) {
        connect();
      }
    });
  }

  /// Força reconexão imediata (usado pelo botão de status ou menu de bandeja).
  Future<void> reconnect() async {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _intentional = true;
    await _updatesSub?.cancel();
    _updatesSub = null;
    try {
      _client.disconnect();
    } catch (_) {}
    _client = _buildClient();
    await connect();
  }

  /// Atualiza host/porta/deviceId em tempo real e reconecta sem reiniciar o app.
  Future<void> reconfigure({
    required String host,
    required int port,
    required String deviceId,
  }) async {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _intentional = true;
    if (isConnected) {
      publishStatus(online: false);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await _updatesSub?.cancel();
    _updatesSub = null;
    try {
      _client.disconnect();
    } catch (_) {}

    _host = host;
    _port = port;
    _deviceId = deviceId;
    _topics = AgentTopics(deviceId);
    _lastRetainedPayloads.clear();
    _client = _buildClient();
    await connect();
  }

  void _onConnected() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _lastError = null;
    _lastRetainedPayloads.clear();
    stateNotifier.value = AgentConnectionState.connected;
    _client.subscribe(_topics.cmd, MqttQos.atLeastOnce);
    publishStatus(online: true);
    final l = _lastLayout;
    if (l != null) publishLayout(l);
  }

  void _onDisconnected() {
    _lastRetainedPayloads.clear();
    stateNotifier.value = AgentConnectionState.disconnected;
    if (!_intentional) {
      stderr.writeln('MQTT: desconectado; autoReconnect assume');
    }
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final e in events) {
      final msg = e.payload;
      if (msg is! MqttPublishMessage) continue;
      final payload =
          MqttPublishPayload.bytesToStringAsString(msg.payload.message);
      final cmd = AgentCommand.tryParse(payload);
      if (cmd != null) {
        _commands.add(cmd);
      } else {
        stderr.writeln('MQTT: payload invalido em ${e.topic}: $payload');
      }
    }
  }

  void publishStatus({required bool online}) {
    _publish(
      topics.status,
      jsonEncode({'online': online, 'os': _osName()}),
      retain: true,
      qos: MqttQos.atLeastOnce,
    );
  }

  void publishLayout(Layout layout, {bool force = false}) {
    final payload = identical(layout, _lastLayout) && _lastLayoutJson != null
        ? _lastLayoutJson!
        : jsonEncode(layout.toPublishJson());
    _lastLayout = layout;
    _lastLayoutJson = payload;
    _publish(topics.layout, payload,
        retain: true, qos: MqttQos.atLeastOnce, force: force);
  }

  void publishVolume(MasterVolume v) {
    _publish(topics.volume, jsonEncode(v.toJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishApps(List<AppVolume> apps) {
    _publish(topics.apps, jsonEncode(apps.map((a) => a.toJson()).toList()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishMedia(MediaState media) {
    _publish(topics.media, jsonEncode(media.toJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishEvent(AgentEvent event) {
    _publish(
      topics.event,
      jsonEncode(event.toJson()),
      retain: false,
      qos: MqttQos.atMostOnce,
    );
  }

  void publishSoundState(SoundPlaybackState soundState) {
    _publish(topics.soundState, jsonEncode(soundState.toJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishSliderState(String sliderId, int value) {
    _publish(
      '${topics.base}/state/$sliderId',
      jsonEncode({'value': value}),
      retain: true,
      qos: MqttQos.atMostOnce,
    );
  }

  void publishToggleState(String toggleId, String stateValue) {
    _publish(
      '${topics.base}/state/$toggleId',
      jsonEncode({'value': stateValue}),
      retain: true,
      qos: MqttQos.atMostOnce,
    );
  }

  void publishPomodoroState(PomodoroState pomodoro) {
    _publish(
      topics.pomodoro,
      jsonEncode(pomodoro.toJson()),
      retain: true,
      qos: MqttQos.atMostOnce,
    );
  }

  void publishTodoState(TodoState todo) {
    _publish(
      topics.todos,
      jsonEncode(todo.toJson()),
      retain: true,
      qos: MqttQos.atMostOnce,
    );
  }

  void publishStatsCpu(StatsSnapshot s) {
    _publish('${topics.base}/stats/cpu', jsonEncode(s.cpuJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishStatsRam(StatsSnapshot s) {
    _publish('${topics.base}/stats/ram', jsonEncode(s.ramJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishStatsDisk(StatsSnapshot s) {
    _publish('${topics.base}/stats/disk', jsonEncode(s.diskJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishStatsNet(StatsSnapshot s) {
    if (s.netRxKbps == null && s.netTxKbps == null) return;
    _publish('${topics.base}/stats/net', jsonEncode(s.netJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishStatsGpu(StatsSnapshot s) {
    if (s.gpuLoad == null && s.gpuTemp == null) return;
    _publish('${topics.base}/stats/gpu', jsonEncode(s.gpuJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishBatteries(BatterySnapshot snap) {
    _publish('${topics.base}/stats/batteries', jsonEncode(snap.toJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishMicState(MicState mic) {
    _publish('${topics.base}/audio/mic', jsonEncode(mic.toJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishAudioOutputs(List<AudioOutputDevice> devices) {
    _publish(
      '${topics.base}/audio/outputs',
      jsonEncode({
        'devices': devices
            .map((d) => {'id': d.id, 'name': d.name, 'is_default': d.isDefault})
            .toList(),
      }),
      retain: true,
      qos: MqttQos.atMostOnce,
    );
  }

  void publishActiveApp(ActiveWindowInfo info) {
    _publish('${topics.base}/active_app', jsonEncode(info.toJson()),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishPageRules(Map<String, List<String>> rules) {
    _publish('${topics.base}/page_rules', jsonEncode(rules),
        retain: true, qos: MqttQos.atMostOnce);
  }

  void publishClipboard(String text) {
    _publish(
      '${topics.base}/clipboard',
      jsonEncode({
        'text': text,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
      retain: false,
      qos: MqttQos.atMostOnce,
    );
  }

  void publishSearchQuery(
    String query, {
    bool active = true,
    String filter = 'all',
    String scope = 'all',
  }) {
    _publish(
      topics.search,
      jsonEncode({
        'query': query,
        'active': active,
        'filter': filter,
        'scope': scope,
      }),
      retain: false,
      qos: MqttQos.atMostOnce,
    );
  }

  void publishScreensaverConfig(ScreensaverConfig config) {
    _publish(
      topics.screensaver,
      jsonEncode(config.toJson()),
      retain: true,
      qos: MqttQos.atLeastOnce,
    );
  }

  void publishWeather(WeatherState weather) {
    _publish(
      topics.weather,
      jsonEncode(weather.toJson()),
      retain: true,
      qos: MqttQos.atMostOnce,
    );
  }

  void publishScreensaverCommand(String action) {
    _publish(
      topics.uiScreensaver,
      jsonEncode({
        'action': action,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
      retain: false,
      qos: MqttQos.atMostOnce,
    );
  }

  void clearRetained() {
    _lastRetainedPayloads.clear();
    for (final t in [
      topics.status,
      topics.layout,
      topics.volume,
      topics.apps,
      topics.media,
      topics.soundState,
      topics.pomodoro,
      topics.todos,
      '${topics.base}/stats/cpu',
      '${topics.base}/stats/ram',
      '${topics.base}/stats/disk',
    ]) {
      _publish(t, '', retain: true, qos: MqttQos.atLeastOnce, force: true);
    }
  }

  /// Verifica se um payload retido precisa realmente ser enviado (deduplicação por tópico).
  bool shouldPublishRetained(String topic, String payload, {bool force = false}) {
    if (!force && _lastRetainedPayloads[topic] == payload) {
      return false;
    }
    _lastRetainedPayloads[topic] = payload;
    return true;
  }

  /// Limpa o cache de deduplicação (útil em testes ou reconexão forçada).
  void clearPublishCache() => _lastRetainedPayloads.clear();

  void _publish(String topic, String payload,
      {required bool retain, required MqttQos qos, bool force = false}) {
    if (!isConnected) return;
    if (retain && !shouldPublishRetained(topic, payload, force: force)) {
      return;
    }
    final b = MqttClientPayloadBuilder();
    if (payload.isNotEmpty) b.addUTF8String(payload);
    _client.publishMessage(topic, qos, b.payload!, retain: retain);
  }

  static String _osName() {
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }

  Future<void> dispose() async {
    _disposed = true;
    _intentional = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _updatesSub?.cancel();
    _updatesSub = null;
    if (isConnected) {
      publishStatus(online: false);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    try {
      _client.disconnect();
    } catch (_) {}
    await _stateChanges.close();
    await _commands.close();
  }
}
