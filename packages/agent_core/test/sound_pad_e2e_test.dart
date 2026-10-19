import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

class MockAudioController implements AudioController {
  @override
  List<AppVolume> get apps => const [];
  @override
  Stream<List<AppVolume>> get appsChanges => const Stream.empty();
  @override
  Future<void> dispose() async {}
  @override
  bool get isAvailable => true;
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

class FakeKeySender implements KeySender {
  @override
  Future<bool> send(String combo) async => true;
  @override
  Future<void> dispose() async {}
}

class E2ETrackingSoundController implements SoundController {
  final List<String> playHistory = [];
  int stopCalls = 0;
  final _stateController = StreamController<SoundPlaybackState>.broadcast();
  SoundPlaybackState _current = SoundPlaybackState.idle;

  @override
  SoundPlaybackState get current => _current;

  @override
  Stream<SoundPlaybackState> get stateChanges => _stateController.stream;

  @override
  Future<void> play(String soundId, {String? targetDevice}) async {
    // Se já havia som tocando, simula interrupção imediata
    if (_current.isPlaying) {
      stopCalls++;
    }
    playHistory.add(soundId);
    _current = SoundPlaybackState.playing(soundId);
    _stateController.add(_current);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _current = SoundPlaybackState.idle;
    _stateController.add(_current);
  }

  void simulateSoundFinished() {
    _current = SoundPlaybackState.idle;
    _stateController.add(_current);
  }

  @override
  Future<List<AudioOutputDevice>> listDevices() async => [
        const AudioOutputDevice(
          id: '{0.0.0.0}.{virtual_mic}',
          name: 'CABLE Input (VB-Audio Virtual Cable)',
          isDefault: false,
        ),
        const AudioOutputDevice(
          id: '{0.0.0.0}.{default_speakers}',
          name: 'Speakers',
          isDefault: true,
        ),
      ];

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}

void main() {
  group('Sound Pad (Etapa 6: Validacao de Ponta a Ponta e Integracao Final)', () {
    late Directory tempManagedDir;
    late SoundLibraryRepository libraryRepo;
    late E2ETrackingSoundController soundController;

    setUp(() {
      tempManagedDir = Directory.systemTemp.createTempSync('sound_pad_e2e_');
      libraryRepo = SoundLibraryRepository(soundsDir: tempManagedDir);
      soundController = E2ETrackingSoundController();
    });

    tearDown(() async {
      await soundController.dispose();
      if (tempManagedDir.existsSync()) {
        tempManagedDir.deleteSync(recursive: true);
      }
    });

    test('Fluxo completo: Importacao -> Layout Seguro -> Disparo Tablet -> Estado Observavel -> Finalizacao', () async {
      // 1. O usuário importa um som para a biblioteca gerenciada a partir de uma pasta externa (ex: Downloads)
      final externalDir = Directory.systemTemp.createTempSync('external_downloads_');
      try {
        final originalFile = File('${externalDir.path}/vinheta_abertura.wav');
        await originalFile.writeAsString('RIFF... WAVE fake audio stream');

        final soundItem = await libraryRepo.importSound(
          sourceFile: originalFile,
          customName: 'Vinheta de Abertura',
        );

        expect(soundItem.id, equals('vinheta_de_abertura'));
        expect(libraryRepo.getSoundFile('vinheta_de_abertura')?.existsSync(), isTrue);

        // Usuário apaga o arquivo dos Downloads: a biblioteca gerenciada protege o som
        await originalFile.delete();
        expect(libraryRepo.getSoundFile('vinheta_de_abertura')?.existsSync(), isTrue);

        // 2. O CMS cria um Layout com um SoundTile referenciando esse som
        const soundTile = SoundTile(
          id: 'tile_vinheta',
          icon: 'graphic_eq',
          label: 'Vinheta',
          soundId: 'vinheta_de_abertura',
        );

        final layout = Layout(
          deviceName: 'Studio PC',
          theme: HubTheme.fallback,
          pages: const {
            'home': [soundTile],
          },
        );

        // 3. Validação do Contrato de Publicação MQTT (Golden Security Rule)
        final publishedJson = layout.toPublishJson();
        final publishedPages = publishedJson['pages'] as Map<String, dynamic>;
        final publishedHome = publishedPages['home'] as List<dynamic>;
        final publishedTile = publishedHome.first as Map<String, dynamic>;

        expect(publishedTile['type'], equals('sound'));
        expect(publishedTile['sound_id'], equals('vinheta_de_abertura'));
        expect(publishedTile['label'], equals('Vinheta'));
        expect(publishedTile['icon'], equals('graphic_eq'));
        expect(publishedTile.containsKey('bindings'), isFalse);
        expect(publishedTile.containsKey('action'), isFalse);
        expect(publishedTile.containsKey('filePath'), isFalse);

        // 4. O tablet recebe o estado via stream do MQTT
        final stateHistory = <SoundPlaybackState>[];
        final sub = soundController.stateChanges.listen((s) => stateHistory.add(s));

        final dispatcher = CommandDispatcher(
          audio: MockAudioController(),
          brightness: UnsupportedBrightnessController(),
          media: MediaService(),
          keySender: FakeKeySender(),
          sound: soundController,
          layoutProvider: () => layout,
        );

        // 5. Tablet toca no tile da Vinheta -> publica cmd {"action": "play_sound", "sound_id": "vinheta_de_abertura"}
        final tabletCommand = const AgentCommand('play_sound', {
          'sound_id': 'vinheta_de_abertura',
        });
        await dispatcher.dispatch(tabletCommand);

        expect(soundController.playHistory, equals(['vinheta_de_abertura']));
        expect(soundController.current.isPlaying, isTrue);
        expect(soundController.current.soundId, equals('vinheta_de_abertura'));

        // 6. Enquanto toca, o estado é "playing"
        expect(stateHistory.last.isPlaying, isTrue);
        expect(stateHistory.last.soundId, equals('vinheta_de_abertura'));

        // 7. Usuário toca em outro som ("buzzer") enquanto a vinheta ainda está tocando
        await dispatcher.dispatch(const AgentCommand('play_sound', {
          'sound_id': 'buzzer',
        }));

        expect(soundController.playHistory, equals(['vinheta_de_abertura', 'buzzer']));
        expect(soundController.stopCalls, equals(1)); // som anterior interrompido
        expect(soundController.current.soundId, equals('buzzer'));
        expect(stateHistory.last.soundId, equals('buzzer'));

        // 8. O buzzer termina naturalmente -> estado volta para idle automaticamente
        soundController.simulateSoundFinished();
        await pumpEventQueue();
        expect(soundController.current.isPlaying, isFalse);
        expect(soundController.current.soundId, isNull);
        expect(stateHistory.last.isPlaying, isFalse);

        await sub.cancel();
      } finally {
        externalDir.deleteSync(recursive: true);
      }
    });
  });
}
