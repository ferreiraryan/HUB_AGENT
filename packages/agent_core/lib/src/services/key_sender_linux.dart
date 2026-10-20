// packages/agent_core/lib/src/services/key_sender_linux.dart

import 'dart:async';
import 'dart:io';

import 'key_sender.dart';

/// Tipo de função para execução de processos em testes e runtime.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  bool runInShell,
});

/// Backends suportados para injeção de teclas no Linux.
enum LinuxKeyBackend {
  wtype,
  ydotool,
  xdotool,
  none,
}

/// Envia teclas no Linux.
///
/// Prioridades de backend:
/// 1. Wayland (WAYLAND_DISPLAY presente):
///    - `wtype` (protocolo zwp_virtual_keyboard_v1, padrão do Hyprland/Sway).
///    - Fallback para `ydotool` (via uinput/ydotoold).
///    - Fallback para `xdotool` (compatibilidade com janelas XWayland).
/// 2. X11 puro:
///    - `xdotool` (XTest).
///    - Fallback para `ydotool`.
class LinuxKeySender implements KeySender {
  final ProcessRunner _runner;
  final Map<String, String>? _environment;

  LinuxKeyBackend? _backend;

  LinuxKeySender({
    ProcessRunner? runner,
    Map<String, String>? environment,
  })  : _runner = runner ?? Process.run,
        _environment = environment;

  /// Retorna o backend atualmente detectado em runtime (útil para diagnóstico).
  Future<LinuxKeyBackend> get detectedBackend => _detectBackend();

  Future<LinuxKeyBackend> _detectBackend() async {
    if (_backend != null) return _backend!;

    final env = _environment ?? Platform.environment;
    final isWayland = (env['WAYLAND_DISPLAY'] ?? '').trim().isNotEmpty;

    if (isWayland) {
      if (await _hasCommand('wtype')) {
        return _backend = LinuxKeyBackend.wtype;
      }
      if (await _hasCommand('ydotool')) {
        return _backend = LinuxKeyBackend.ydotool;
      }
      if (await _hasCommand('xdotool')) {
        return _backend = LinuxKeyBackend.xdotool;
      }
    } else {
      if (await _hasCommand('xdotool')) {
        return _backend = LinuxKeyBackend.xdotool;
      }
      if (await _hasCommand('ydotool')) {
        return _backend = LinuxKeyBackend.ydotool;
      }
      if (await _hasCommand('wtype')) {
        return _backend = LinuxKeyBackend.wtype;
      }
    }

    stderr.writeln(
      'key_sender_linux: nenhuma ferramenta de envio de teclas disponível (wtype, ydotool, xdotool). '
      'No Wayland / Hyprland, instale wtype (ex: sudo pacman -S wtype).',
    );
    return _backend = LinuxKeyBackend.none;
  }

  Future<bool> _hasCommand(String cmd) async {
    try {
      final r = await _runner('which', [cmd]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Converte ações de mídia para keysyms XF86.
  static String? mediaToXf86(String combo) {
    switch (combo.trim().toLowerCase()) {
      case 'media_play_pause':
      case 'play_pause':
        return 'XF86AudioPlay';
      case 'media_next':
      case 'next':
        return 'XF86AudioNext';
      case 'media_prev':
      case 'prev':
        return 'XF86AudioPrev';
      case 'media_stop':
      case 'stop':
        return 'XF86AudioStop';
      case 'volume_up':
        return 'XF86AudioRaiseVolume';
      case 'volume_down':
        return 'XF86AudioLowerVolume';
      case 'volume_mute':
        return 'XF86AudioMute';
      default:
        return null;
    }
  }

  /// Converte uma combinação legível (ex: "ctrl+shift+s", "win+d", "alt+f4")
  /// nos argumentos esperados pelo binário `wtype`.
  static List<String>? buildWtypeArgs(String combo) {
    final trimmed = combo.trim();
    if (trimmed.isEmpty) return null;

    final media = mediaToXf86(trimmed);
    if (media != null) {
      return ['-k', media];
    }

    const modifierMap = <String, String>{
      'ctrl': 'ctrl',
      'control': 'ctrl',
      'alt': 'alt',
      'shift': 'shift',
      'win': 'win',
      'windows': 'win',
      'super': 'win',
      'meta': 'win',
      'cmd': 'win',
      'command': 'win',
      'leftwin': 'win',
      'lwin': 'win',
      'rightwin': 'win',
      'rwin': 'win',
      'altgr': 'altgr',
      'capslock': 'capslock',
    };

    const keyAliases = <String, String>{
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

    final rawTokens = trimmed
        .toLowerCase()
        .split('+')
        .map((p) => p.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (rawTokens.isEmpty) return null;

    final activeMods = <String>[];
    final activeKeys = <String>[];

    for (final token in rawTokens) {
      final mod = modifierMap[token];
      if (mod != null) {
        if (!activeMods.contains(mod)) {
          activeMods.add(mod);
        }
      } else {
        String keyName;
        if (keyAliases.containsKey(token)) {
          keyName = keyAliases[token]!;
        } else if (RegExp(r'^f([1-9]|1[0-9]|2[0-4])$').hasMatch(token)) {
          keyName = token.toUpperCase();
        } else if (token.length == 1) {
          keyName = token;
        } else {
          keyName = token;
        }
        activeKeys.add(keyName);
      }
    }

    if (activeKeys.length > 1) {
      return null;
    }

    final args = <String>[];

    if (activeKeys.isEmpty) {
      if (activeMods.length == 1) {
        final solo = activeMods.first;
        switch (solo) {
          case 'win':
            return ['-k', 'Super_L'];
          case 'ctrl':
            return ['-k', 'Control_L'];
          case 'alt':
            return ['-k', 'Alt_L'];
          case 'shift':
            return ['-k', 'Shift_L'];
          default:
            return null;
        }
      }
      return null;
    }

    for (final mod in activeMods) {
      args.addAll(['-M', mod]);
    }

    args.addAll(['-k', activeKeys.first]);

    for (final mod in activeMods.reversed) {
      args.addAll(['-m', mod]);
    }

    return args;
  }

  /// Converte uma combinação nos argumentos esperados pelo binário `ydotool` (via scancodes do kernel).
  static List<String>? buildYdotoolArgs(String combo) {
    final trimmed = combo.trim();
    if (trimmed.isEmpty) return null;

    final media = mediaToXf86(trimmed);
    final lookup = media != null ? trimmed.toLowerCase() : null;

    const scancodes = <String, int>{
      'esc': 1, 'escape': 1,
      '1': 2, '2': 3, '3': 4, '4': 5, '5': 6, '6': 7, '7': 8, '8': 9, '9': 10, '0': 11,
      'backspace': 14, 'bksp': 14, 'back': 14,
      'tab': 15,
      'q': 16, 'w': 17, 'e': 18, 'r': 19, 't': 20, 'y': 21, 'u': 22, 'i': 23, 'o': 24, 'p': 25,
      'enter': 28, 'return': 28,
      'ctrl': 29, 'control': 29, 'leftctrl': 29, 'lctrl': 29,
      'a': 30, 's': 31, 'd': 32, 'f': 33, 'g': 34, 'h': 35, 'j': 36, 'k': 37, 'l': 38,
      'shift': 42, 'leftshift': 42, 'lshift': 42,
      'z': 44, 'x': 45, 'c': 46, 'v': 47, 'b': 48, 'n': 49, 'm': 50,
      'rightshift': 54, 'rshift': 54,
      'alt': 56, 'leftalt': 56, 'lalt': 56,
      'space': 57, 'spc': 57, 'espaço': 57, 'espaco': 57,
      'capslock': 58,
      'f1': 59, 'f2': 60, 'f3': 61, 'f4': 62, 'f5': 63, 'f6': 64, 'f7': 65, 'f8': 66, 'f9': 67, 'f10': 68,
      'f11': 87, 'f12': 88,
      'rightctrl': 97, 'rctrl': 97,
      'altgr': 100, 'rightalt': 100,
      'home': 102, 'up': 103, 'pgup': 104, 'pageup': 104, 'page_up': 104,
      'left': 105, 'right': 106, 'end': 107, 'down': 108, 'pgdn': 109, 'pagedown': 109, 'page_down': 109,
      'ins': 110, 'insert': 110, 'del': 111, 'delete': 111,
      'volume_mute': 113, 'volume_down': 114, 'volume_up': 115,
      'media_next': 163, 'next': 163,
      'media_play_pause': 164, 'play_pause': 164,
      'media_prev': 165, 'prev': 165,
      'media_stop': 166, 'stop': 166,
      'win': 125, 'windows': 125, 'super': 125, 'meta': 125, 'cmd': 125, 'command': 125, 'leftwin': 125, 'lwin': 125,
      'rightwin': 126, 'rwin': 126,
    };

    if (lookup != null) {
      final code = scancodes[lookup];
      if (code == null) return null;
      return ['key', '$code:1', '$code:0'];
    }

    const modifierTokens = {
      'ctrl', 'control', 'alt', 'shift', 'win', 'windows', 'super', 'meta',
      'cmd', 'command', 'leftwin', 'lwin', 'rightwin', 'rwin', 'altgr', 'capslock',
    };

    final rawTokens = trimmed
        .toLowerCase()
        .split('+')
        .map((p) => p.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (rawTokens.isEmpty) return null;

    final modCodes = <int>[];
    final keyCodes = <int>[];

    for (final token in rawTokens) {
      final code = scancodes[token];
      if (code == null) return null;

      if (modifierTokens.contains(token)) {
        if (!modCodes.contains(code)) modCodes.add(code);
      } else {
        keyCodes.add(code);
      }
    }

    if (keyCodes.length > 1) return null;

    final events = <String>[];
    if (keyCodes.isEmpty) {
      if (modCodes.length == 1) {
        return ['key', '${modCodes.first}:1', '${modCodes.first}:0'];
      }
      return null;
    }

    for (final m in modCodes) {
      events.add('$m:1');
    }
    events.add('${keyCodes.first}:1');
    events.add('${keyCodes.first}:0');
    for (final m in modCodes.reversed) {
      events.add('$m:0');
    }

    return ['key', ...events];
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
    final backend = await _detectBackend();
    switch (backend) {
      case LinuxKeyBackend.wtype:
        return _sendWtype(combo);
      case LinuxKeyBackend.ydotool:
        return _sendYdotool(combo);
      case LinuxKeyBackend.xdotool:
        return _sendXdotool(combo);
      case LinuxKeyBackend.none:
        return false;
    }
  }

  Future<bool> _sendWtype(String combo) async {
    final args = buildWtypeArgs(combo);
    if (args == null || args.isEmpty) return false;

    try {
      final r = await _runner('wtype', args).timeout(const Duration(seconds: 3));
      if (r.exitCode != 0) {
        stderr.writeln('key_sender_linux (wtype): exitCode ${r.exitCode}: ${r.stderr}');
        return false;
      }
      return true;
    } catch (e) {
      stderr.writeln('key_sender_linux (wtype) falhou: $e');
      return false;
    }
  }

  Future<bool> _sendYdotool(String combo) async {
    final args = buildYdotoolArgs(combo);
    if (args == null || args.isEmpty) return false;

    try {
      final r = await _runner('ydotool', args).timeout(const Duration(seconds: 3));
      if (r.exitCode != 0) {
        stderr.writeln('key_sender_linux (ydotool): exitCode ${r.exitCode}: ${r.stderr}');
        return false;
      }
      return true;
    } catch (e) {
      stderr.writeln('key_sender_linux (ydotool) falhou: $e');
      return false;
    }
  }

  Future<bool> _sendXdotool(String combo) async {
    final media = mediaToXf86(combo);
    final keyArg = media ?? normalizeCombo(combo);
    if (keyArg == null || keyArg.isEmpty) return false;

    try {
      final r = await _runner('xdotool', ['key', keyArg]).timeout(const Duration(seconds: 3));
      if (r.exitCode != 0) {
        stderr.writeln('key_sender_linux (xdotool): exitCode ${r.exitCode}: ${r.stderr}');
        return false;
      }
      return true;
    } catch (e) {
      stderr.writeln('key_sender_linux (xdotool) falhou: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {}
}
