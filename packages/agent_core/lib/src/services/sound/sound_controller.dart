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
  final void Function(int volume)? onVolumeChanged;

  final _stateController = StreamController<SoundPlaybackState>.broadcast();
  SoundPlaybackState _current = SoundPlaybackState.idle;
  final List<Process> _activeProcesses = [];
  final Map<Process, String> _processToSoundId = {};
  int _playEpoch = 0;
  bool _disposed = false;
  int _volume;
  String? _cachedHelperPath;
  final Map<String, String> _soundFileCache = {};

  SystemSoundController({
    required this.soundsDir,
    this.defaultTargetDeviceProvider,
    this.customHelperPath,
    this.onVolumeChanged,
    int initialVolume = 100,
  }) : _volume = initialVolume.clamp(0, 100);

  @override
  int get volume => _volume;

  @override
  Future<void> setVolume(int value) async {
    final clamped = value.clamp(0, 100);
    final changed = (_volume != clamped);
    _volume = clamped;
    if (changed) {
      onVolumeChanged?.call(_volume);
    }
    if (Platform.isWindows && _activeProcesses.isNotEmpty) {
      final helper = _resolveHelperPath();
      if (helper != null) {
        final procs = List<Process>.from(_activeProcesses);
        for (final p in procs) {
          try {
            await Process.run(
              helper,
              ['set-app', '${p.pid}', '$_volume'],
              runInShell: false,
            );
          } catch (_) {}
        }
      }
    }
  }

  void invalidateSoundCache() {
    _soundFileCache.clear();
  }

  @override
  Stream<SoundPlaybackState> get stateChanges => _stateController.stream;

  @override
  SoundPlaybackState get current => _current;

  String? _findSoundFile(String soundId) {
    if (!soundsDir.existsSync()) return null;

    final cached = _soundFileCache[soundId];
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }

    // Tenta primeiro acesso direto pelas extensões mais comuns sem escanear a pasta
    const extensions = ['.mp3', '.wav', '.ogg', '.flac', '.m4a', '.aac'];
    for (final ext in extensions) {
      final direct = File('${soundsDir.path}/$soundId$ext');
      if (direct.existsSync()) {
        _soundFileCache[soundId] = direct.path;
        return direct.path;
      }
    }

    // Fallback: varre diretório caso tenha extensão arbitrária
    try {
      final entities = soundsDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final filename = entity.uri.pathSegments.last;
          final dotIndex = filename.lastIndexOf('.');
          final base = (dotIndex != -1) ? filename.substring(0, dotIndex) : filename;
          if (base == soundId) {
            _soundFileCache[soundId] = entity.path;
            return entity.path;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String? _resolveHelperPath() {
    if (_cachedHelperPath != null && File(_cachedHelperPath!).existsSync()) {
      return _cachedHelperPath;
    }
    if (customHelperPath != null && File(customHelperPath!).existsSync()) {
      _cachedHelperPath = customHelperPath;
      return _cachedHelperPath;
    }
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir/hub_audio_helper.exe',
      '$exeDir/resources/hub_audio_helper.exe',
      '$exeDir/data/flutter_assets/resources/hub_audio_helper.exe',
      'windows/runner/resources/hub_audio_helper.exe',
      'apps/cms_app/windows/runner/resources/hub_audio_helper.exe',
      '../apps/cms_app/windows/runner/resources/hub_audio_helper.exe',
      '../../apps/cms_app/windows/runner/resources/hub_audio_helper.exe',
      'build/windows/x64/runner/Debug/hub_audio_helper.exe',
      'apps/cms_app/build/windows/x64/runner/Debug/hub_audio_helper.exe',
      '../apps/cms_app/build/windows/x64/runner/Debug/hub_audio_helper.exe',
      '../../apps/cms_app/build/windows/x64/runner/Debug/hub_audio_helper.exe',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) {
        _cachedHelperPath = c;
        return c;
      }
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
    if (_disposed) return;

    final soundFilePath = _findSoundFile(soundId);
    if (soundFilePath == null) {
      stderr.writeln('SoundPad: som com ID "$soundId" não encontrado em ${soundsDir.path}');
      return;
    }

    final currentEpoch = _playEpoch;
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

      // Se durante o spawn assíncrono o stop() foi chamado ou a instância foi descartada:
      if (_disposed || currentEpoch != _playEpoch) {
        try {
          proc.kill();
        } catch (_) {}
        return;
      }

      _activeProcesses.add(proc);
      _processToSoundId[proc] = soundId;
      _current = SoundPlaybackState.playing(soundId);
      _stateController.add(_current);

      void handleExit() {
        final wasInList = _activeProcesses.remove(proc);
        _processToSoundId.remove(proc);
        if (wasInList && !_disposed && !_stateController.isClosed) {
          if (_activeProcesses.isEmpty) {
            _current = SoundPlaybackState.idle;
          } else {
            final latestSoundId = _processToSoundId.values.isNotEmpty
                ? _processToSoundId.values.last
                : null;
            _current = latestSoundId != null
                ? SoundPlaybackState.playing(latestSoundId)
                : SoundPlaybackState.idle;
          }
          _stateController.add(_current);
        }
      }

      proc.exitCode.then((_) => handleExit()).catchError((_) => handleExit());
    } catch (e) {
      stderr.writeln('SoundPad: erro ao iniciar reprodução do som "$soundId": $e');
      if (_activeProcesses.isEmpty && !_disposed && !_stateController.isClosed) {
        _current = SoundPlaybackState.idle;
        _stateController.add(_current);
      }
    }
  }

  @override
  Future<void> stop() async {
    _playEpoch++; // Invalida qualquer processo que ainda esteja iniciando

    final procs = List<Process>.from(_activeProcesses);
    _activeProcesses.clear();
    _processToSoundId.clear();

    for (final proc in procs) {
      try {
        proc.kill();
      } catch (_) {}
    }

    if (_current.isPlaying || procs.isNotEmpty) {
      _current = SoundPlaybackState.idle;
      if (!_stateController.isClosed) {
        _stateController.add(_current);
      }
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _stateController.close();
  }
}

