import 'dart:convert';
import 'dart:io';
import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

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
        media: MediaService(),
        layoutProvider: () => Layout.initial(''),
      );

      // Usa binários portáveis básicos garantidos em ambientes comuns
      // ou depende da detecção de falha natural pelo path.
      final res = await disp.testChain([
        ['true'],
        ['comando_que_nao_existe_jamais_xyz123'],
        ['true'],
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
  });

  group('payloads auxiliares', () {
    test('audio/volume e int 0-100, chave unica', () {
      const v = MasterVolume(value: 45, muted: true);
      expect(v.toJson(), equals({'value': 45}));
    });
  });
}
