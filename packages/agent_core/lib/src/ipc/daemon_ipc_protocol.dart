import 'dart:convert';
import 'dart:io';
import 'dart:math';

enum GlobalHotkeyStatus {
  disabled,
  ready,
  inUse,
  invalid,
  unsupported;

  static GlobalHotkeyStatus parse(String? raw) => switch (raw) {
        'ready' => GlobalHotkeyStatus.ready,
        'inUse' => GlobalHotkeyStatus.inUse,
        'invalid' => GlobalHotkeyStatus.invalid,
        'unsupported' => GlobalHotkeyStatus.unsupported,
        _ => GlobalHotkeyStatus.disabled,
      };
}

/// Metadados de conexão local do `hub_agent_daemon`, persistidos em
/// `<supportDir>/daemon.ipc.json` com permissão restrita ao usuário atual.
class DaemonEndpointInfo {
  final int pid;
  final int port;
  final String token;
  final int version;

  const DaemonEndpointInfo({
    required this.pid,
    required this.port,
    required this.token,
    this.version = 1,
  });

  static File fileFor(Directory supportDir) =>
      File('${supportDir.path}${Platform.pathSeparator}daemon.ipc.json');

  static String generateToken() {
    final rng = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buf.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  Map<String, dynamic> toJson() => {
        'pid': pid,
        'port': port,
        'token': token,
        'version': version,
      };

  static DaemonEndpointInfo? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final pid = (raw['pid'] as num?)?.toInt();
    final port = (raw['port'] as num?)?.toInt();
    final token = raw['token']?.toString();
    final version = (raw['version'] as num?)?.toInt() ?? 1;
    if (pid == null || port == null || token == null || token.isEmpty) {
      return null;
    }
    return DaemonEndpointInfo(
      pid: pid,
      port: port,
      token: token,
      version: version,
    );
  }

  static Future<DaemonEndpointInfo?> read(Directory supportDir) async {
    try {
      final file = fileFor(supportDir);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return tryFromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeAtomic(Directory supportDir) async {
    await supportDir.create(recursive: true);
    final file = fileFor(supportDir);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(toJson()), flush: true);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', tmp.path]);
      } catch (_) {}
    }
    await tmp.rename(file.path);
  }

  static Future<void> remove(Directory supportDir) async {
    try {
      final file = fileFor(supportDir);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
