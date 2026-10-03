// packages/agent_core/lib/src/services/key_sender_windows.dart

import 'dart:io';

import 'key_sender.dart';

/// Envia teclas no Windows via nircmd.exe.
///
/// Por que nircmd e não SendInput via FFI: montar a struct INPUT na mão
/// é chato (union, layouts de 32 vs 64 bits) e já causou crash. O nircmd
/// encapsula isso num binário de 100 KB que está no bundle do app.
class WindowsKeySender implements KeySender {
  String? _nircmdPath;

  @override
  Future<bool> send(String combo) async {
    _nircmdPath ??= await _resolveNircmdPath();
    if (_nircmdPath == null) return false;

    final media = _mediaCommand(combo);
    if (media != null) {
      return _run(['sendkeypress', media]);
    }

    final normalized = _normalizeCombo(combo);
    if (normalized == null) return false;
    return _run(['sendkeypress', normalized]);
  }

  /// Mapeia ações de mídia para comandos nativos do nircmd.
String? _mediaCommand(String combo) {
  switch (combo.trim().toLowerCase()) {
    case 'media_play_pause':
    case 'play_pause':
      return '0xB3';
    case 'media_next':
    case 'next':
      return '0xB0';
    case 'media_prev':
    case 'prev':
      return '0xB1';
    case 'media_stop':
    case 'stop':
      return '0xB2';
    case 'volume_up':
      return '0xAF';
    case 'volume_down':
      return '0xAE';
    case 'volume_mute':
      return '0xAD';
    default:
      return null;
  }
}

  /// Converte "ctrl+shift+s" para o formato que o nircmd aceita.
  ///
  /// O nircmd aceita nomes como "ctrl", "shift", "alt", "enter", "esc",
  /// "f1".."f24", e usa "+" como separador de modificadores — o mesmo
  /// formato que o usuário digita no CMS.
  String? _normalizeCombo(String combo) {
    final trimmed = combo.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    // Aliases de nomes comuns.
    const aliases = <String, String>{
      'control': 'ctrl',
      'escape': 'esc',
      'return': 'enter',
      'del': 'delete',
      'ins': 'insert',
      'pgup': 'pageup',
      'pgdn': 'pagedown',
      'meta': 'win',
      'super': 'win',
    };

    final parts = trimmed.split('+').map((p) {
      final k = p.trim();
      return aliases[k] ?? k;
    }).where((s) => s.isNotEmpty).toList();

    if (parts.isEmpty) return null;
    return parts.join('+');
  }

  Future<bool> _run(List<String> args) async {
    try {
      final r = await Process.run(
        _nircmdPath!,
        args,
        runInShell: false,
      );
      return r.exitCode == 0;
    } catch (e) {
      stderr.writeln('key_sender: nircmd ${args.join(' ')} falhou: $e');
      return false;
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
    // Fallback: procura no PATH.
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
  Future<void> dispose() async {}
}