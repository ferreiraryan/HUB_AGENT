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

  /// Converte combinações como "win+tab", "ctrl+shift+esc", "alt+f4"
  /// para keysyms válidos do xdotool / X11.
  static String? normalizeCombo(String combo) {
    final trimmed = combo.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    const aliases = <String, String>{
      'win': 'Super_L',
      'windows': 'Super_L',
      'leftwin': 'Super_L',
      'lwin': 'Super_L',
      'super': 'Super_L',
      'meta': 'Super_L',
      'cmd': 'Super_L',
      'command': 'Super_L',
      'rightwin': 'Super_R',
      'rwin': 'Super_R',
      'control': 'ctrl',
      'esc': 'Escape',
      'escape': 'Escape',
      'enter': 'Return',
      'return': 'Return',
      'tab': 'Tab',
      'del': 'Delete',
      'delete': 'Delete',
      'ins': 'Insert',
      'insert': 'Insert',
      'spc': 'space',
      'space': 'space',
      'espaço': 'space',
      'espaco': 'space',
      'back': 'BackSpace',
      'bksp': 'BackSpace',
      'backspace': 'BackSpace',
      'pgup': 'Prior',
      'page_up': 'Prior',
      'pageup': 'Prior',
      'pgdn': 'Next',
      'page_down': 'Next',
      'pagedown': 'Next',
      'prtscn': 'Print',
      'prtsc': 'Print',
      'print_screen': 'Print',
      'printscreen': 'Print',
      'up': 'Up',
      'down': 'Down',
      'left': 'Left',
      'right': 'Right',
      'home': 'Home',
      'end': 'End',
      'capslock': 'Caps_Lock',
    };

    final parts = trimmed
        .split('+')
        .map((p) {
          final k = p.trim();
          if (k.isEmpty) return '';
          if (aliases.containsKey(k)) return aliases[k]!;
          if (RegExp(r'^f([1-9]|1[0-9]|2[0-4])$').hasMatch(k)) {
            return k.toUpperCase();
          }
          return k;
        })
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) return null;
    return parts.join('+');
  }

  @override
  Future<bool> send(String combo) async {
    if (!_xdotool) {
      final ok = await _probe();
      if (!ok) return false;
    }

    final normalized = normalizeCombo(combo);
    if (normalized == null) return false;

    try {
      final r = await Process.run('xdotool', ['key', normalized]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> dispose() async {}
}
