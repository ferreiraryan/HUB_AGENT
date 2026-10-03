// packages/agent_core/lib/src/services/media_windows.dart

import 'dart:async';
import 'dart:io';

import 'media_service.dart';

class WindowsMediaService extends MediaService {
  String? _nircmdPath;

  @override
  Future<void> start() async {
    _nircmdPath = await _resolveNircmdPath();
    available = _nircmdPath != null;
    if (!available) {
      stderr.writeln('media: nircmd.exe nao encontrado');
      return;
    }
  }

  Future<String?> _resolveNircmdPath() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      '$exeDir${Platform.pathSeparator}nircmd.exe',
      '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}nircmd.exe',
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }
    try {
      final r = await Process.run('where', ['nircmd.exe']);
      if (r.exitCode == 0) {
        final first = (r.stdout as String).trim().split('\n').first.trim();
        if (first.isNotEmpty) return first;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> playPause() => _sendKey('play');
  @override
  Future<void> next() => _sendKey('nexttrack');
  @override
  Future<void> previous() => _sendKey('prevtrack');

  Future<void> _sendKey(String key) async {
    if (_nircmdPath == null) return;
    try {
      final r = await Process.run(
        _nircmdPath!,
        ['sendkey', key],
        runInShell: false,
      );
      print('[MEDIA] sendkey $key exit=${r.exitCode}');
    } catch (e) {
      stderr.writeln('media: nircmd sendkey $key falhou: $e');
    }
  }
}
