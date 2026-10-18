import 'dart:convert';
import 'dart:io';
import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

class FakeKeySender implements KeySender {
  final receivedCombos = <String>[];

  @override
  Future<bool> send(String combo) async {
    receivedCombos.add(combo);
    return true;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  final goldenRaw = File('test/fixtures/layout_golden.json').readAsStringSync();
  final golden = jsonDecode(goldenRaw) as Map<String, dynamic>;

  group('contrato do layout', () {
    test('round-trip byte a byte, ordem de chaves incluida', () {
      final layout = Layout.fromJson(golden);
      expect(jsonEncode(layout.toPublishJson()), equals(jsonEncode(golden)));
    });

    test('toPublishJson tem exatamente 3 chaves de topo', () {
      final json = Layout.fromJson(golden).toPublishJson();
      expect(json.keys.toList(), equals(['deviceName', 'theme', 'pages']));
    });

    test('bindings NUNCA vazam para o payload publicado', () {
      final layout = Layout.fromJson(golden).setBindingLegacy(
          'open_vscode', ['code']).setBindingLegacy('open_terminal', ['kitty']);

      final published = jsonEncode(layout.toPublishJson());
      expect(published.contains('"bindings"'), isFalse);
      expect(published.contains('"code"'), isFalse);
      expect(published.contains('"kitty"'), isFalse);
      expect(published, equals(jsonEncode(golden)));

      expect(
          layout.toDiskJson()['bindings'],
          equals({
            'open_vscode': [
              ['code']
            ],
            'open_terminal': [
              ['kitty']
            ]
          }));
    });

    test('disco -> memoria -> disco preserva bindings', () {
      final original = Layout.fromJson(golden)
          .setBindingLegacy('open_vscode', ['code', '--new-window']);
      final round = Layout.fromJson(original.toDiskJson());
      expect(
          round.bindingFor('open_vscode'),
          equals([
            ['code', '--new-window']
          ]));
      expect(round, equals(original));
    });

    test(
        'bindings antigos (lista de strings) migram para formato novo no parsing',
        () {
      final json = {
        'deviceName': 'PC',
        'theme': {
          'bgColor': '#000000',
          'cardColor': '#111111',
          'accentColor': '#222222'
        },
        'pages': {},
        'bindings': {
          'act': ['echo', 'old']
        }
      };
      final layout = Layout.fromJson(json);
      expect(
          layout.bindingFor('act'),
          equals([
            ['echo', 'old']
          ]));
    });

    test('bindings novos com N comandos round-trip', () {
      final layout = Layout.initial('PC').setBinding('act', [
        ['echo', '1'],
        ['echo', '2']
      ]);
      final round = Layout.fromJson(layout.toDiskJson());
      expect(
          round.bindingFor('act'),
          equals([
            ['echo', '1'],
            ['echo', '2']
          ]));
    });

    test('limite de 10 comandos é aplicado no fromJson', () {
      final cmds = List.generate(15, (i) => ['cmd', '$i']);
      final json = {
        'deviceName': 'PC',
        'theme': {
          'bgColor': '#000000',
          'cardColor': '#111111',
          'accentColor': '#222222'
        },
        'pages': {},
        'bindings': {'act': cmds}
      };
      final layout = Layout.fromJson(json);
      expect(layout.bindingFor('act')!.length, equals(10));
    });

    test('setBinding com lista vazia remove a chave', () {
      var layout = Layout.initial('PC').setBinding('act', [
        ['cmd']
      ]);
      expect(layout.bindings.containsKey('act'), isTrue);
      layout = layout.setBinding('act', []);
      expect(layout.bindings.containsKey('act'), isFalse);
    });

    test('setBinding remove comandos internos vazios', () {
      final layout = Layout.initial('PC').setBinding('act', [
        ['cmd'],
        [],
        ['cmd2']
      ]);
      expect(
          layout.bindingFor('act'),
          equals([
            ['cmd'],
            ['cmd2']
          ]));
    });

    test('testChain para no primeiro erro', () async {
      final disp = CommandDispatcher(
        audio: UnsupportedAudioController(),
        brightness: UnsupportedBrightnessController(),
        media: MediaService(),
        keySender: FakeKeySender(),
        layoutProvider: () => Layout.initial(''),
      );

      // `echo` existe em qualquer SO (via cmd no Windows, nativo no Linux).
      final okCmd = Platform.isWindows
          ? ['cmd', '/c', 'echo', 'ok']
          : ['echo', 'ok'];

      final res = await disp.testChain([
        okCmd,
        ['comando_que_nao_existe_jamais_xyz123'],
        okCmd,
      ]);

      expect(res.length, equals(2));
      expect(res[1].ok, isFalse);
    });

    test('mesmo id em paginas diferentes e valido (é a mesma acao)', () {
      final ids = Layout.fromJson(golden)
          .pages
          .values
          .expand((l) => l)
          .map((t) => t.id)
          .toList();
      expect(ids.where((i) => i == 'next').length, equals(2));
      expect(
        Layout.fromJson(golden)
            .validate()
            .where((i) => i.level == IssueLevel.error),
        isEmpty,
      );
    });

    test('SliderTile com brightness preserva source no round-trip', () {
      final layout = Layout.initial('PC').upsertTile(
          'home',
          const SliderTile(
            id: 'brilho_1',
            icon: '☀️',
            label: 'Brilho HDMI',
            source: SliderSource(
              kind: SliderSource.kindBrightness,
              match: 'card1-HDMI-A-1',
            ),
          ));
      final back = Layout.fromJson(layout.toPublishJson());
      final tile = back.tilesOf('home').whereType<SliderTile>().first;
      expect(tile.source.kind, equals(SliderSource.kindBrightness));
      expect(tile.source.match, equals('card1-HDMI-A-1'));
    });

    test('SliderSource brightness sem match é válido (aplica em todos)', () {
      final src = SliderSource(kind: SliderSource.kindBrightness);
      expect(src.match, isNull);
      final json = src.toJson();
      expect(json['kind'], equals('brightness'));
      expect(json.containsKey('match'), isFalse);
    });

    test('binding __sendkeys__ é reconhecido sem Process.start', () async {
      final fakeSender = FakeKeySender();
      final layout = Layout.initial('PC').setBinding('test_keys', [
        ['__sendkeys__', 'ctrl+shift+s']
      ]);

      final disp = CommandDispatcher(
        audio: UnsupportedAudioController(),
        brightness: UnsupportedBrightnessController(),
        media: MediaService(),
        keySender: fakeSender,
        layoutProvider: () => layout,
      );

      final result = await disp.runShortcut('test_keys');

      expect(result, isTrue);
      expect(fakeSender.receivedCombos, equals(['ctrl+shift+s']));
    });

    test('WindowsKeySender normaliza tecla Windows para lwin e alias comuns', () {
      expect(WindowsKeySender.normalizeCombo('win+tab'), equals('lwin+tab'));
      expect(WindowsKeySender.normalizeCombo('windows+tab'), equals('lwin+tab'));
      expect(WindowsKeySender.normalizeCombo('win+d'), equals('lwin+d'));
      expect(WindowsKeySender.normalizeCombo('super+tab'), equals('lwin+tab'));
      expect(WindowsKeySender.normalizeCombo('meta+e'), equals('lwin+e'));
      expect(WindowsKeySender.normalizeCombo('win'), equals('lwin'));
      expect(WindowsKeySender.normalizeCombo('rightwin+l'), equals('rwin+l'));
      expect(WindowsKeySender.normalizeCombo('ctrl+shift+esc'), equals('ctrl+shift+esc'));
      expect(WindowsKeySender.normalizeCombo('control+alt+del'), equals('ctrl+alt+delete'));
      expect(WindowsKeySender.normalizeCombo('space'), equals('spc'));
    });

    test('LinuxKeySender normaliza tecla Windows para Super_L e keysyms do xdotool', () {
      expect(LinuxKeySender.normalizeCombo('win+tab'), equals('Super_L+Tab'));
      expect(LinuxKeySender.normalizeCombo('windows+d'), equals('Super_L+d'));
      expect(LinuxKeySender.normalizeCombo('super+e'), equals('Super_L+e'));
      expect(LinuxKeySender.normalizeCombo('ctrl+shift+esc'), equals('ctrl+shift+Escape'));
      expect(LinuxKeySender.normalizeCombo('alt+f4'), equals('alt+F4'));
      expect(LinuxKeySender.normalizeCombo('f11'), equals('F11'));
      expect(LinuxKeySender.normalizeCombo('space'), equals('space'));
    });

    test('replaceTile substitui in-place e migra bindings ao alterar id', () {
      final initial = Layout(
        deviceName: 'PC',
        theme: HubTheme.fallback,
        pages: const {
          'home': [
            ShortcutTile(id: 'tile_1', icon: '1️⃣', label: 'Um'),
            ShortcutTile(id: 'tile_2', icon: '2️⃣', label: 'Dois'),
            ShortcutTile(id: 'tile_3', icon: '3️⃣', label: 'Tres'),
          ],
        },
      ).setBinding('tile_2', [
        ['echo', 'hello']
      ]);

      // Substitui tile_2 por tile_renamed
      final updated = initial.replaceTile(
        'home',
        'tile_2',
        const ShortcutTile(id: 'tile_renamed', icon: '⭐', label: 'Dois Editado'),
      );

      final tiles = updated.tilesOf('home');
      // Deve manter exatamente 3 tiles e a ordem 1 -> 2 -> 3
      expect(tiles.length, equals(3));
      expect(tiles[0].id, equals('tile_1'));
      expect(tiles[1].id, equals('tile_renamed'));
      expect(tiles[1].label, equals('Dois Editado'));
      expect(tiles[2].id, equals('tile_3'));

      // O binding do id antigo deve ter sido migrado para o novo id
      expect(updated.bindingFor('tile_2'), isNull);
      expect(updated.bindingFor('tile_renamed'), equals([['echo', 'hello']]));
    });
  });

  group('payloads auxiliares', () {
    test('audio/volume e int 0-100, chave unica', () {
      const v = MasterVolume(value: 45, muted: true);
      expect(v.toJson(), equals({'value': 45}));
    });
  });
}
