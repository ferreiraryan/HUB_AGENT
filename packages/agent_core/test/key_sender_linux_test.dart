// packages/agent_core/test/key_sender_linux_test.dart

import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('LinuxKeySender - buildWtypeArgs', () {
    test('converte modificadores múltiplos e tecla para ordem correta e liberação LIFO', () {
      final args = LinuxKeySender.buildWtypeArgs('ctrl+shift+s');
      expect(
        args,
        equals(['-M', 'ctrl', '-M', 'shift', '-k', 's', '-m', 'shift', '-m', 'ctrl']),
      );
    });

    test('converte tecla Windows e aliases para "win"', () {
      expect(
        LinuxKeySender.buildWtypeArgs('win+d'),
        equals(['-M', 'win', '-k', 'd', '-m', 'win']),
      );
      expect(
        LinuxKeySender.buildWtypeArgs('super+tab'),
        equals(['-M', 'win', '-k', 'Tab', '-m', 'win']),
      );
      expect(
        LinuxKeySender.buildWtypeArgs('meta+e'),
        equals(['-M', 'win', '-k', 'e', '-m', 'win']),
      );
      expect(
        LinuxKeySender.buildWtypeArgs('cmd+r'),
        equals(['-M', 'win', '-k', 'r', '-m', 'win']),
      );
    });

    test('converte atalhos clássicos (Alt+F4, Ctrl+Shift+Esc)', () {
      expect(
        LinuxKeySender.buildWtypeArgs('alt+f4'),
        equals(['-M', 'alt', '-k', 'F4', '-m', 'alt']),
      );
      expect(
        LinuxKeySender.buildWtypeArgs('ctrl+shift+esc'),
        equals(['-M', 'ctrl', '-M', 'shift', '-k', 'Escape', '-m', 'shift', '-m', 'ctrl']),
      );
    });

    test('converte teclas de função simples (F1 até F24)', () {
      expect(LinuxKeySender.buildWtypeArgs('f11'), equals(['-k', 'F11']));
      expect(LinuxKeySender.buildWtypeArgs('f1'), equals(['-k', 'F1']));
      expect(LinuxKeySender.buildWtypeArgs('f24'), equals(['-k', 'F24']));
    });

    test('converte aliases comuns de teclas especiais (enter, esc, del, space, backspace)', () {
      expect(
        LinuxKeySender.buildWtypeArgs('ctrl+enter'),
        equals(['-M', 'ctrl', '-k', 'Return', '-m', 'ctrl']),
      );
      expect(
        LinuxKeySender.buildWtypeArgs('ctrl+del'),
        equals(['-M', 'ctrl', '-k', 'Delete', '-m', 'ctrl']),
      );
      expect(
        LinuxKeySender.buildWtypeArgs('ctrl+space'),
        equals(['-M', 'ctrl', '-k', 'space', '-m', 'ctrl']),
      );
      expect(
        LinuxKeySender.buildWtypeArgs('ctrl+backspace'),
        equals(['-M', 'ctrl', '-k', 'BackSpace', '-m', 'ctrl']),
      );
    });

    test('converte comandos de mídia para keysyms XF86', () {
      expect(LinuxKeySender.buildWtypeArgs('play_pause'), equals(['-k', 'XF86AudioPlay']));
      expect(LinuxKeySender.buildWtypeArgs('media_play_pause'), equals(['-k', 'XF86AudioPlay']));
      expect(LinuxKeySender.buildWtypeArgs('media_next'), equals(['-k', 'XF86AudioNext']));
      expect(LinuxKeySender.buildWtypeArgs('media_prev'), equals(['-k', 'XF86AudioPrev']));
      expect(LinuxKeySender.buildWtypeArgs('media_stop'), equals(['-k', 'XF86AudioStop']));
      expect(LinuxKeySender.buildWtypeArgs('volume_up'), equals(['-k', 'XF86AudioRaiseVolume']));
      expect(LinuxKeySender.buildWtypeArgs('volume_down'), equals(['-k', 'XF86AudioLowerVolume']));
      expect(LinuxKeySender.buildWtypeArgs('volume_mute'), equals(['-k', 'XF86AudioMute']));
    });

    test('trata modificadores isolados enviando o keysym correspondente', () {
      expect(LinuxKeySender.buildWtypeArgs('win'), equals(['-k', 'Super_L']));
      expect(LinuxKeySender.buildWtypeArgs('super'), equals(['-k', 'Super_L']));
      expect(LinuxKeySender.buildWtypeArgs('ctrl'), equals(['-k', 'Control_L']));
      expect(LinuxKeySender.buildWtypeArgs('alt'), equals(['-k', 'Alt_L']));
      expect(LinuxKeySender.buildWtypeArgs('shift'), equals(['-k', 'Shift_L']));
    });

    test('rejeita combos vazios ou inválidos', () {
      expect(LinuxKeySender.buildWtypeArgs(''), isNull);
      expect(LinuxKeySender.buildWtypeArgs('   '), isNull);
      expect(LinuxKeySender.buildWtypeArgs('+++'), isNull);
      // Mais de uma tecla primária
      expect(LinuxKeySender.buildWtypeArgs('ctrl+a+b'), isNull);
    });
  });

  group('LinuxKeySender - buildYdotoolArgs', () {
    test('converte ctrl+shift+s para eventos de scancode do kernel', () {
      final args = LinuxKeySender.buildYdotoolArgs('ctrl+shift+s');
      expect(args, equals(['key', '29:1', '42:1', '31:1', '31:0', '42:0', '29:0']));
    });

    test('converte win+d para scancode 125 e 32', () {
      final args = LinuxKeySender.buildYdotoolArgs('win+d');
      expect(args, equals(['key', '125:1', '32:1', '32:0', '125:0']));
    });

    test('converte play_pause para scancode 164', () {
      final args = LinuxKeySender.buildYdotoolArgs('play_pause');
      expect(args, equals(['key', '164:1', '164:0']));
    });
  });

  group('LinuxKeySender - Detecção de backend e execução com mock', () {
    test('em Wayland com wtype disponível: seleciona wtype e executa com sucesso', () async {
      final executed = <String>[];

      final sender = LinuxKeySender(
        environment: {'WAYLAND_DISPLAY': 'wayland-1'},
        runner: (exe, args, {bool? runInShell}) async {
          executed.add('$exe ${args.join(' ')}');
          if (exe == 'which' && args.first == 'wtype') {
            return ProcessResult(1, 0, '/usr/bin/wtype\n', '');
          }
          if (exe == 'wtype') {
            return ProcessResult(2, 0, '', '');
          }
          return ProcessResult(3, 1, '', 'not found');
        },
      );

      final backend = await sender.detectedBackend;
      expect(backend, equals(LinuxKeyBackend.wtype));

      final success = await sender.send('ctrl+shift+s');
      expect(success, isTrue);
      expect(
        executed,
        contains('wtype -M ctrl -M shift -k s -m shift -m ctrl'),
      );
    });

    test('em Wayland sem wtype mas com ydotool: faz fallback para ydotool', () async {
      final executed = <String>[];

      final sender = LinuxKeySender(
        environment: {'WAYLAND_DISPLAY': 'wayland-1'},
        runner: (exe, args, {bool? runInShell}) async {
          executed.add('$exe ${args.join(' ')}');
          if (exe == 'which' && args.first == 'wtype') {
            return ProcessResult(1, 1, '', 'wtype not found');
          }
          if (exe == 'which' && args.first == 'ydotool') {
            return ProcessResult(2, 0, '/usr/bin/ydotool\n', '');
          }
          if (exe == 'ydotool') {
            return ProcessResult(3, 0, '', '');
          }
          return ProcessResult(4, 1, '', '');
        },
      );

      final backend = await sender.detectedBackend;
      expect(backend, equals(LinuxKeyBackend.ydotool));

      final success = await sender.send('win+d');
      expect(success, isTrue);
      expect(executed, contains('ydotool key 125:1 32:1 32:0 125:0'));
    });

    test('em X11 puro com xdotool disponível: seleciona xdotool', () async {
      final executed = <String>[];

      final sender = LinuxKeySender(
        environment: {'WAYLAND_DISPLAY': '', 'DISPLAY': ':0'},
        runner: (exe, args, {bool? runInShell}) async {
          executed.add('$exe ${args.join(' ')}');
          if (exe == 'which' && args.first == 'xdotool') {
            return ProcessResult(1, 0, '/usr/bin/xdotool\n', '');
          }
          if (exe == 'xdotool') {
            return ProcessResult(2, 0, '', '');
          }
          return ProcessResult(3, 1, '', '');
        },
      );

      final backend = await sender.detectedBackend;
      expect(backend, equals(LinuxKeyBackend.xdotool));

      final success = await sender.send('alt+f4');
      expect(success, isTrue);
      expect(executed, contains('xdotool key alt+F4'));
    });

    test('quando nenhuma ferramenta está disponível: retorna false e backend none', () async {
      final sender = LinuxKeySender(
        environment: {'WAYLAND_DISPLAY': 'wayland-1'},
        runner: (exe, args, {bool? runInShell}) async {
          return ProcessResult(1, 1, '', 'not found');
        },
      );

      final backend = await sender.detectedBackend;
      expect(backend, equals(LinuxKeyBackend.none));

      final success = await sender.send('ctrl+shift+s');
      expect(success, isFalse);
    });

    test('quando a execução do processo falha com exit code != 0: retorna false', () async {
      final sender = LinuxKeySender(
        environment: {'WAYLAND_DISPLAY': 'wayland-1'},
        runner: (exe, args, {bool? runInShell}) async {
          if (exe == 'which') return ProcessResult(1, 0, '', '');
          return ProcessResult(2, 1, '', 'execution error');
        },
      );

      final success = await sender.send('ctrl+shift+s');
      expect(success, isFalse);
    });

    test('em ambiente de sistema real se wtype estiver disponível: executa tecla com sucesso', () async {
      final sender = LinuxKeySender();
      final backend = await sender.detectedBackend;
      if (backend == LinuxKeyBackend.wtype) {
        final ok = await sender.send('shift');
        expect(ok, isTrue);
      }
    });
  });
}
