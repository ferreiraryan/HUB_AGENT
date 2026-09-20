import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models/audio_state.dart';
import '../models/layout.dart';
import '../models/media_state.dart';

/// Topicos canonicos: prefixo `nodes/{deviceId}`.
///
/// O tablet assina com wildcard (`nodes/+/status`), entao o auto-discovery
/// depende so de o deviceId ser unico na rede.
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

/// Mensagem publicada pelo tablet em `nodes/{deviceId}/cmd`.
///
/// `{ "action": string, "value"?: number, "app_id"?: string }`
class AgentCommand {
  final String action;
  final Map<String, dynamic> raw;

  const AgentCommand(this.action, this.raw);

  /// 0-100 int. Aceita float vindo do tablet por tolerancia, mas arredonda.
  int? get value {
    final v = raw['value'];
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String? get appId => raw['app_id']?.toString();

  /// Usado pela acao `run_shortcut`, onde o id vem em campo separado.
  String? get shortcutId => raw['id']?.toString();

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

/// Conexao MQTT do node. Nao conhece UI nem disco.
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
        // LWT: queda de energia e o broker publica isso sozinho. O tablet
        // apaga o card do PC sem precisar de timeout proprio.
        .withWillTopic(topics.status)
        .withWillMessage(jsonEncode({'online': false}))
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .startClean();

    try {
      await _client.connect(username, password);
    } catch (e) {
      stderr.writeln('MQTT: falha ao conectar em $host:$port -> $e');
      _client.disconnect();
      _state.add(AgentConnectionState.disconnected);
      return;
    }

    _client.updates?.listen(_onMessage);
  }

  void _onConnected() {
    _state.add(AgentConnectionState.connected);
    _client.subscribe(topics.cmd, MqttQos.atLeastOnce);
    // Reconectou: o retained do broker pode estar velho se editamos offline.
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
        stderr.writeln('MQTT: payload invalido em ${e.topic}: $payload');
      }
    }
  }

  // ------------------------------------------------------------ publicacao

  /// `{ online: true, os: "linux" }`
  void publishStatus({required bool online}) {
    _publish(
      topics.status,
      jsonEncode({'online': online, 'os': _osName()}),
      retain: true,
      qos: MqttQos.atLeastOnce,
    );
  }

  /// A regra de ouro: retain true, e SEMPRE [Layout.toPublishJson].
  /// Publicar toDiskJson vazaria os bindings (argv de shell) para a rede.
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

  /// Apaga os retained deste node. Chame ao trocar o deviceId ou desinstalar,
  /// senao o tablet mostra um PC fantasma para sempre.
  void clearRetained() {
    for (final t in [
      topics.status,
      topics.layout,
      topics.volume,
      topics.apps,
      topics.media,
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

  /// Saida limpa: publica offline sem depender do LWT.
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
