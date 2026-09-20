import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AgentConfig {
  final String host;
  final int port;
  final String deviceId;

  const AgentConfig({
    required this.host,
    required this.port,
    required this.deviceId,
  });

  factory AgentConfig.fromJson(Map<String, dynamic> json) => AgentConfig(
    host: json['host'] as String? ?? 'localhost',
    port: json['port'] as int? ?? 1883,
    deviceId: json['deviceId'] as String? ?? Platform.localHostname,
  );

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'deviceId': deviceId,
  };

  static Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/agent_config.json');
  }

  static Future<AgentConfig> load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          return AgentConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
      }
    } catch (e) {
      stderr.writeln('Falha ao ler agent_config.json, usando defaults: $e');
    }

    return AgentConfig(
      host: 'localhost',
      port: 1883,
      deviceId: Platform.localHostname,
    );
  }

  Future<void> save() async {
    try {
      final file = await _getFile();
      await file.parent.create(recursive: true);

      final tmp = File('${file.path}.tmp');
      const encoder = JsonEncoder.withIndent('  ');
      await tmp.writeAsString(encoder.convert(toJson()), flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      stderr.writeln('Falha ao gravar agent_config.json: $e');
    }
  }
}
