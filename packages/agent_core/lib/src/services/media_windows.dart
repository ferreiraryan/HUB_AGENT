// packages/agent_core/lib/src/services/media_windows.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/media_state.dart';
import '../util/windows_binaries.dart';
import '../util/windows_helper_bridge.dart';
import 'media_service.dart';

/// MediaService para Windows via hub_audio_helper.exe (daemon event-driven GSMTC)
/// com fallback automático para CLI e nircmd.exe.
class WindowsMediaService extends MediaService {
  String? _helperPath;
  String? _nircmdPath;
  bool _pollingInFlight = false;
  StreamSubscription<Map<String, dynamic>>? _bridgeSub;

  WindowsMediaService({
    super.interval = const Duration(seconds: 2),
    super.positionSyncInterval = const Duration(seconds: 12),
  });

  static MediaState _parseMap(Map<String, dynamic> json) => MediaState(
        status: PlaybackStatus.parse(json['status']?.toString()),
        title: json['title']?.toString() ?? '',
        artist: json['artist']?.toString() ?? '',
        position: json['position'] is num ? (json['position'] as num).round() : null,
        duration: json['duration'] is num ? (json['duration'] as num).round() : null,
        playbackRate: json['playback_rate'] is num
            ? (json['playback_rate'] as num).toDouble()
            : null,
      );

  @override
  Future<void> start() async {
    _helperPath = WindowsBinaries.resolveHelperPath();
    _nircmdPath = WindowsBinaries.resolveNircmdPath();
    available = _helperPath != null || _nircmdPath != null;

    if (!available) {
      stderr.writeln('media: nenhum helper de midia encontrado no Windows');
      return;
    }

    final usingDaemon = await WindowsHelperBridge.instance.ensureStarted();
    if (usingDaemon) {
      _bridgeSub = WindowsHelperBridge.instance.mediaEvents.listen((ev) {
        acceptState(_parseMap(ev));
      });
      await _pollWindows(forceEmit: true);
      // Como o daemon empurra eventos GSMTC (play/pause/track/seek), só precisamos
      // de uma consulta leve sem spawn a cada 12s para calibração da timeline.
      timer = Timer.periodic(positionSyncInterval, (_) => _pollWindows());
      return;
    }

    if (_helperPath != null) {
      await _pollWindows(forceEmit: true);
      timer = Timer.periodic(interval, (_) => _pollWindows());
    }
  }

  Future<void> _pollWindows({bool forceEmit = false}) async {
    if (_pollingInFlight) return;
    _pollingInFlight = true;
    try {
      if (WindowsHelperBridge.instance.isRunning) {
        final res = await WindowsHelperBridge.instance.request('media_status');
        final data = res?['data'];
        if (data is Map) {
          acceptState(_parseMap(data.cast<String, dynamic>()), forceEmit: forceEmit);
          return;
        }
      }

      if (_helperPath == null) return;
      final res = await Process.run(
        _helperPath!,
        ['media-status'],
        runInShell: false,
      ).timeout(const Duration(seconds: 2));

      if (res.exitCode == 0) {
        final out = (res.stdout as String).trim();
        if (out.isNotEmpty && out.startsWith('{')) {
          final json = jsonDecode(out) as Map<String, dynamic>;
          acceptState(_parseMap(json), forceEmit: forceEmit);
        }
      }
    } catch (_) {
    } finally {
      _pollingInFlight = false;
    }
  }

  @override
  Future<void> playPause() async {
    final ok = await _controlHelper('play_pause');
    if (!ok) await _sendKey('0xB3');
  }

  @override
  Future<void> next() async {
    final ok = await _controlHelper('next');
    if (!ok) await _sendKey('0xB0');
  }

  @override
  Future<void> previous() async {
    final ok = await _controlHelper('prev');
    if (!ok) await _sendKey('0xB1');
  }

  @override
  Future<void> seek(int seconds) async {
    await _controlHelperArgs(['seek', '$seconds']);
  }

  @override
  Future<void> rewind(int seconds) async {
    await _controlHelperArgs(['rewind', '$seconds']);
  }

  @override
  Future<void> fastForward(int seconds) async {
    await _controlHelperArgs(['fast_forward', '$seconds']);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    await _controlHelperArgs(['rate', rate.toString()]);
  }

  Future<bool> _controlHelper(String action) => _controlHelperArgs([action]);

  Future<bool> _controlHelperArgs(List<String> args) async {
    if (WindowsHelperBridge.instance.isRunning && args.isNotEmpty) {
      final res = await WindowsHelperBridge.instance.request(
        'media_control',
        args: {
          'action': args[0],
          if (args.length > 1) 'arg': args[1],
        },
      );
      if (res?['ok'] == true) {
        Timer(const Duration(milliseconds: 150), () => _pollWindows(forceEmit: true));
        return true;
      }
    }

    if (_helperPath == null) return false;
    try {
      final res = await Process.run(
        _helperPath!,
        ['media-control', ...args],
        runInShell: false,
      );
      Timer(const Duration(milliseconds: 150), () => _pollWindows(forceEmit: true));
      return res.exitCode == 0;
    } catch (e) {
      stderr.writeln('media-control $args falhou: $e');
      return false;
    }
  }

  Future<void> _sendKey(String vkCodeHex) async {
    if (_nircmdPath == null) return;
    try {
      await Process.run(
        _nircmdPath!,
        ['sendkeypress', vkCodeHex],
        runInShell: false,
      );
    } catch (e) {
      stderr.writeln('media: nircmd sendkeypress $vkCodeHex falhou: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _bridgeSub?.cancel();
    await super.dispose();
  }
}