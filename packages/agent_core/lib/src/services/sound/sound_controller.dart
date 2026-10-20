import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/audio_output_device.dart';
import '../../models/sound_playback_state.dart';

abstract class SoundController {
  Stream<SoundPlaybackState> get stateChanges;
  SoundPlaybackState get current;

  int get volume;
  Future<void> setVolume(int value);

  Future<void> play(String soundId, {String? targetDevice});
  Future<void> stop();
  Future<List<AudioOutputDevice>> listDevices();
  Future<void> dispose();
}

class SystemSoundController implements SoundController {
  final Directory soundsDir;
  final String? Function()? defaultTargetDeviceProvider;
  final String? customHelperPath;

  final _stateController = StreamController<SoundPlaybackState>.broadcast();
  SoundPlaybackState _current = SoundPlaybackState.idle;
  Process? _activeProcess;
  String? _activeSoundId;
  int _volume = 100;

  SystemSoundController({
    required this.soundsDir,
    this.defaultTargetDeviceProvider,
    this.customHelperPath,
  });

  @override
  int get volume => _volume;

  @override
  Future<void> setVolume(int value) async {
    _volume = value.clamp(0, 100);
  }

  @override
  Stream<SoundPlaybackState> get stateChanges => _stateController.stream;

  @override
  SoundPlaybackState get current => _current;

  String? _findSoundFile(String soundId) {
    if (!soundsDir.existsSync()) return null;
    final entities = soundsDir.listSync();
    for (final entity in entities) {
      if (entity is File) {
        final filename = entity.uri.pathSegments.last;
        final dotIndex = filename.lastIndexOf('.');
        final base = (dotIndex != -1) ? filename.substring(0, dotIndex) : filename;
        if (base == soundId) {
          return entity.path;
        }
      }
    }
    return null;
  }

  String? _resolveHelperPath() {
    if (customHelperPath != null && File(customHelperPath!).existsSync()) {
      return customHelperPath;
    }
    final scriptDir = File(Platform.script.toFilePath()).parent.path;
    final candidates = [
      '$scriptDir/hub_audio_helper.exe',
      '$scriptDir/resources/hub_audio_helper.exe',
      '$scriptDir/data/flutter_assets/resources/hub_audio_helper.exe',
      'windows/runner/resources/hub_audio_helper.exe',
      'apps/cms_app/windows/runner/resources/hub_audio_helper.exe',
      '../cms_app/windows/runner/resources/hub_audio_helper.exe',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  @override
  Future<List<AudioOutputDevice>> listDevices() async {
    if (Platform.isWindows) {
      final helper = _resolveHelperPath();
      if (helper != null) {
        try {
          final res = await Process.run(helper, ['list-devices']);
          if (res.exitCode == 0) {
            final jsonList = jsonDecode(res.stdout.toString());
            if (jsonList is List) {
              return jsonList
                  .map((item) => AudioOutputDevice.fromJson(
                      (item as Map).cast<String, dynamic>()))
                  .toList();
            }
          }
        } catch (e) {
          stderr.writeln('Erro ao listar dispositivos de áudio via helper: $e');
        }
      }
    } else if (Platform.isLinux) {
      try {
        final res = await Process.run('pactl', ['list', 'sinks', 'short']);
        if (res.exitCode == 0) {
          final lines = res.stdout.toString().split('\n');
          final list = <AudioOutputDevice>[];
          for (final line in lines) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              list.add(AudioOutputDevice(id: parts[1], name: parts[1]));
            }
          }
          if (list.isNotEmpty) return list;
        }
      } catch (_) {}
    }

    return const [
      AudioOutputDevice(id: 'default', name: 'Dispositivo Padrão do Sistema', isDefault: true)
    ];
  }

  @override
  Future<void> play(String soundId, {String? targetDevice}) async {
    // Se o mesmo som já estiver tocando, para a reprodução (comportamento de toggle do Sound Pad)
    if (_activeSoundId == soundId && _current.isPlaying) {
      await stop();
      return;
    }

    // Se outro som estiver tocando, para o anterior ("um som por vez")
    if (_activeProcess != null) {
      await stop();
    }

    final soundFilePath = _findSoundFile(soundId);
    if (soundFilePath == null) {
      stderr.writeln('SoundPad: som com ID "$soundId" não encontrado em ${soundsDir.path}');
      return;
    }

    final device = targetDevice ?? defaultTargetDeviceProvider?.call();

    try {
      Process proc;
      if (Platform.isWindows) {
        final helper = _resolveHelperPath();
        if (helper != null) {
          final target = (device != null && device.trim().isNotEmpty && device != 'default')
              ? device.trim()
              : 'default';
          final args = ['play-sound', soundFilePath, target, '$_volume'];
          proc = await Process.start(helper, args);
        } else {
          // Fallback para nircmd mediaplay (apenas dispositivo padrão)
          proc = await Process.start('nircmd.exe', ['mediaplay', '60000', soundFilePath]);
        }
      } else if (Platform.isLinux) {
        // Tenta paplay ou pw-play
        final paplayVol = (_volume * 65536 / 100).round().clamp(0, 65536);
        final args = <String>['--volume=$paplayVol'];
        if (device != null && device.trim().isNotEmpty && device != 'default') {
          args.addAll(['-d', device.trim()]);
        }
        args.add(soundFilePath);
        proc = await Process.start('paplay', args);
      } else {
        stderr.writeln('SoundPad: plataforma não suportada para reprodução');
        return;
      }

      _activeProcess = proc;
      _activeSoundId = soundId;
      _current = SoundPlaybackState.playing(soundId);
      _stateController.add(_current);

      proc.exitCode.then((_) {
        // Se ainda for a reprodução deste som, reseta para idle
        if (_activeSoundId == soundId) {
          _activeProcess = null;
          _activeSoundId = null;
          _current = SoundPlaybackState.idle;
          if (!_stateController.isClosed) {
            _stateController.add(_current);
          }
        }
      }).catchError((_) {
        if (_activeSoundId == soundId) {
          _activeProcess = null;
          _activeSoundId = null;
          _current = SoundPlaybackState.idle;
          if (!_stateController.isClosed) {
            _stateController.add(_current);
          }
        }
      });
    } catch (e) {
      stderr.writeln('SoundPad: erro ao iniciar reprodução do som "$soundId": $e');
      _activeProcess = null;
      _activeSoundId = null;
      _current = SoundPlaybackState.idle;
      _stateController.add(_current);
    }
  }

  @override
  Future<void> stop() async {
    final proc = _activeProcess;
    _activeProcess = null;
    _activeSoundId = null;

    if (proc != null) {
      try {
        proc.kill();
      } catch (_) {}
    }

    if (_current.isPlaying) {
      _current = SoundPlaybackState.idle;
      if (!_stateController.isClosed) {
        _stateController.add(_current);
      }
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _stateController.close();
  }
}

