import 'dart:convert';
import 'dart:io';
import 'package:agent_core/agent_core.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main(List<String> args) async {
  String? host;
  int? port;
  String? deviceId;
  String kindStr = 'info';
  String message = 'Notificação de teste';
  int duration = 3000;

  // Tenta ler configuracao real do CMS em AppData
  final appData = Platform.environment['APPDATA'];
  if (appData != null) {
    final configFile = File('$appData/com.example/cms_app/agent_config.json');
    if (configFile.existsSync()) {
      try {
        final json = jsonDecode(configFile.readAsStringSync());
        if (json is Map<String, dynamic>) {
          host = json['host'] as String?;
          port = json['port'] as int?;
          deviceId = json['deviceId'] as String?;
        }
      } catch (_) {}
    }
  }

  host ??= '192.168.100.244';
  port ??= 1883;
  deviceId ??= 'windows-pc';

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--host' && i + 1 < args.length) host = args[++i];
    if (args[i] == '--port' && i + 1 < args.length) port = int.tryParse(args[++i]) ?? port;
    if (args[i] == '--device' && i + 1 < args.length) deviceId = args[++i];
    if (args[i] == '--kind' && i + 1 < args.length) kindStr = args[++i];
    if (args[i] == '--message' && i + 1 < args.length) message = args[++i];
    if (args[i] == '--duration' && i + 1 < args.length) duration = int.tryParse(args[++i]) ?? 3000;
  }

  stdout.writeln('Conectando ao broker em $host:$port para o dispositivo "$deviceId"...');

  final clientId = 'notifier-${DateTime.now().millisecondsSinceEpoch}';
  final client = MqttServerClient.withPort(host!, clientId, port!)
    ..logging(on: false)
    ..keepAlivePeriod = 20;

  client.connectionMessage = MqttConnectMessage()
      .withClientIdentifier(clientId)
      .startClean();

  try {
    await client.connect();
  } catch (e) {
    stderr.writeln('Falha ao conectar no broker $host:$port -> $e');
    exit(1);
  }

  if (client.connectionStatus?.state != MqttConnectionState.connected) {
    stderr.writeln('Status de conexao inválido: ${client.connectionStatus?.state}');
    exit(1);
  }

  final event = AgentEvent(
    kind: AgentEventKind.fromString(kindStr),
    message: message,
    durationMs: duration,
  );

  final topic = 'nodes/$deviceId/event';
  stdout.writeln('Enviando evento: $event no tópico $topic');

  final builder = MqttClientPayloadBuilder();
  builder.addUTF8String(jsonEncode(event.toJson()));

  client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!, retain: false);

  await Future.delayed(const Duration(milliseconds: 300));
  client.disconnect();
  stdout.writeln('Evento enviado com sucesso!');
  exit(0);
}
