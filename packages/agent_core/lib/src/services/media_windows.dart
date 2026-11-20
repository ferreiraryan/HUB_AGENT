// packages/agent_core/lib/src/services/media_windows.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/media_state.dart';
import '../util/windows_binaries.dart';
import 'media_service.dart';

/// MediaService para Windows via hub_audio_helper.exe com fallback para nircmd.exe.
///
/// Consulta metadados (GSMTC) em tempo real (título, artista, status, posição e duração)
/// e envia comandos de controle (play/pause, next, prev, seek, rewind, fast_forward).
class WindowsMediaService extends MediaService {
  String? _helperPath;
  String? _nircmdPath;
  bool _pollingInFlight = false;

  WindowsMediaService({Duration interval = const Duration(seconds: 1)})
      : super(interval: interval);

  @override
  Future<void> start() async {
    _helperPath = WindowsBinaries.resolveHelperPath();
    _nircmdPath = WindowsBinaries.resolveNircmdPath();
    available = _helperPath != null || _nircmdPath != null;

    if (!available) {
      stderr.writeln('media: nenhum helper de midia encontrado no Windows');
      return;
    }

    if (_helperPath != null) {
      await _pollWindows();
      timer = Timer.periodic(interval, (_) => _pollWindows());
    }
  }

  Future<void> _pollWindows() async {
    if (_pollingInFlight || _helperPath == null) return;
    _pollingInFlight = true;
    try {
      final res = await Process.run(
        _helperPath!,
        ['media-status'],
        runInShell: false,
      ).timeout(const Duration(seconds: 2));

      if (res.exitCode == 0) {
        final out = (res.stdout as String).trim();
        if (out.isNotEmpty && out.startsWith('{')) {
          final json = jsonDecode(out) as Map<String, dynamic>;
          final parsed = MediaState(
            status: PlaybackStatus.parse(json['status']?.toString()),
            title: json['title']?.toString() ?? '',
            artist: json['artist']?.toString() ?? '',
            position: json['position'] is num ? (json['position'] as num).round() : null,
            duration: json['duration'] is num ? (json['duration'] as num).round() : null,
            playbackRate: json['playback_rate'] is num ? (json['playback_rate'] as num).toDouble() : null,
          );
          if (parsed != last) {
            last = parsed;
            if (!controller.isClosed) controller.add(parsed);
          }
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
    if (_helperPath == null) return false;
    try {
      final res = await Process.run(
        _helperPath!,
        ['media-control', ...args],
        runInShell: false,
      );
      Timer(const Duration(milliseconds: 150), _pollWindows);
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
}