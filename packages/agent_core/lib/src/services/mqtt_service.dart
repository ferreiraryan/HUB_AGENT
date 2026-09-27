import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/audio_state.dart';
import '../models/layout.dart';
import '../models/media_state.dart';
import 'stats/stats_service.dart';

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
  String toString() => 'AgentCommand($action,${jsonEncode(raw)})';
}

class MqttService {
  final String host;
  final int port;
  final String deviceId;
  final AgentTopics topics;
  final String? username;
  final String? password;

  late final MqttServerClient _client;

  final _state = StreamController<AgentConnectionState>.broadcast();
  final _commands = StreamController<AgentCommand>.broadcast();

  Layout? _lastLayout;
  bool _intentional = false;

  MqttService({
    required this.host,
    required this.deviceId,
    this.port = 1883,
    this.username,
    this.password,
    AgentTopics? topics,
  }) : topics = topics ?? AgentTopics(deviceId) {
    _client = MqttServerClient.withPort(host, 'node-$deviceId', port)
      ..keepAlivePeriod = 20
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false)
      ..onConnected = _onConnected
      ..onDisconnected = _onDisconnected
      ..onAutoReconnected = _onConnected;
  }

  Stream<AgentConnectionState> get connectionState => _state.stream;
  Stream<AgentCommand> get commands => _commands.stream;
  bool get isConnected =>
      _client.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect() async {
    _intentional = false;
    _state.add(AgentConnectionState.connecting);

    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('node-$deviceId')
        .withWillTopic(topics.status)
        .withWillMessage(jsonEncode({'online': false}))
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .startClean();

    try {
      await _client.connect(username, password);
    } catch (e) {
      stderr.writeln('MQTT: falha ao conectar em $host:$port ->$e');
      _client.disconnect();
      _state.add(AgentConnectionState.disconnected);
      return;
    }

    _client.updates?.listen(_onMessage);
  }

  void _onConnected() {
    _state.add(AgentConnectionState.connected);
    _client.subscribe(topics.cmd, MqttQos.atLeastOnce);
    final l = _lastLayout;
    if (l != null) publishLayout(l);
  }

  void _onDisconnected() {
    _state.add(AgentConnectionState.disconnected);
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
        stderr.writeln('MQTT: payload invalido em ${e.topic}:$payload');
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

  void publishLayout(Layout layout) {
    _lastLayout = layout;
    _publish(topics.layout, jsonEncode(layout.toPublishJson()),
        retain: true, qos: MqttQos.atLeastOnce);
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

  void publishSliderState(String sliderId, int value) {
    _publish(
      '${topics.base}/state/$sliderId',
      jsonEncode({'value': value}),
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

  void clearRetained() {
    for (final t in [
      topics.status,
      topics.layout,
      topics.volume,
      topics.apps,
      topics.media,
      '${topics.base}/stats/cpu',
      '${topics.base}/stats/ram',
      '${topics.base}/stats/disk',
    ]) {
      _publish(t, '', retain: true, qos: MqttQos.atLeastOnce);
    }
  }

  void _publish(String topic, String payload,
      {required bool retain, required MqttQos qos}) {
    if (!isConnected) return;
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
    _intentional = true;
    if (isConnected) {
      publishStatus(online: false);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    _client.disconnect();
    await _state.close();
    await _commands.close();
  }
}
