import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

class _FakeAudio implements AudioController {
  MasterVolume _master = const MasterVolume(value: 50, muted: false);
  final _masterCtl = StreamController<MasterVolume>.broadcast();
  final _appsCtl = StreamController<List<AppVolume>>.broadcast();

  @override
  Stream<MasterVolume> get masterChanges => _masterCtl.stream;
  @override
  Stream<List<AppVolume>> get appsChanges => _appsCtl.stream;
  @override
  MasterVolume get master => _master;
  @override
  List<AppVolume> get apps => const [];
  @override
  bool get isAvailable => true;
  @override
  Future<void> start() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> setMasterVolume(int value) async {
    _master = MasterVolume(value: value.clamp(0, 100), muted: _master.muted);
  }

  @override
  Future<void> setMute(bool muted) async {
    _master = MasterVolume(value: _master.value, muted: muted);
  }

  @override
  Future<void> setAppVolume(String id, int value) async {}
  @override
  Future<void> setAppVolumeByName(String name, int value) async {}
  @override
  Future<void> dispose() async {
    await _masterCtl.close();
    await _appsCtl.close();
  }
}

class _FakeMedia extends MediaService {
  @override
  Future<void> start() async {}
  @override
  Future<void> playPause() async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> seek(int seconds) async {}
  @override
  Future<void> rewind(int seconds) async {}
  @override
  Future<void> fastForward(int seconds) async {}
  @override
  Future<void> setPlaybackRate(double rate) async {}
}

class _FakeKeySender implements KeySender {
  final sent = <String>[];
  @override
  Future<bool> send(String combo) async {
    sent.add(combo);
    return true;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('Layout renamePage & duplicatePage', () {
    test('renamePage atualiza chave da pagina e target de FolderTile', () {
      var layout = Layout.initial('PC')
          .addPage('estudo')
          .upsertTile(
            'home',
            const FolderTile(
              id: 'folder_estudo',
              icon: '📁',
              label: 'Estudo',
              target: 'estudo',
            ),
          )
          .upsertTile(
            'estudo',
            const ShortcutTile(id: 'sc_1', icon: '⚡', label: 'Acao'),
          );

      final renamed = layout.renamePage('estudo', 'estudos_pro');
      expect(renamed.pages.containsKey('estudo'), isFalse);
      expect(renamed.pages.containsKey('estudos_pro'), isTrue);
      expect(renamed.tilesOf('estudos_pro').length, equals(1));

      final folder = renamed.findTile<FolderTile>('folder_estudo');
      expect(folder?.target, equals('estudos_pro'));
    });

    test('renamePage ignora tentativa de renomear home', () {
      final layout = Layout.initial('PC');
      expect(layout.renamePage('home', 'outra'), equals(layout));
    });

    test('duplicatePage clona tiles com IDs unicos e copia bindings', () {
      var layout = Layout.initial('PC')
          .addPage('p1')
          .upsertTile(
            'p1',
            const ShortcutTile(id: 'sc_1', icon: '⚡', label: 'Acao 1'),
          )
          .upsertTile(
            'p1',
            const ToggleTile(
              id: 'tg_1',
              stateA: ToggleStateConfig(icon: '🔴', label: 'Off'),
              stateB: ToggleStateConfig(icon: '🟢', label: 'On'),
            ),
          )
          .setBinding('sc_1', [
            ['__open_url__', 'https://example.com']
          ])
          .setBinding('tg_1:a', [
            ['__delay__', '100']
          ])
          .setBinding('tg_1:b', [
            ['__delay__', '200']
          ]);

      final dup = layout.duplicatePage('p1', 'p2');
      expect(dup.pages.containsKey('p2'), isTrue);
      final p2Tiles = dup.tilesOf('p2');
      expect(p2Tiles.length, equals(2));
      expect(p2Tiles[0].id, isNot(equals('sc_1')));
      expect(p2Tiles[1].id, isNot(equals('tg_1')));
      expect(dup.bindingFor(p2Tiles[0].id), equals([['__open_url__', 'https://example.com']]));
      expect(dup.bindingFor('${p2Tiles[1].id}:a'), equals([['__delay__', '100']]));
      expect(dup.bindingFor('${p2Tiles[1].id}:b'), equals([['__delay__', '200']]));

      // Garante que nenhum binding vaza para toPublishJson
      final pub = dup.toPublishJson().toString();
      expect(pub.contains('example.com'), isFalse);
    });
  });

  group('CommandDispatcher novas macros e builtins', () {
    test('mute_master, vol_up, vol_down e open_cms funcionam', () async {
      final audio = _FakeAudio();
      var cmsOpened = false;
      final events = <AgentEvent>[];

      final dispatcher = CommandDispatcher(
        audio: audio,
        brightness: UnsupportedBrightnessController(),
        media: _FakeMedia(),
        keySender: _FakeKeySender(),
        layoutProvider: () => Layout.initial('PC'),
        onEvent: events.add,
        onOpenCms: () => cmsOpened = true,
      );

      await dispatcher.dispatch(const AgentCommand('vol_up', {'action': 'vol_up'}));
      expect(audio.master.value, equals(55));

      await dispatcher.dispatch(const AgentCommand('vol_down', {'action': 'vol_down'}));
      expect(audio.master.value, equals(50));

      await dispatcher.dispatch(const AgentCommand('mute_master', {'action': 'mute_master'}));
      expect(audio.master.muted, isTrue);
      expect(events.isNotEmpty, isTrue);

      await dispatcher.dispatch(const AgentCommand('open_cms', {'action': 'open_cms'}));
      expect(cmsOpened, isTrue);
    });

    test('__delay__ e __http__ executam corretamente contra servidor local', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? receivedMethod;
      String? receivedBody;
      server.listen((req) async {
        receivedMethod = req.method;
        receivedBody = await utf8.decoder.bind(req).join();
        req.response.statusCode = 200;
        req.response.write('ok');
        await req.response.close();
      });

      try {
        final url = 'http://127.0.0.1:${server.port}/hook';
        final layout = Layout.initial('PC')
            .upsertTile('home', const ShortcutTile(id: 'macro_1', icon: '⚡', label: 'Hook'))
            .setBinding('macro_1', [
          ['__delay__', '20'],
          ['__http__', 'POST', url, '{"ping":true}'],
        ]);

        final dispatcher = CommandDispatcher(
          audio: _FakeAudio(),
          brightness: UnsupportedBrightnessController(),
          media: _FakeMedia(),
          keySender: _FakeKeySender(),
          layoutProvider: () => layout,
        );

        final ok = await dispatcher.runShortcut('macro_1');
        expect(ok, isTrue);
        expect(receivedMethod, equals('POST'));
        expect(receivedBody, equals('{"ping":true}'));
      } finally {
        await server.close(force: true);
      }
    });

    test('test() valida passos especiais sem executar efeitos colaterais', () async {
      final dispatcher = CommandDispatcher(
        audio: _FakeAudio(),
        brightness: UnsupportedBrightnessController(),
        media: _FakeMedia(),
        keySender: _FakeKeySender(),
        layoutProvider: () => Layout.initial('PC'),
      );

      expect((await dispatcher.test(['__delay__', '500'])).ok, isTrue);
      expect((await dispatcher.test(['__delay__', 'abc'])).ok, isFalse);
      expect((await dispatcher.test(['__open_url__', 'https://google.com'])).ok, isTrue);
      expect((await dispatcher.test(['__type_text__', 'hello'])).ok, isTrue);
      expect((await dispatcher.test(['__http__', 'GET', 'http://localhost:8123'])).ok, isTrue);
      expect((await dispatcher.test(['__http__', 'GET', 'ftp://invalid'])).ok, isFalse);
      expect((await dispatcher.test(['__builtin__', 'mute_master'])).ok, isTrue);
    });
  });

  group('Windows helper JSON parsers', () {
    test('WindowsStatsProvider.parseHelperJson analisa stats nativos Win32', () {
      const raw =
          '{"cpu_load":18,"ram_used_mb":8192,"ram_total_mb":16384,"ram_percent":50,"disk_mount":"C:","disk_used_gb":200,"disk_total_gb":500,"disk_percent":40}';
      final snap = WindowsStatsProvider.parseHelperJson(raw);
      expect(snap, isNotNull);
      expect(snap!.cpuLoad, equals(18));
      expect(snap.ramUsedMb, equals(8192));
      expect(snap.ramTotalMb, equals(16384));
      expect(snap.ramPercent, equals(50));
      expect(snap.diskMount, equals('C:'));
      expect(snap.diskUsedGb, equals(200));
      expect(snap.diskTotalGb, equals(500));
      expect(snap.diskPercent, equals(40));
    });

    test('WindowsBrightnessController parsers analisam displays e brilho DDC/CI', () {
      const displaysRaw =
          '[{"number":1,"model":"LG UltraGear","supported":true,"brightness":65},{"number":2,"model":"Unsupported","supported":false,"brightness":-1}]';
      final displays = WindowsBrightnessController.parseDisplaysJson(displaysRaw);
      expect(displays.length, equals(1));
      expect(displays.first.number, equals(1));
      expect(displays.first.model, equals('LG UltraGear'));

      expect(WindowsBrightnessController.parseBrightnessJson('{"value":72}'), equals(72));
      expect(WindowsBrightnessController.parseBrightnessJson('{"value":null}'), isNull);
    });
  });
}
