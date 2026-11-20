import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/audio_state.dart';
import '../../util/windows_binaries.dart';
import '../../util/windows_helper_bridge.dart';
import 'audio_controller.dart';

/// AudioController para Windows via hub_audio_helper.exe (WASAPI nativo)
/// com suporte a daemon persistente (orientado a eventos, 0 spawns/min) e
/// fallback gracioso para CLI / nircmd.exe.
class WindowsAudioController implements AudioController, ExtendedAudioController {
  final _masterCtl = StreamController<MasterVolume>.broadcast();
  final _appsCtl = StreamController<List<AppVolume>>.broadcast();
  final _micCtl = StreamController<MicState>.broadcast();

  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _bridgeSub;
  bool _available = false;
  bool _usingDaemon = false;
  MasterVolume _master = const MasterVolume(value: 0);
  MicState _mic = const MicState();
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
  Stream<MicState> get micChanges => _micCtl.stream;
  @override
  MasterVolume get master => _master;
  @override
  MicState get mic => _mic;
  @override
  List<AppVolume> get apps => List.unmodifiable(_apps);
  @override
  bool get isAvailable => _available;

  @override
  Future<void> start() async {
    _helperPath = WindowsBinaries.resolveHelperPath();
    _nircmdPath = WindowsBinaries.resolveNircmdPath();

    if (_helperPath == null && _nircmdPath == null) {
      _available = false;
      stderr.writeln('audio: nenhum helper (hub_audio_helper.exe ou nircmd.exe) encontrado.');
      return;
    }

    _available = true;

    _usingDaemon = await WindowsHelperBridge.instance.ensureStarted();
    if (_usingDaemon) {
      _bridgeSub = WindowsHelperBridge.instance.audioEvents.listen(_applyStatusMap);
      await refresh();
      // Com daemon orientado a eventos (WASAPI callback para master/mic), um
      // refresh leve a cada 4s sem spawn de processo mantém a lista de apps sincronizada.
      _pollTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => refresh(),
      );
      return;
    }

    // Fallback CLI legado
    await refresh();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => refresh(),
    );
  }

  void _applyStatusMap(Map<String, dynamic> data) {
    final masterJson = data['master'];
    if (masterJson is Map) {
      final newMaster = MasterVolume(
        value: (masterJson['volume'] as num?)?.toInt() ?? 0,
        muted: masterJson['muted'] == true,
      );
      if (newMaster != _master) {
        _master = newMaster;
        if (!_masterCtl.isClosed) _masterCtl.add(newMaster);
      }
    }

    final micJson = data['mic'];
    if (micJson is Map) {
      final newMic = MicState(
        available: micJson['available'] == true,
        muted: micJson['muted'] == true,
        volume: (micJson['volume'] as num?)?.toInt() ?? 100,
      );
      if (newMic != _mic) {
        _mic = newMic;
        if (!_micCtl.isClosed) _micCtl.add(newMic);
      }
    }

    final appsJson = data['apps'];
    if (appsJson is List) {
      final newApps = <AppVolume>[];
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
      if (!_listEq(_apps, newApps)) {
        _apps = newApps;
        if (!_appsCtl.isClosed) _appsCtl.add(List.unmodifiable(_apps));
      }
    }
  }

  @override
  Future<void> refresh() async {
    if (!_available) return;

    if (WindowsHelperBridge.instance.isRunning) {
      final res = await WindowsHelperBridge.instance.request('audio_status');
      final data = res?['data'];
      if (data is Map) {
        _applyStatusMap(data.cast<String, dynamic>());
        return;
      }
    }

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
            _applyStatusMap(data);
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

    if (WindowsHelperBridge.instance.isRunning) {
      final res = await WindowsHelperBridge.instance
          .request('set_master', args: {'value': v});
      if (res?['ok'] == true) {
        await refresh();
        return;
      }
    }

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

    if (WindowsHelperBridge.instance.isRunning) {
      final res = await WindowsHelperBridge.instance
          .request('set_master_mute', args: {'muted': muted});
      if (res?['ok'] == true) {
        await refresh();
        return;
      }
    }

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

    if (WindowsHelperBridge.instance.isRunning) {
      final res = await WindowsHelperBridge.instance
          .request('set_app', args: {'target': clean, 'value': v});
      if (res?['ok'] == true) {
        await refresh();
        return;
      }
    }

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

    if (WindowsHelperBridge.instance.isRunning) {
      final res = await WindowsHelperBridge.instance
          .request('set_app', args: {'target': clean, 'value': v});
      if (res?['ok'] == true) {
        await refresh();
        return;
      }
    }

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
  Future<void> setMicMute(bool muted) async {
    if (!_available || _helperPath == null) return;
    if (WindowsHelperBridge.instance.isRunning) {
      final res = await WindowsHelperBridge.instance
          .request('set_mic_mute', args: {'muted': muted});
      if (res?['ok'] == true) {
        await refresh();
        return;
      }
    }
    try {
      await Process.run(_helperPath!, ['set-mic-mute', muted ? '1' : '0'],
          runInShell: false);
      await refresh();
    } catch (_) {}
  }

  @override
  Future<void> setDefaultOutput(String deviceNameOrId) async {
    final clean = deviceNameOrId.trim();
    if (clean.isEmpty) return;
    _nircmdPath ??= WindowsBinaries.resolveNircmdPath();
    if (_nircmdPath != null) {
      // Define como dispositivo padrão de multimídia (1) e comunicação (2)
      await _runNircmd(['setdefaultsounddevice', clean, '1']);
      await _runNircmd(['setdefaultsounddevice', clean, '2']);
      await refresh();
    }
  }

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _bridgeSub?.cancel();
    await _masterCtl.close();
    await _appsCtl.close();
    await _micCtl.close();
  }
}