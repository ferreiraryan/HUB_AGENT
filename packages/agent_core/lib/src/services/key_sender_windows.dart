import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'key_sender.dart';

class WindowsKeySender implements KeySender {
  @override
  Future<bool> send(String combo) async {
    final parts = combo
        .toLowerCase()
        .split('+')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return false;

    final mods = <int>[];
    int? vk;

    for (final p in parts) {
      switch (p) {
        case 'ctrl':
        case 'control':
          mods.add(VK_CONTROL);
          break;
        case 'shift':
          mods.add(VK_SHIFT);
          break;
        case 'alt':
          mods.add(VK_MENU);
          break;
        case 'win':
        case 'meta':
        case 'super':
          mods.add(VK_LWIN);
          break;
        default:
          final resolved = _resolveKey(p);
          if (resolved == null) return false;
          vk = resolved;
      }
    }

    if (vk == null) return false;

    for (final m in mods) _sendKey(m, true);

    _sendKey(vk, true);
    _sendKey(vk, false);

    for (final m in mods.reversed) _sendKey(m, false);

    return true;
  }

  int? _resolveKey(String name) {
    if (name.length == 1) {
      final code = name.codeUnitAt(0);
      if (code >= 0x61 && code <= 0x7A) {
        return 0x41 + (code - 0x61);
      }
      if (code >= 0x30 && code <= 0x39) {
        return 0x30 + (code - 0x30);
      }
    }

    const special = <String, int>{
      'enter': 0x0D,
      'return': 0x0D,
      'esc': 0x1B,
      'escape': 0x1B,
      'tab': 0x09,
      'space': 0x20,
      'backspace': 0x08,
      'delete': 0x2E,
      'del': 0x2E,
      'insert': 0x2D,
      'ins': 0x2D,
      'home': 0x24,
      'end': 0x23,
      'page_up': 0x21,
      'pgup': 0x21,
      'page_down': 0x22,
      'pgdn': 0x22,
      'up': 0x26,
      'down': 0x28,
      'left': 0x25,
      'right': 0x27,
      'media_play_pause': 0xB3,
      'media_next': 0xB0,
      'media_prev': 0xB1,
      'media_stop': 0xB2,
      'volume_up': 0xAF,
      'volume_down': 0xAE,
      'volume_mute': 0xAD,
    };

    if (special.containsKey(name)) return special[name];

    final m = RegExp(r'^f(\d{1,2})$').firstMatch(name);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      if (n >= 1 && n <= 24) return 0x70 + (n - 1);
    }

    return null;
  }

  void _sendKey(int vk, bool down) {
    final input = calloc<INPUT>();
    input.ref.type = INPUT_KEYBOARD;
    input.ref.ki.wVk = vk;
    input.ref.ki.dwFlags = down ? 0 : KEYEVENTF_KEYUP;

    SendInput(1, input, sizeOf<INPUT>());

    free(input);
  }

  @override
  Future<void> dispose() async {}
}
