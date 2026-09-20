import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

/// A cerca do projeto. Se alguem renomear campo, mudar ordem de chave ou
/// vazar um campo que o dashboard nao espera, quebra aqui — nao no tablet.
void main() {
  final goldenRaw = File('test/fixtures/layout_golden.json').readAsStringSync();
  final golden = jsonDecode(goldenRaw) as Map<String, dynamic>;

  group('contrato do layout', () {
    test('round-trip byte a byte, ordem de chaves incluida', () {
      final layout = Layout.fromJson(golden);
      // jsonEncode respeita ordem de insercao; comparar as formas compactas
      // verifica estrutura E ordem de uma vez so.
      expect(jsonEncode(layout.toPublishJson()), equals(jsonEncode(golden)));
    });

    test('toPublishJson tem exatamente 3 chaves de topo', () {
      final json = Layout.fromJson(golden).toPublishJson();
      expect(json.keys.toList(), equals(['deviceName', 'theme', 'pages']));
    });

    test('bindings NUNCA vazam para o payload publicado', () {
      final layout = Layout.fromJson(golden).setBinding(
          'open_vscode', ['code']).setBinding('open_terminal', ['kitty']);

      final published = jsonEncode(layout.toPublishJson());
      expect(published.contains('"bindings"'), isFalse);
      expect(published.contains('"code"'), isFalse);
      expect(published.contains('"kitty"'), isFalse);
      // e o publicado continua identico ao golden
      expect(published, equals(jsonEncode(golden)));

      // ja no disco, os bindings estao la
      expect(
          layout.toDiskJson()['bindings'],
          equals({
            'open_vscode': ['code'],
            'open_terminal': ['kitty']
          }));
    });

    test('disco -> memoria -> disco preserva bindings', () {
      final original = Layout.fromJson(golden)
          .setBinding('open_vscode', ['code', '--new-window']);
      final round = Layout.fromJson(original.toDiskJson());
      expect(round.bindingFor('open_vscode'), equals(['code', '--new-window']));
      expect(round, equals(original));
    });

    test('tema tem exatamente 3 cores, em hex minusculo', () {
      final theme = Layout.fromJson(golden).theme;
      expect(theme.toJson().keys.toList(),
          equals(['bgColor', 'cardColor', 'accentColor']));
      expect(theme.toJson()['accentColor'], equals('#cba6f7'));
      expect(theme.toJson().containsKey('borderRadius'), isFalse);
    });

    test('shortcut nao emite cmd nem target', () {
      final t = Layout.fromJson(golden)
          .tilesOf('home')
          .whereType<ShortcutTile>()
          .first
          .toJson();
      expect(t.keys.toList(), equals(['type', 'id', 'icon', 'label']));
    });

    test('folder emite target na ultima posicao', () {
      final t = Layout.fromJson(golden)
          .tilesOf('home')
          .whereType<FolderTile>()
          .first
          .toJson();
      expect(
          t.keys.toList(), equals(['type', 'id', 'icon', 'label', 'target']));
    });

    test('type omitido vira shortcut', () {
      final t = Tile.fromJson({'id': 'x', 'icon': 'A', 'label': 'X'});
      expect(t, isA<ShortcutTile>());
      expect(t.toJson()['type'], equals('shortcut'));
    });

    test('type desconhecido falha alto', () {
      expect(() => Tile.fromJson({'type': 'widget', 'id': 'x'}),
          throwsA(isA<FormatException>()));
    });

    test('home sai primeiro mesmo inserida por ultimo', () {
      final base = Layout.fromJson(golden);
      final shuffled = Layout(
        deviceName: base.deviceName,
        theme: base.theme,
        pages: {
          'dev': base.tilesOf('dev'),
          'media': base.tilesOf('media'),
          'home': base.tilesOf('home'),
        },
      );
      expect((shuffled.toPublishJson()['pages'] as Map).keys.first,
          equals('home'));
    });

    test('mesmo id em paginas diferentes e valido (é a mesma acao)', () {
      // "next" aparece na home e em media no golden.
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
      expect(v.toJson()['value'], isA<int>());
      expect(v.toJson().containsKey('muted'), isFalse);
    });

    test('audio/apps segue {id, name, volume} nessa ordem', () {
      const a = AppVolume(id: '12', name: 'Firefox', volume: 80);
      expect(a.toJson().keys.toList(), equals(['id', 'name', 'volume']));
      expect(jsonEncode([a.toJson()]),
          equals('[{"id":"12","name":"Firefox","volume":80}]'));
    });

    test('media segue {status, title, artist}', () {
      const m = MediaState(
          status: PlaybackStatus.playing, title: 'Song', artist: 'Band');
      expect(m.toJson().keys.toList(), equals(['status', 'title', 'artist']));
      expect(m.toJson()['status'], equals('Playing'));
    });

    test('media sem player vira Stopped com campos vazios', () {
      expect(MediaState.idle.toJson(),
          equals({'status': 'Stopped', 'title': '', 'artist': ''}));
      expect(PlaybackStatus.parse(null), equals(PlaybackStatus.stopped));
      expect(PlaybackStatus.parse('No players found'),
          equals(PlaybackStatus.stopped));
    });
  });

  group('topicos', () {
    const t = AgentTopics('meu-pc');
    test('prefixo nodes/{deviceId}', () {
      expect(t.status, equals('nodes/meu-pc/status'));
      expect(t.layout, equals('nodes/meu-pc/layout'));
      expect(t.volume, equals('nodes/meu-pc/audio/volume'));
      expect(t.apps, equals('nodes/meu-pc/audio/apps'));
      expect(t.media, equals('nodes/meu-pc/media'));
      expect(t.cmd, equals('nodes/meu-pc/cmd'));
    });
  });

  group('parse de comando', () {
    test('value float do tablet e arredondado para int', () {
      final c = AgentCommand.tryParse('{"action":"set_volume","value":42.6}');
      expect(c!.value, equals(43));
    });

    test('set_app_volume carrega app_id', () {
      final c = AgentCommand.tryParse(
          '{"action":"set_app_volume","app_id":"12","value":30}');
      expect(c!.appId, equals('12'));
      expect(c.value, equals(30));
    });

    test('payload sem action e descartado', () {
      expect(AgentCommand.tryParse('{"value":10}'), isNull);
      expect(AgentCommand.tryParse('nao e json'), isNull);
    });
  });

  group('validacao', () {
    test('golden sem bindings avisa shortcuts sem comando', () {
      final issues = Layout.fromJson(golden).validate();
      // play_pause e next sao embutidas; open_vscode/open_terminal/prev nao.
      final semComando =
          issues.where((i) => i.message.contains('sem comando')).toList();
      expect(semComando.map((i) => i.tileId).toSet(),
          equals({'open_vscode', 'open_terminal'}));
    });

    test('pasta apontando para pagina inexistente e erro', () {
      final broken = Layout.fromJson(golden).upsertTile(
          'home',
          const FolderTile(
              id: 'g', icon: '?', label: 'G', target: 'nao_existe'));
      expect(broken.validate().any((i) => i.level == IssueLevel.error), isTrue);
    });

    test('binding orfao e avisado', () {
      final l = Layout.fromJson(golden).setBinding('id_que_nao_existe', ['ls']);
      expect(l.validate().any((i) => i.message.contains('orfao')), isTrue);
    });
  });
}
