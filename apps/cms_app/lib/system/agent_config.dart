import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AgentConfig {
  final String host;
  final int port;
  final String deviceId;
  final String? soundOutputDevice;
  final bool mirrorNotifications;
  final int soundVolume;
  final bool autoStartVoiceMeeter;
  final String? voiceMeeterPath;
  final String? voiceMeeterConfigXml;

  const AgentConfig({
    required this.host,
    required this.port,
    required this.deviceId,
    this.soundOutputDevice,
    this.mirrorNotifications = true,
    this.soundVolume = 100,
    this.autoStartVoiceMeeter = false,
    this.voiceMeeterPath,
    this.voiceMeeterConfigXml,
  });

  factory AgentConfig.fromJson(Map<String, dynamic> json) => AgentConfig(
        host: json['host'] as String? ?? 'localhost',
        port: json['port'] as int? ?? 1883,
        deviceId: json['deviceId'] as String? ?? Platform.localHostname,
        soundOutputDevice: json['soundOutputDevice'] as String?,
        mirrorNotifications: json['mirrorNotifications'] as bool? ?? true,
        soundVolume: (json['soundVolume'] as num?)?.toInt() ?? 100,
        autoStartVoiceMeeter: json['autoStartVoiceMeeter'] as bool? ?? false,
        voiceMeeterPath: json['voiceMeeterPath'] as String?,
        voiceMeeterConfigXml: json['voiceMeeterConfigXml'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'deviceId': deviceId,
        'mirrorNotifications': mirrorNotifications,
        'soundVolume': soundVolume,
        'autoStartVoiceMeeter': autoStartVoiceMeeter,
        if (soundOutputDevice != null) 'soundOutputDevice': soundOutputDevice,
        if (voiceMeeterPath != null) 'voiceMeeterPath': voiceMeeterPath,
        if (voiceMeeterConfigXml != null)
          'voiceMeeterConfigXml': voiceMeeterConfigXml,
      };

  AgentConfig copyWith({
    String? host,
    int? port,
    String? deviceId,
    String? soundOutputDevice,
    bool? mirrorNotifications,
    int? soundVolume,
    bool? autoStartVoiceMeeter,
    String? voiceMeeterPath,
    String? voiceMeeterConfigXml,
    bool clearSoundOutputDevice = false,
    bool clearVoiceMeeterPath = false,
    bool clearVoiceMeeterConfigXml = false,
  }) =>
      AgentConfig(
        host: host ?? this.host,
        port: port ?? this.port,
        deviceId: deviceId ?? this.deviceId,
        mirrorNotifications: mirrorNotifications ?? this.mirrorNotifications,
        soundVolume: soundVolume ?? this.soundVolume,
        autoStartVoiceMeeter: autoStartVoiceMeeter ?? this.autoStartVoiceMeeter,
        soundOutputDevice: clearSoundOutputDevice
            ? null
            : (soundOutputDevice ?? this.soundOutputDevice),
        voiceMeeterPath: clearVoiceMeeterPath
            ? null
            : (voiceMeeterPath ?? this.voiceMeeterPath),
        voiceMeeterConfigXml: clearVoiceMeeterConfigXml
            ? null
            : (voiceMeeterConfigXml ?? this.voiceMeeterConfigXml),
      );

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
      mirrorNotifications: true,
      soundVolume: 100,
      autoStartVoiceMeeter: false,
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
