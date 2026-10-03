import 'dart:async';
import 'dart:io';

import '../models/media_state.dart';
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
  Future<void> playPause() => _run(['sendkeypress', '0xB3']);
  @override
  Future<void> next() => _run(['sendkeypress', '0xB0']);
  @override
  Future<void> previous() => _run(['sendkeypress', '0xB1']);

  Future<void> _run(List<String> args) async {
    if (_nircmdPath == null) return;
    try {
      final r = await Process.run(
        _nircmdPath!,
        args,
        runInShell: false,
      );
      print('[MEDIA] run: ${args.join(' ')} exit=${r.exitCode}');
    } catch (e) {
      stderr.writeln('media: nircmd ${args.join(' ')} falhou: $e');
    }
  }
}