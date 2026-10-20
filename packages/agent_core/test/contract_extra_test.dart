import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:agent_core/src/services/stats/stats_service.dart';
import 'package:test/test.dart';

void main() {
  group('Contrato de Comandos (AgentCommand)', () {
    test('tryParse rejeita payloads malformados ou incompletos', () {
      expect(AgentCommand.tryParse(''), isNull);
      expect(AgentCommand.tryParse('not json'), isNull);
      expect(AgentCommand.tryParse('[]'), isNull);
      expect(AgentCommand.tryParse('{}'), isNull);
      expect(AgentCommand.tryParse('{"value": 1}'), isNull);
      expect(AgentCommand.tryParse('{"action": ""}'), isNull);
      expect(AgentCommand.tryParse('{"action": 123}'), isNull);
    });

    test('tryParse processa campos numericos, strings e ids', () {
      final cmd1 = AgentCommand.tryParse('{"action": "set_volume", "value": 75}')!;
      expect(cmd1.action, equals('set_volume'));
      expect(cmd1.value, equals(75));

      final cmd2 = AgentCommand.tryParse('{"action": "set_volume", "value": "42"}')!;
      expect(cmd2.value, equals(42));

      final cmd3 = AgentCommand.tryParse('{"action": "set_volume", "value": 39.6}')!;
      expect(cmd3.value, equals(40));

      final cmdApp = AgentCommand.tryParse('{"action": "set_app_volume", "app_id": "spotify", "value": 50}')!;
      expect(cmdApp.appId, equals('spotify'));
      expect(cmdApp.value, equals(50));

      final cmdShortcut = AgentCommand.tryParse('{"action": "run_shortcut", "id": "lock_screen"}')!;
      expect(cmdShortcut.shortcutId, equals('lock_screen'));

      final cmdSlider = AgentCommand.tryParse('{"action": "set_slider", "id": "vol_custom", "value": 80}')!;
      expect(cmdSlider.sliderId, equals('vol_custom'));
      expect(cmdSlider.value, equals(80));

      // Precedência de sound_id sobre id
      final cmdSound1 = AgentCommand.tryParse('{"action": "play_sound", "sound_id": "sound_a", "id": "fallback"}')!;
      expect(cmdSound1.soundId, equals('sound_a'));

      final cmdSound2 = AgentCommand.tryParse('{"action": "play_sound", "id": "sound_b"}')!;
      expect(cmdSound2.soundId, equals('sound_b'));
    });
  });

  group('Contrato de Mídia (MediaState e PlaybackStatus)', () {
    test('PlaybackStatus wire format e parsing', () {
      expect(PlaybackStatus.playing.wire, equals('Playing'));
      expect(PlaybackStatus.paused.wire, equals('Paused'));
      expect(PlaybackStatus.stopped.wire, equals('Stopped'));

      expect(PlaybackStatus.parse('Playing'), equals(PlaybackStatus.playing));
      expect(PlaybackStatus.parse('Paused'), equals(PlaybackStatus.paused));
      expect(PlaybackStatus.parse('Stopped'), equals(PlaybackStatus.stopped));
      expect(PlaybackStatus.parse('unknown'), equals(PlaybackStatus.stopped));
      expect(PlaybackStatus.parse(null), equals(PlaybackStatus.stopped));
    });

    test('MediaState serializa corretamente e preserva idle', () {
      const state = MediaState(
        status: PlaybackStatus.playing,
        title: 'Song Title',
        artist: 'Artist Name',
      );
      final json = state.toJson();
      expect(json, equals({
        'status': 'Playing',
        'title': 'Song Title',
        'artist': 'Artist Name',
      }));
      expect(json.keys.toList(), equals(['status', 'title', 'artist']));

      expect(MediaState.idle.status, equals(PlaybackStatus.stopped));
      expect(MediaState.idle.toJson()['status'], equals('Stopped'));
    });
  });

  group('Payloads Auxiliares (AppVolume e StatsSnapshot)', () {
    test('AppVolume serializa respeitando ordem de chaves', () {
      const app = AppVolume(id: 'sink_1', name: 'Spotify', volume: 65);
      final json = app.toJson();
      expect(json, equals({'id': 'sink_1', 'name': 'Spotify', 'volume': 65}));
      expect(json.keys.toList(), equals(['id', 'name', 'volume']));
    });

    test('StatsSnapshot cpuJson, ramJson e diskJson', () {
      const full = StatsSnapshot(
        cpuLoad: 25,
        cpuTemp: 52,
        cpuFreqMhz: 3600,
        ramUsedMb: 4096,
        ramTotalMb: 16384,
        ramPercent: 25,
        diskMount: '/',
        diskUsedGb: 120,
        diskTotalGb: 500,
        diskPercent: 24,
      );

      expect(full.cpuJson(), equals({
        'load': 25,
        'temp': 52,
        'freq_mhz': 3600,
      }));
      expect(full.ramJson(), equals({
        'used_mb': 4096,
        'total_mb': 16384,
        'percent': 25,
      }));
      expect(full.diskJson(), equals({
        'mount': '/',
        'used_gb': 120,
        'total_gb': 500,
        'percent': 24,
      }));

      // Quando temp e freq são nulos (ex: Windows ou sensor ausente)
      const partial = StatsSnapshot(
        cpuLoad: 10,
        ramUsedMb: 2048,
        ramTotalMb: 8192,
        ramPercent: 25,
        diskMount: 'C:',
        diskUsedGb: 80,
        diskTotalGb: 256,
        diskPercent: 31,
      );
      expect(partial.cpuJson(), equals({'load': 10}));
      expect(partial.cpuJson().containsKey('temp'), isFalse);
      expect(partial.cpuJson().containsKey('freq_mhz'), isFalse);
    });
  });

  group('Tópicos MQTT (AgentTopics)', () {
    test('AgentTopics gera topicos corretos com prefixo padrao e customizado', () {
      const topics = AgentTopics('pc-sala');
      expect(topics.base, equals('nodes/pc-sala'));
      expect(topics.status, equals('nodes/pc-sala/status'));
      expect(topics.layout, equals('nodes/pc-sala/layout'));
      expect(topics.volume, equals('nodes/pc-sala/audio/volume'));
      expect(topics.apps, equals('nodes/pc-sala/audio/apps'));
      expect(topics.media, equals('nodes/pc-sala/media'));
      expect(topics.soundState, equals('nodes/pc-sala/sound/state'));
      expect(topics.cmd, equals('nodes/pc-sala/cmd'));

      const custom = AgentTopics('desk', prefix: 'custom_nodes');
      expect(custom.base, equals('custom_nodes/desk'));
      expect(custom.cmd, equals('custom_nodes/desk/cmd'));
    });
  });

  group('Contrato de Tiles e Round-trip de Tipos', () {
    test('Serializacao e desserializacao de todos os tipos de Tile', () {
      final tiles = <Tile>[
        const ShortcutTile(id: 'sh_1', icon: '🚀', label: 'Launch'),
        const FolderTile(id: 'f_1', icon: '📁', label: 'Folder', target: 'subpage'),
        const BackTile(id: 'b_1', icon: '⬅️', label: 'Voltar'),
        const SliderTile(
          id: 'sl_master',
          icon: '🔊',
          label: 'Master',
          source: SliderSource(kind: SliderSource.kindMasterVolume),
        ),
        const SliderTile(
          id: 'sl_app',
          icon: '🎵',
          label: 'Spotify',
          source: SliderSource(kind: SliderSource.kindAppVolume, match: 'spotify'),
        ),
        const SliderTile(
          id: 'sl_bright',
          icon: '☀️',
          label: 'Brilho',
          source: SliderSource(kind: SliderSource.kindBrightness, match: 'HDMI-1'),
        ),
        const SliderTile(
          id: 'sl_custom',
          icon: '🎚️',
          label: 'Custom',
          source: SliderSource(kind: SliderSource.kindCustom),
        ),
        const StatTile(
          id: 'st_ram',
          icon: '📊',
          label: 'RAM',
          source: StatSource(kind: StatSource.kindRam, field: 'percent', unit: '%'),
        ),
        const SoundTile(id: 'snd_1', icon: '🔔', label: 'Bell', soundId: 'bell_wav'),
      ];

      for (final tile in tiles) {
        final json = tile.toJson();
        final from = Tile.fromJson(json);
        expect(from, equals(tile));
      }
    });

    test('Tile.fromJson e SliderSource.fromJson lancam FormatException para tipo/kind desconhecido', () {
      expect(
        () => Tile.fromJson({'id': 'inv', 'type': 'desconhecido'}),
        throwsFormatException,
      );
      expect(
        () => SliderSource.fromJson({'kind': 'invalido'}),
        throwsFormatException,
      );
      expect(
        () => StatSource.fromJson({'kind': 'invalido'}),
        throwsFormatException,
      );
    });

    test('Layout round-trip completo com todos os tipos de tile em toPublishJson', () {
      final layout = Layout(
        deviceName: 'Workstation',
        theme: HubTheme.fallback,
        pages: {
          'home': [
            const BackTile(id: 'b1', icon: '⬅️', label: 'Voltar'),
            const SliderTile(
              id: 's_vol',
              icon: '🔊',
              label: 'Master',
              source: SliderSource(kind: SliderSource.kindMasterVolume),
            ),
            const StatTile(
              id: 's_cpu',
              icon: '💻',
              label: 'CPU',
              source: StatSource(kind: StatSource.kindCpu, field: 'load', unit: '%'),
            ),
            const SoundTile(id: 's_sound', icon: '🔔', label: 'Sound', soundId: 'sound_1'),
          ],
        },
      );

      final published = layout.toPublishJson();
      final recovered = Layout.fromJson(published);
      expect(jsonEncode(recovered.toPublishJson()), equals(jsonEncode(published)));
    });
  });

  group('Validacao de Layout (Layout.validate)', () {
    test('Valida presenca obrigatoria da pagina home e detecta pagina orfa', () {
      final invalid = const Layout(
        deviceName: 'Test',
        theme: HubTheme.fallback,
        pages: {
          'other': [ShortcutTile(id: 's1', icon: 'x', label: 'Shortcut')],
        },
      );
      final issues = invalid.validate();
      expect(issues.any((i) => i.level == IssueLevel.error && i.message.contains('home')), isTrue);
      expect(issues.any((i) => i.level == IssueLevel.warning && i.message.contains('orfa')), isTrue);
    });

    test('Detecta pasta apontando para pagina inexistente e binding orfao', () {
      final layout = Layout(
        deviceName: 'Test',
        theme: HubTheme.fallback,
        pages: const {
          'home': [
            FolderTile(id: 'f1', icon: '📁', label: 'Missing Target', target: 'inexistente'),
          ],
        },
        bindings: const {
          'orfao': [['ls']],
        },
      );
      final issues = layout.validate();
      expect(issues.any((i) => i.level == IssueLevel.error && i.message.contains('inexistente')), isTrue);
      expect(issues.any((i) => i.level == IssueLevel.warning && i.message.contains('orfao')), isTrue);
    });
  });
  group('Contrato de Eventos Efêmeros e Notificações (AgentEvent e Action Notify)', () {
    test('AgentTopics define o tópico canônico de eventos', () {
      const topics = AgentTopics('pc-main');
      expect(topics.event, equals('nodes/pc-main/event'));
    });

    test('AgentEvent serializa e desserializa corretamente preservando kinds e limites', () {
      final e1 = AgentEvent.info('Som terminado');
      expect(e1.kind, equals(AgentEventKind.info));
      expect(e1.message, equals('Som terminado'));
      expect(e1.durationMs, equals(3000));
      expect(e1.toJson(), equals({'kind': 'info', 'message': 'Som terminado', 'duration': 3000}));

      final e2 = AgentEvent.fromJson({
        'kind': 'warning',
        'message': 'Bateria em 10%',
        'duration': 5000,
      });
      expect(e2.kind, equals(AgentEventKind.warning));
      expect(e2.message, equals('Bateria em 10%'));
      expect(e2.durationMs, equals(5000));

      final eClamp = AgentEvent.fromJson({
        'kind': 'desconhecido',
        'message': 'Teste',
        'duration': 999999,
      });
      expect(eClamp.kind, equals(AgentEventKind.info));
      expect(eClamp.durationMs, equals(15000));

      final eClampMin = AgentEvent.fromJson({
        'message': 'Min',
        'duration': 100,
      });
      expect(eClampMin.durationMs, equals(500));
    });

    test('AgentCommand processa campos de notify', () {
      final cmd = AgentCommand.tryParse(
          '{"action": "notify", "kind": "success", "message": "OBS Gravando", "duration": 4000}')!;
      expect(cmd.action, equals('notify'));
      expect(cmd.kind, equals('success'));
      expect(cmd.message, equals('OBS Gravando'));
      expect(cmd.duration, equals(4000));
    });

    test('CommandDispatcher despacha notify para o callback onEvent', () async {
      final events = <AgentEvent>[];
      final dispatcher = CommandDispatcher(
        audio: _MockAudio(),
        brightness: UnsupportedBrightnessController(),
        media: MediaService(),
        keySender: _FakeKey(),
        layoutProvider: () => const Layout(
          deviceName: 'Test',
          theme: HubTheme.fallback,
          pages: {'home': []},
        ),
        onEvent: events.add,
      );

      final cmd = AgentCommand.tryParse(
          '{"action": "notify", "kind": "error", "message": "Falha na sincronização", "duration": 2500}')!;
      await dispatcher.dispatch(cmd);

      expect(events, hasLength(1));
      expect(events.first.kind, equals(AgentEventKind.error));
      expect(events.first.message, equals('Falha na sincronização'));
      expect(events.first.durationMs, equals(2500));

      final cmdInvalid = AgentCommand.tryParse('{"action": "notify", "kind": "info"}')!;
      await dispatcher.dispatch(cmdInvalid);
      expect(events, hasLength(1));
    });
  });
}

class _MockAudio implements AudioController {
  @override
  List<AppVolume> get apps => const [];
  @override
  Stream<List<AppVolume>> get appsChanges => const Stream.empty();
  @override
  Future<void> dispose() async {}
  @override
  bool get isAvailable => false;
  @override
  MasterVolume get master => const MasterVolume(value: 50);
  @override
  Stream<MasterVolume> get masterChanges => const Stream.empty();
  @override
  Future<void> refresh() async {}
  @override
  Future<void> setAppVolume(String id, int volume) async {}
  @override
  Future<void> setAppVolumeByName(String name, int volume) async {}
  @override
  Future<void> setMasterVolume(int volume) async {}
  @override
  Future<void> setMute(bool muted) async {}
  @override
  Future<void> start() async {}
}

class _FakeKey implements KeySender {
  @override
  Future<bool> send(String combo) async => true;
  @override
  Future<void> dispose() async {}
}
