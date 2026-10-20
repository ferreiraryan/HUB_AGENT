import 'package:flutter/services.dart';

/// Helper para normalização, formatação e detecção de combinações de teclas.
class KeyComboHelper {
  static const List<String> canonicalModifiers = ['ctrl', 'alt', 'shift', 'win'];

  static const Map<String, String> modifierAliases = {
    'control': 'ctrl',
    'ctrl': 'ctrl',
    'alt': 'alt',
    'shift': 'shift',
    'win': 'win',
    'windows': 'win',
    'super': 'win',
    'meta': 'win',
    'cmd': 'win',
    'command': 'win',
    'lwin': 'win',
    'rwin': 'win',
    'leftwin': 'win',
    'rightwin': 'win',
  };

  static const Map<String, String> keyDisplayNames = {
    'ctrl': 'Ctrl',
    'alt': 'Alt',
    'shift': 'Shift',
    'win': 'Win',
    'esc': 'Esc',
    'escape': 'Esc',
    'return': 'Enter',
    'enter': 'Enter',
    'tab': 'Tab',
    'backspace': 'Backspace',
    'bksp': 'Backspace',
    'del': 'Delete',
    'delete': 'Delete',
    'ins': 'Insert',
    'insert': 'Insert',
    'spc': 'Space',
    'space': 'Space',
    'prior': 'Page Up',
    'pageup': 'Page Up',
    'next': 'Page Down',
    'pagedown': 'Page Down',
    'home': 'Home',
    'end': 'End',
    'up': 'Up',
    'down': 'Down',
    'left': 'Left',
    'right': 'Right',
    'print': 'Print Screen',
    'prtscn': 'Print Screen',
    'printscreen': 'Print Screen',
    'capslock': 'Caps Lock',
  };

  /// Normaliza uma string de combinação de teclas para o formato canônico em minúsculas:
  /// Ordem: ctrl -> alt -> shift -> win -> tecla final.
  /// Remove espaços, múltiplos `+`, maiúsculas/minúsculas e resolve aliases (`super` -> `win`).
  static String normalize(String combo) {
    final trimmed = combo.trim();
    if (trimmed.isEmpty) return '';

    final rawTokens = trimmed
        .toLowerCase()
        .split('+')
        .map((p) => p.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (rawTokens.isEmpty) return '';

    final activeMods = <String>{};
    final activeKeys = <String>[];

    for (final token in rawTokens) {
      final mod = modifierAliases[token];
      if (mod != null) {
        activeMods.add(mod);
      } else {
        // Alias de teclas não modificadoras
        final keyName = token == 'escape'
            ? 'esc'
            : token == 'return'
                ? 'enter'
                : token;
        if (!activeKeys.contains(keyName)) {
          activeKeys.add(keyName);
        }
      }
    }

    final orderedParts = <String>[];
    for (final m in canonicalModifiers) {
      if (activeMods.contains(m)) {
        orderedParts.add(m);
      }
    }
    orderedParts.addAll(activeKeys);

    return orderedParts.join('+');
  }

  /// Formata uma combinação canônica (ex: "ctrl+shift+esc") para exibição amigável ("Ctrl + Shift + Esc").
  static String formatDisplay(String combo) {
    final norm = normalize(combo);
    if (norm.isEmpty) return '';

    final parts = norm.split('+');
    return parts.map((p) {
      if (keyDisplayNames.containsKey(p)) {
        return keyDisplayNames[p]!;
      }
      if (RegExp(r'^f([1-9]|1[0-9]|2[0-4])$').hasMatch(p)) {
        return p.toUpperCase();
      }
      if (p.length == 1) {
        return p.toUpperCase();
      }
      return p[0].toUpperCase() + p.substring(1);
    }).join(' + ');
  }

  /// Alterna um modificador (ex: 'ctrl', 'alt', 'shift', 'win') em uma combinação existente.
  /// Se já existir, remove. Se não existir, adiciona na ordem canônica correta.
  static String toggleModifier(String currentCombo, String modifier) {
    final normMod = modifierAliases[modifier.toLowerCase()] ?? modifier.toLowerCase();
    final norm = normalize(currentCombo);
    if (norm.isEmpty) {
      return normMod;
    }

    final parts = norm.split('+').toList();
    if (parts.contains(normMod)) {
      parts.remove(normMod);
    } else {
      parts.add(normMod);
    }

    return normalize(parts.join('+'));
  }

  /// Verifica se um modificador específico está ativo na combinação.
  static bool hasModifier(String combo, String modifier) {
    final normMod = modifierAliases[modifier.toLowerCase()] ?? modifier.toLowerCase();
    final norm = normalize(combo);
    return norm.split('+').contains(normMod);
  }

  /// Converte um [LogicalKeyboardKey] e o estado atual de modificadores do teclado
  /// em uma combinação canônica (ex: "ctrl+shift+esc", "win+d", "alt+f4").
  static String? fromKeyEvent(KeyEvent event) {
    // Ignora eventos que não sejam de descida de tecla (KeyDown / KeyRepeat)
    if (event is! KeyDownEvent) return null;

    final key = event.logicalKey;
    final isModifier = _isModifierKey(key);

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;

    final activeMods = <String>[];
    if (isCtrl || key == LogicalKeyboardKey.controlLeft || key == LogicalKeyboardKey.controlRight) {
      activeMods.add('ctrl');
    }
    if (isAlt || key == LogicalKeyboardKey.altLeft || key == LogicalKeyboardKey.altRight) {
      activeMods.add('alt');
    }
    if (isShift || key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight) {
      activeMods.add('shift');
    }
    if (isMeta || key == LogicalKeyboardKey.metaLeft || key == LogicalKeyboardKey.metaRight) {
      activeMods.add('win');
    }

    // Se pressionou apenas uma tecla modificadora sem outra tecla:
    if (isModifier) {
      return normalize(activeMods.join('+'));
    }

    final keyLabel = _logicalKeyToName(key);
    if (keyLabel == null) return null;

    final parts = [...activeMods, keyLabel];
    return normalize(parts.join('+'));
  }

  static bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.capsLock;
  }

  static String? _logicalKeyToName(LogicalKeyboardKey key) {
    // Teclas de função F1..F24
    for (int i = 1; i <= 24; i++) {
      if (key.keyId == LogicalKeyboardKey.f1.keyId + (i - 1)) {
        return 'f$i';
      }
    }

    // Teclas especiais
    if (key == LogicalKeyboardKey.escape) return 'esc';
    if (key == LogicalKeyboardKey.enter) return 'enter';
    if (key == LogicalKeyboardKey.tab) return 'tab';
    if (key == LogicalKeyboardKey.backspace) return 'backspace';
    if (key == LogicalKeyboardKey.delete) return 'del';
    if (key == LogicalKeyboardKey.insert) return 'ins';
    if (key == LogicalKeyboardKey.space) return 'space';
    if (key == LogicalKeyboardKey.pageUp) return 'pageup';
    if (key == LogicalKeyboardKey.pageDown) return 'pagedown';
    if (key == LogicalKeyboardKey.home) return 'home';
    if (key == LogicalKeyboardKey.end) return 'end';
    if (key == LogicalKeyboardKey.arrowUp) return 'up';
    if (key == LogicalKeyboardKey.arrowDown) return 'down';
    if (key == LogicalKeyboardKey.arrowLeft) return 'left';
    if (key == LogicalKeyboardKey.arrowRight) return 'right';
    if (key == LogicalKeyboardKey.printScreen) return 'print';

    // Letras A-Z
    final keyLabel = key.keyLabel.trim().toLowerCase();
    if (keyLabel.length == 1) {
      return keyLabel;
    }

    return null;
  }
}
