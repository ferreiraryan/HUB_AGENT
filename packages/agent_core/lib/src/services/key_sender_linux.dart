import 'dart:io';

import 'key_sender.dart';

class LinuxKeySender implements KeySender {
  bool _xdotool = false;
  // ydotool ainda não implementado (requer mapeamento de nomes para event codes
  // do kernel Linux, como 29:1 para ctrl press, ao contrário do xdotool que
  // aceita strings legíveis diretamente).

  Future<bool> _probe() async {
    try {
      final r = await Process.run('which', ['xdotool']);
      if (r.exitCode == 0) {
        _xdotool = true;
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> send(String combo) async {
    if (!_xdotool) {
      final ok = await _probe();
      if (!ok) return false;
    }

    try {
      final r = await Process.run('xdotool', ['key', combo]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> dispose() async {}
}
