import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/audio_state.dart';
import 'audio_controller.dart';

/// AudioController para Windows via hub_audio_helper.exe (WASAPI nativo)
/// com fallback gracioso para nircmd.exe.
///
/// Utiliza hub_audio_helper.exe para leitura e ajuste em tempo real do volume
/// master e sessões de áudio por aplicativo (inclusive multi-processos como
/// Spotify, Discord, navegadores e jogos).
class WindowsAudioController implements AudioController {
  final _masterCtl = StreamController<MasterVolume>.broadcast();
  final _appsCtl = StreamController<List<AppVolume>>.broadcast();

  Timer? _pollTimer;
  bool _available = false;
  MasterVolume _master = const MasterVolume(value: 0);
  List<AppVolume> _apps = const [];

  /// Caminho do helper nativo WASAPI (hub_audio_helper.exe).
  String? _helperPath;

  /// Caminho de fallback (nircmd.exe).
  String? _nircmdPath;

  @override
  Stream<MasterVolume> get masterChanges => _masterCtl.stream;
  @override
  Stream<List<AppVolume>> get appsChanges => _appsCtl.stream;
  @override
  MasterVolume get master => _master;
  @override
  List<AppVolume> get apps => List.unmodifiable(_apps);
  @override
  bool get isAvailable => _available;

  @override
  Future<void> start() async {
    _helperPath = await _resolveBinaryPath('hub_audio_helper.exe');
    if (_helperPath == null) {
      _nircmdPath = await _resolveBinaryPath('nircmd.exe');
    }

    if (_helperPath == null && _nircmdPath == null) {
      _available = false;
      stderr.writeln('audio: nenhum helper (hub_audio_helper.exe ou nircmd.exe) encontrado.');
      return;
    }

    _available = true;

    // Leitura inicial
    await refresh();

    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (_) => refresh(),
    );
  }

  /// Procura um executável nos locais previsíveis do bundle e repositório.
  Future<String?> _resolveBinaryPath(String binaryName) async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      '$exeDir${Platform.pathSeparator}$binaryName',
      '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}$binaryName',
      '$exeDir${Platform.pathSeparator}resources${Platform.pathSeparator}$binaryName',
      // Fallbacks para ambiente de desenvolvimento/testes
      '${Directory.current.path}${Platform.pathSeparator}windows${Platform.pathSeparator}runner${Platform.pathSeparator}resources${Platform.pathSeparator}$binaryName',
      '${Directory.current.path}${Platform.pathSeparator}apps${Platform.pathSeparator}cms_app${Platform.pathSeparator}windows${Platform.pathSeparator}runner${Platform.pathSeparator}resources${Platform.pathSeparator}$binaryName',
      '${Directory.current.path}${Platform.pathSeparator}build${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}runner${Platform.pathSeparator}Debug${Platform.pathSeparator}$binaryName',
      '${Directory.current.path}${Platform.pathSeparator}apps${Platform.pathSeparator}cms_app${Platform.pathSeparator}build${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}runner${Platform.pathSeparator}Debug${Platform.pathSeparator}$binaryName',
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }

    // PATH do sistema
    try {
      final r = await Process.run('where', [binaryName]);
      if (r.exitCode == 0) {
        final first = (r.stdout as String).trim().split('\n').first.trim();
        if (first.isNotEmpty) return first;
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<void> refresh() async {
    if (!_available) return;

    if (_helperPath != null) {
      try {
        final r = await Process.run(
          _helperPath!,
          ['status'],
          runInShell: false,
        ).timeout(const Duration(seconds: 2));

        if (r.exitCode == 0) {
          final raw = (r.stdout as String).trim();
          if (raw.isNotEmpty) {
            final data = jsonDecode(raw) as Map<String, dynamic>;
            final masterJson = data['master'] as Map<String, dynamic>?;
            if (masterJson != null) {
              final newMaster = MasterVolume(
                value: (masterJson['volume'] as num?)?.toInt() ?? 0,
                muted: masterJson['muted'] == true,
              );
              if (newMaster != _master) {
                _master = newMaster;
                if (!_masterCtl.isClosed) _masterCtl.add(newMaster);
              }
            }

            final appsJson = data['apps'] as List?;
            final newApps = <AppVolume>[];
            if (appsJson != null) {
              for (final item in appsJson) {
                if (item is Map) {
                  final id = (item['id'] ?? '').toString();
                  final name = (item['name'] ?? id).toString();
                  final vol = (item['volume'] as num?)?.toInt() ?? 0;
                  if (id.isNotEmpty) {
                    newApps.add(AppVolume(id: id, name: name, volume: vol));
                  }
                }
              }
            }

            if (!_listEq(_apps, newApps)) {
              _apps = newApps;
              if (!_appsCtl.isClosed) _appsCtl.add(List.unmodifiable(_apps));
            }
          }
        }
      } catch (_) {
        // Falha transitória
      }
    } else if (_nircmdPath != null) {
      // Fallback nircmd: apenas mantém o último valor conhecido
      if (_master.value == 0 && _pollTimer == null) {
        _master = const MasterVolume(value: 50, muted: false);
        if (!_masterCtl.isClosed) _masterCtl.add(_master);
      }
    }
  }

  @override
  Future<void> setMasterVolume(int value) async {
    if (!_available) return;
    final v = value.clamp(0, 100);

    if (_helperPath != null) {
      try {
        await Process.run(_helperPath!, ['set-master', '$v'], runInShell: false);
        await refresh();
      } catch (_) {}
    } else if (_nircmdPath != null) {
      final nircmdValue = (v * 65535 ~/ 100).clamp(0, 65535);
      await _runNircmd(['setsysvolume', '$nircmdValue']);
      _master = MasterVolume(value: v, muted: _master.muted);
      if (!_masterCtl.isClosed) _masterCtl.add(_master);
    }
  }

  @override
  Future<void> setMute(bool muted) async {
    if (!_available) return;

    if (_helperPath != null) {
      try {
        await Process.run(_helperPath!, ['set-master-mute', muted ? '1' : '0'], runInShell: false);
        await refresh();
      } catch (_) {}
    } else if (_nircmdPath != null) {
      await _runNircmd(['mutesysvolume', muted ? '1' : '0']);
      _master = MasterVolume(value: _master.value, muted: muted);
      if (!_masterCtl.isClosed) _masterCtl.add(_master);
    }
  }

  @override
  Future<void> setAppVolume(String id, int value) async {
    final clean = id.trim();
    if (clean.isEmpty || !_available) return;
    final v = value.clamp(0, 100);

    if (_helperPath != null) {
      try {
        await Process.run(_helperPath!, ['set-app', clean, '$v'], runInShell: false);
        await refresh();
      } catch (_) {}
    } else if (_nircmdPath != null) {
      if (int.tryParse(clean) != null || clean.startsWith('/')) {
        final floatVal = (v / 100.0).toStringAsFixed(2);
        final pidArg = clean.startsWith('/') ? clean : '/$clean';
        await _runNircmd(['setappvolume', pidArg, floatVal]);
      } else {
        await setAppVolumeByName(clean, value);
      }
    }
  }

  @override
  Future<void> setAppVolumeByName(String name, int value) async {
    final clean = name.trim();
    if (clean.isEmpty || !_available) return;
    final v = value.clamp(0, 100);

    if (_helperPath != null) {
      try {
        await Process.run(_helperPath!, ['set-app', clean, '$v'], runInShell: false);
        await refresh();
      } catch (_) {}
    } else if (_nircmdPath != null) {
      final floatVal = (v / 100.0).toStringAsFixed(2);
      final proc = clean.toLowerCase().endsWith('.exe') ? clean : '$clean.exe';
      await _runNircmd(['setappvolume', proc, floatVal]);
    }
  }

  Future<void> _runNircmd(List<String> args) async {
    final path = _nircmdPath;
    if (path == null) return;
    try {
      await Process.run(path, args, runInShell: false);
    } catch (_) {}
  }

  static bool _listEq(List<AppVolume> a, List<AppVolume> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _masterCtl.close();
    await _appsCtl.close();
  }
}