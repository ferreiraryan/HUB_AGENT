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

class FakeSoundController implements SoundController {
  final List<String> playedSounds = [];
  int stopCalls = 0;
  final _controller = StreamController<SoundPlaybackState>.broadcast();
  SoundPlaybackState _current = SoundPlaybackState.idle;

  @override
  SoundPlaybackState get current => _current;

  @override
  Stream<SoundPlaybackState> get stateChanges => _controller.stream;

  @override
  Future<void> play(String soundId, {String? targetDevice}) async {
    playedSounds.add(soundId);
    _current = SoundPlaybackState.playing(soundId);
    _controller.add(_current);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _current = SoundPlaybackState.idle;
    _controller.add(_current);
  }

  @override
  Future<List<AudioOutputDevice>> listDevices() async => [
        const AudioOutputDevice(id: 'dev_1', name: 'Virtual Cable', isDefault: true),
      ];

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class FakeKeySender implements KeySender {
  @override
  Future<bool> send(String combo) async => true;

  @override
  Future<void> dispose() async {}
}

void main() {
  group('Sound Pad (Etapa 2: Motor de Audio e Controller)', () {
    test('AudioOutputDevice serializa e desserializa corretamente', () {
      const device = AudioOutputDevice(
        id: '{0.0.0.0}.{123}',
        name: 'CABLE Input (VB-Audio Virtual Cable)',
        isDefault: true,
      );

      final json = device.toJson();
      expect(json, equals({
        'id': '{0.0.0.0}.{123}',
        'name': 'CABLE Input (VB-Audio Virtual Cable)',
        'is_default': true,
      }));

      final parsed = AudioOutputDevice.fromJson(json);
      expect(parsed, equals(device));
    });

    test('CommandDispatcher despacha play_sound e stop_sound para SoundController', () async {
      final fakeSound = FakeSoundController();
      final dispatcher = CommandDispatcher(
        audio: MockAudioController(),
        brightness: UnsupportedBrightnessController(),
        media: MediaService(),
        keySender: FakeKeySender(),
        sound: fakeSound,
        layoutProvider: () => Layout.initial('PC'),
      );

      await dispatcher.dispatch(const AgentCommand('play_sound', {'sound_id': 'horn_fx'}));
      expect(fakeSound.playedSounds, equals(['horn_fx']));
      expect(fakeSound.current.isPlaying, isTrue);

      await dispatcher.dispatch(const AgentCommand('stop_sound', {}));
      expect(fakeSound.stopCalls, equals(1));
      expect(fakeSound.current.isPlaying, isFalse);
    });

    test('CommandDispatcher despacha acao direta correspondente a SoundTile no layout', () async {
      final fakeSound = FakeSoundController();
      final layout = Layout(
        deviceName: 'PC',
        theme: HubTheme.fallback,
        pages: const {
          'home': [
            SoundTile(
              id: 'btn_applause',
              icon: '👏',
              label: 'Palmas',
              soundId: 'applause_wav',
            ),
          ],
        },
      );

      final dispatcher = CommandDispatcher(
        audio: MockAudioController(),
        brightness: UnsupportedBrightnessController(),
        media: MediaService(),
        keySender: FakeKeySender(),
        sound: fakeSound,
        layoutProvider: () => layout,
      );

      // Tablet clicou no tile 'btn_applause'
      await dispatcher.dispatch(const AgentCommand('btn_applause', {}));
      expect(fakeSound.playedSounds, equals(['applause_wav']));
    });

    test('SystemSoundController ignora reproducao de som inexistente sem erro', () async {
      final tempDir = Directory.systemTemp.createTempSync('sound_pad_test_');
      try {
        final controller = SystemSoundController(soundsDir: tempDir);
        expect(controller.current, equals(SoundPlaybackState.idle));

        await controller.play('inexistente');
        expect(controller.current, equals(SoundPlaybackState.idle));
        await controller.dispose();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('SystemSoundController listDevices retorna fallback default', () async {
      final tempDir = Directory.systemTemp.createTempSync('sound_pad_test_');
      try {
        final controller = SystemSoundController(
          soundsDir: tempDir,
          customHelperPath: 'caminho_inexistente.exe',
        );
        final devices = await controller.listDevices();
        expect(devices, isNotEmpty);
        expect(devices.first.id, isNotEmpty);
        await controller.dispose();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
