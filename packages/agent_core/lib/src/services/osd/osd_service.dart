import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../util/windows_binaries.dart';

/// Serviço de HUD / OSD flutuante no PC (feedback visual ao alterar sliders ou ações).
abstract interface class OsdService {
  bool get enabled;
  String get position;

  void setConfig({bool? enabled, String? position});

  Future<void> showSlider({
    required String title,
    required int value,
    String icon = 'volume',
    String? subtitle,
    String? accentHex,
    int durationMs = 1800,
  });

  Future<void> showBadge({
    required String title,
    required String subtitle,
    String icon = 'toggle',
    String? accentHex,
    int durationMs = 1600,
  });

  Future<void> dispose();
}

OsdService createDefaultOsdService() {
  if (Platform.isWindows) return WindowsOsdService();
  if (Platform.isLinux) return LinuxOsdService();
  return NoopOsdService();
}

class NoopOsdService implements OsdService {
  @override
  bool enabled = false;
  @override
  String position = 'bottom_center';

  @override
  void setConfig({bool? enabled, String? position}) {
    if (enabled != null) this.enabled = enabled;
    if (position != null) this.position = position;
  }

  @override
  Future<void> showSlider({
    required String title,
    required int value,
    String icon = 'volume',
    String? subtitle,
    String? accentHex,
    int durationMs = 1800,
  }) async {}

  @override
  Future<void> showBadge({
    required String title,
    required String subtitle,
    String icon = 'toggle',
    String? accentHex,
    int durationMs = 1600,
  }) async {}

  @override
  Future<void> dispose() async {}
}

/// Implementação Windows via `hub_audio_helper.exe osd-daemon` (janela GDI+
/// transparente click-through que não rouba foco).
class WindowsOsdService implements OsdService {
  @override
  bool enabled;
  @override
  String position;

  Process? _daemon;
  bool _starting = false;
  bool _disposed = false;
  String? _helperPath;

  WindowsOsdService({
    this.enabled = true,
    this.position = 'bottom_center',
  });

  static String encodePayload({
    required String kind,
    required String title,
    required String icon,
    String subtitle = '',
    int value = 0,
    String accentHex = '#cba6f7',
    String position = 'bottom_center',
    int durationMs = 1800,
  }) {
    return jsonEncode({
      'kind': kind,
      'icon': icon,
      'title': title,
      'subtitle': subtitle,
      'value': value.clamp(0, 100),
      'accent': accentHex,
      'position': position,
      'duration_ms': durationMs,
    });
  }

  @override
  void setConfig({bool? enabled, String? position}) {
    if (enabled != null) this.enabled = enabled;
    if (position != null && position.isNotEmpty) this.position = position;
  }

  Future<bool> _ensureDaemon() async {
    if (_disposed || !enabled) return false;
    if (_daemon != null) return true;
    if (_starting) return false;
    _starting = true;
    try {
      _helperPath ??= WindowsBinaries.resolveHelperPath();
      if (_helperPath == null) return false;
      final proc = await Process.start(
        _helperPath!,
        ['osd-daemon'],
        runInShell: false,
      );
      _daemon = proc;
      proc.stdout.drain<void>();
      proc.stderr.drain<void>();
      proc.exitCode.then((_) {
        if (_daemon == proc) _daemon = null;
      });
      return true;
    } catch (_) {
      return false;
    } finally {
      _starting = false;
    }
  }

  Future<void> _sendLine(String jsonLine) async {
    if (!enabled || _disposed) return;
    final ok = await _ensureDaemon();
    if (!ok || _daemon == null) return;
    try {
      _daemon!.stdin.writeln(jsonLine);
      await _daemon!.stdin.flush();
    } catch (_) {
      _daemon = null;
    }
  }

  @override
  Future<void> showSlider({
    required String title,
    required int value,
    String icon = 'volume',
    String? subtitle,
    String? accentHex,
    int durationMs = 1800,
  }) async {
    if (!enabled) return;
    final v = value.clamp(0, 100);
    await _sendLine(encodePayload(
      kind: 'slider',
      title: title,
      icon: icon,
      subtitle: subtitle ?? '$v%',
      value: v,
      accentHex: accentHex ?? '#cba6f7',
      position: position,
      durationMs: durationMs,
    ));
  }

  @override
  Future<void> showBadge({
    required String title,
    required String subtitle,
    String icon = 'toggle',
    String? accentHex,
    int durationMs = 1600,
  }) async {
    if (!enabled) return;
    await _sendLine(encodePayload(
      kind: 'badge',
      title: title,
      icon: icon,
      subtitle: subtitle,
      accentHex: accentHex ?? '#cba6f7',
      position: position,
      durationMs: durationMs,
    ));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final proc = _daemon;
    _daemon = null;
    if (proc != null) {
      try {
        proc.stdin.writeln('quit');
        await proc.stdin.flush();
      } catch (_) {}
      proc.kill();
    }
  }
}

/// Implementação Linux via `notify-send` síncrono (com hint de barra de progresso
/// compatível com dunst, mako, swaync, GNOME e KDE).
class LinuxOsdService implements OsdService {
  @override
  bool enabled;
  @override
  String position;

  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  LinuxOsdService({
    this.enabled = true,
    this.position = 'bottom_center',
  });

  @override
  void setConfig({bool? enabled, String? position}) {
    if (enabled != null) this.enabled = enabled;
    if (position != null && position.isNotEmpty) this.position = position;
  }

  bool _shouldThrottle() {
    final now = DateTime.now();
    if (now.difference(_lastSent) < const Duration(milliseconds: 80)) {
      return true;
    }
    _lastSent = now;
    return false;
  }

  @override
  Future<void> showSlider({
    required String title,
    required int value,
    String icon = 'volume',
    String? subtitle,
    String? accentHex,
    int durationMs = 1800,
  }) async {
    if (!enabled || _shouldThrottle()) return;
    final v = value.clamp(0, 100);
    try {
      await Process.run(
        'notify-send',
        [
          '-a',
          'hub_agent',
          '-t',
          '$durationMs',
          '-h',
          'int:value:$v',
          '-h',
          'string:x-canonical-private-synchronous:hub-agent-osd',
          title,
          subtitle ?? '$v%',
        ],
        runInShell: false,
      );
    } catch (_) {}
  }

  @override
  Future<void> showBadge({
    required String title,
    required String subtitle,
    String icon = 'toggle',
    String? accentHex,
    int durationMs = 1600,
  }) async {
    if (!enabled) return;
    try {
      await Process.run(
        'notify-send',
        [
          '-a',
          'hub_agent',
          '-t',
          '$durationMs',
          '-h',
          'string:x-canonical-private-synchronous:hub-agent-osd',
          title,
          subtitle,
        ],
        runInShell: false,
      );
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {}
}
