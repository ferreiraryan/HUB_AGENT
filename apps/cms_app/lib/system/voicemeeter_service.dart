import 'dart:io';

import 'agent_config.dart';

class VoiceMeeterService {
  static const List<String> defaultCandidates = [
    r'C:\Program Files (x86)\VB\Voicemeeter\voicemeeter_x64.exe',
    r'C:\Program Files (x86)\VB\Voicemeeter\voicemeeter.exe',
    r'C:\Program Files\VB\Voicemeeter\voicemeeter_x64.exe',
    r'C:\Program Files\VB\Voicemeeter\voicemeeter.exe',
  ];

  static String? findInstalledExe({String? customPath}) {
    if (!Platform.isWindows) return null;
    if (customPath != null && customPath.trim().isNotEmpty) {
      if (File(customPath.trim()).existsSync()) return customPath.trim();
    }
    for (final path in defaultCandidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  static bool isInstalled({String? customPath}) =>
      findInstalledExe(customPath: customPath) != null;

  static Future<bool> isRunning() async {
    if (!Platform.isWindows) return false;
    try {
      final res = await Process.run('tasklist', ['/FI', 'IMAGENAME eq voicemeeter*']);
      if (res.exitCode == 0) {
        final out = (res.stdout as String).toLowerCase();
        return out.contains('voicemeeter');
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> launch({
    String? customPath,
    String? configXml,
  }) async {
    if (!Platform.isWindows) return false;

    if (await isRunning()) {
      stdout.writeln('VoiceMeeter já está em execução.');
      return true;
    }

    final exe = findInstalledExe(customPath: customPath);
    if (exe == null) {
      stderr.writeln('VoiceMeeter não encontrado no sistema.');
      return false;
    }

    final args = <String>['-h'];
    if (configXml != null && configXml.trim().isNotEmpty) {
      final xmlFile = File(configXml.trim());
      if (xmlFile.existsSync()) {
        args.add('-l${xmlFile.path}');
      }
    }

    try {
      await Process.start(
        exe,
        args,
        mode: ProcessStartMode.detached,
      );
      stdout.writeln('VoiceMeeter iniciado em segundo plano: $exe com argumentos: $args');
      return true;
    } catch (e) {
      stderr.writeln('Erro ao iniciar VoiceMeeter ($exe): $e');
      return false;
    }
  }

  static Future<bool> launchIfEnabled(AgentConfig config) async {
    if (!Platform.isWindows || !config.autoStartVoiceMeeter) {
      return false;
    }
    return launch(
      customPath: config.voiceMeeterPath,
      configXml: config.voiceMeeterConfigXml,
    );
  }
}

