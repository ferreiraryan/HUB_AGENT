import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/media_state.dart';

class MediaService {
  static const String _formatSpec =
      '{{status}}|{{title}}|{{artist}}|{{position}}|{{mpris:length}}|{{rate}}';

  final Duration interval;
  final Duration positionSyncInterval;
  final String executable;

  Timer? timer;
  Process? _followProc;
  StreamSubscription<String>? _followSub;
  MediaState last = MediaState.idle;
  MediaState _lastEmitted = MediaState.idle;
  DateTime _lastEmittedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool available = true;
  bool _inFlight = false;
  bool _disposed = false;

  final controller = StreamController<MediaState>.broadcast();

  MediaService({
    this.interval = const Duration(seconds: 2),
    this.positionSyncInterval = const Duration(seconds: 12),
    this.executable = 'playerctl',
  });

  Stream<MediaState> get changes => controller.stream;
  MediaState get current => last;
  bool get isAvailable => available;

  /// Decide se um novo estado de mídia deve ser emitido no stream (e portanto no MQTT).
  ///
  /// Mudanças de status, faixa, duração, velocidade ou seek manual (>2s de desvio)
  /// são emitidas imediatamente. Durante reprodução contínua normal, emite apenas
  /// pulsos periódicos de calibração ([positionSyncInterval]) pois o tablet
  /// já interpola a timeline localmente a cada segundo.
  bool shouldEmitState(MediaState next, {DateTime? now}) {
    final ts = now ?? DateTime.now();
    if (_lastEmittedAt.millisecondsSinceEpoch == 0) {
      return next != _lastEmitted;
    }

    final metaChanged = next.status != _lastEmitted.status ||
        next.title != _lastEmitted.title ||
        next.artist != _lastEmitted.artist ||
        next.duration != _lastEmitted.duration ||
        next.playbackRate != _lastEmitted.playbackRate;
    if (metaChanged) return true;

    if (next.status == PlaybackStatus.playing) {
      final elapsedSec = ts.difference(_lastEmittedAt).inMilliseconds / 1000.0;
      if (elapsedSec >= positionSyncInterval.inSeconds) {
        return next.position != _lastEmitted.position;
      }
      if (next.position != null && _lastEmitted.position != null) {
        final rate = next.playbackRate ?? 1.0;
        final expected = _lastEmitted.position! + (elapsedSec * rate);
        if ((next.position! - expected).abs() > 2.5) {
          return true; // Seek manual ou salto de posição
        }
      }
      return false;
    }

    return next.position != _lastEmitted.position;
  }

  /// Atualiza estado interno e emite no stream apenas quando necessário.
  void acceptState(MediaState next, {bool forceEmit = false, DateTime? now}) {
    last = next;
    final ts = now ?? DateTime.now();
    if (forceEmit || shouldEmitState(next, now: ts)) {
      _lastEmitted = next;
      _lastEmittedAt = ts;
      if (!controller.isClosed) controller.add(next);
    }
  }

  Future<void> start() async {
    available = await _probe();
    if (!available) {
      stderr.writeln('playerctl nao encontrado: modulo de media desativado');
      return;
    }
    await _poll();
    final followOk = await _startFollowStream();
    if (!followOk && !_disposed) {
      timer = Timer.periodic(interval, (_) => _poll());
    }
  }

  Future<bool> _startFollowStream() async {
    try {
      final proc = await Process.start(executable, [
        '--follow',
        'metadata',
        '--format',
        _formatSpec,
      ]);
      _followProc = proc;
      proc.stderr.drain<void>();
      _followSub = proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (_disposed) return;
        final parsed = parseMetadataLine(line);
        acceptState(parsed);
      });

      proc.exitCode.then((_) {
        if (_followProc == proc) {
          _followProc = null;
          if (!_disposed && timer == null) {
            // Fallback seguro para polling caso o playerctl --follow encerre.
            timer = Timer.periodic(interval, (_) => _poll());
          }
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probe() async {
    try {
      final r = await Process.run('which', [executable]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _poll({bool forceEmit = false}) async {
    if (_inFlight || _disposed) return;
    _inFlight = true;
    try {
      final state = await _read();
      acceptState(state, forceEmit: forceEmit);
    } finally {
      _inFlight = false;
    }
  }

  static MediaState parseMetadataLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return MediaState.idle;

    final parts = line.split('|');
    if (parts.length < 3) return MediaState.idle;

    int? pos;
    int? dur;
    double? rate;
    if (parts.length >= 4) {
      final posMicro = int.tryParse(parts[3].trim());
      if (posMicro != null) pos = (posMicro / 1000000).round();
    }
    if (parts.length >= 5) {
      final lenMicro = int.tryParse(parts[4].trim());
      if (lenMicro != null) dur = (lenMicro / 1000000).round();
    }
    if (parts.length >= 6) {
      rate = double.tryParse(parts[5].trim());
    }

    return MediaState(
      status: PlaybackStatus.parse(parts[0]),
      title: parts[1].trim(),
      artist: parts[2].trim(),
      position: pos,
      duration: dur,
      playbackRate: rate,
    );
  }

  Future<MediaState> _read() async {
    try {
      final r = await Process.run(executable, [
        'metadata',
        '--format',
        _formatSpec,
      ]).timeout(const Duration(seconds: 3));

      if (r.exitCode != 0) return MediaState.idle;
      return parseMetadataLine(r.stdout as String);
    } catch (_) {
      return MediaState.idle;
    }
  }

  Future<void> playPause() => _control('play-pause');
  Future<void> next() => _control('next');
  Future<void> previous() => _control('previous');
  Future<void> seek(int seconds) => _controlArgs(['position', '$seconds']);
  Future<void> rewind(int seconds) => _controlArgs(['position', '$seconds-']);
  Future<void> fastForward(int seconds) => _controlArgs(['position', '$seconds+']);
  Future<void> setPlaybackRate(double rate) => _controlArgs(['rate', rate.toString()]);

  Future<void> _control(String verb) => _controlArgs([verb]);

  Future<void> _controlArgs(List<String> args) async {
    if (!available) return;
    try {
      await Process.run(executable, args);
      Timer(const Duration(milliseconds: 120), () => _poll(forceEmit: true));
    } catch (e) {
      stderr.writeln('playerctl $args falhou:$e');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    timer?.cancel();
    timer = null;
    await _followSub?.cancel();
    _followSub = null;
    try {
      _followProc?.kill();
    } catch (_) {}
    _followProc = null;
    await controller.close();
  }
}