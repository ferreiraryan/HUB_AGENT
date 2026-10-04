// packages/agent_core/lib/src/services/media_windows.dart

import 'dart:async';
import 'dart:io';

import 'media_service.dart';

/// MediaService para Windows via nircmd.exe.
///
/// Play/pause/next/prev enviam teclas de mídia via `sendkeypress` do nircmd.
/// IMPORTANTE: usar `sendkeypress` (com "press"), NÃO `sendkey`. O comando
/// errado abre a janela de help do nircmd. As teclas de mídia são passadas
/// como VK codes em hexadecimal (0xB3 = play/pause, 0xB0 = next, 0xB1 = prev).
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

  // VK codes de mídia em hex (mesmos que o Windows usa via SendInput).
  // 0xB3 = VK_MEDIA_PLAY_PAUSE
  // 0xB0 = VK_MEDIA_NEXT_TRACK
  // 0xB1 = VK_MEDIA_PREV_TRACK
  // 0xB2 = VK_MEDIA_STOP
  @override
  Future<void> playPause() => _sendKey('0xB3');
  @override
  Future<void> next() => _sendKey('0xB0');
  @override
  Future<void> previous() => _sendKey('0xB1');

  Future<void> _sendKey(String vkCodeHex) async {
    if (_nircmdPath == null) return;
    try {
      final r = await Process.run(
        _nircmdPath!,
        ['sendkeypress', vkCodeHex],
        runInShell: false,
      );
      print('[MEDIA] sendkeypress $vkCodeHex exit=${r.exitCode}');
    } catch (e) {
      stderr.writeln('media: nircmd sendkeypress $vkCodeHex falhou: $e');
    }
  }
}