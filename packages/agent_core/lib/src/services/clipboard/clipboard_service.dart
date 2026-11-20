import 'dart:convert';
import 'dart:io';

import '../../util/windows_binaries.dart';

/// Ponte de área de transferência (Clipboard) cross-platform (Windows & Linux).
class ClipboardService {
  String? _helperPath;

  Future<String> getText() async {
    if (Platform.isWindows) {
      _helperPath ??= WindowsBinaries.resolveHelperPath();
      if (_helperPath == null) return '';
      try {
        final r = await Process.run(
          _helperPath!,
          ['get-clipboard'],
          runInShell: false,
        ).timeout(const Duration(seconds: 2));
        if (r.exitCode == 0) {
          final map = jsonDecode((r.stdout as String).trim());
          if (map is Map && map['text'] is String) {
            return map['text'] as String;
          }
        }
      } catch (_) {}
      return '';
    }

    if (Platform.isLinux) {
      for (final cmd in const [
        ['wl-paste', '--no-newline'],
        ['xclip', '-o', '-selection', 'clipboard'],
        ['xsel', '--clipboard', '--output'],
      ]) {
        try {
          final r = await Process.run(cmd.first, cmd.skip(1).toList(),
                  runInShell: false)
              .timeout(const Duration(seconds: 2));
          if (r.exitCode == 0) return r.stdout as String;
        } catch (_) {}
      }
    }

    return '';
  }

  Future<bool> setText(String text) async {
    if (Platform.isWindows) {
      _helperPath ??= WindowsBinaries.resolveHelperPath();
      if (_helperPath == null) return false;
      try {
        final b64 = base64Encode(utf8.encode(text));
        final r = await Process.run(
          _helperPath!,
          ['set-clipboard', b64],
          runInShell: false,
        ).timeout(const Duration(seconds: 2));
        return r.exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    if (Platform.isLinux) {
      for (final cmd in const [
        ['wl-copy'],
        ['xclip', '-i', '-selection', 'clipboard'],
        ['xsel', '--clipboard', '--input'],
      ]) {
        try {
          final proc = await Process.start(cmd.first, cmd.skip(1).toList(),
              runInShell: false);
          proc.stdin.write(text);
          await proc.stdin.close();
          final code = await proc.exitCode.timeout(const Duration(seconds: 2));
          if (code == 0) return true;
        } catch (_) {}
      }
    }

    return false;
  }
}
