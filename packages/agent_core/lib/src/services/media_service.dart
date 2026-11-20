import 'dart:async';
import 'dart:io';

import '../models/media_state.dart';

class MediaService {
  final Duration interval;
  final String executable;

  Timer? timer;
  MediaState last = MediaState.idle;
  bool available = true;
  bool _inFlight = false;

  final controller = StreamController<MediaState>.broadcast();

  MediaService({
    this.interval = const Duration(seconds: 1),
    this.executable = 'playerctl',
  });

  Stream<MediaState> get changes => controller.stream;
  MediaState get current => last;
  bool get isAvailable => available;

  Future<void> start() async {
    available = await _probe();
    if (!available) {
      stderr.writeln('playerctl nao encontrado: modulo de media desativado');
      return;
    }
    await _poll();
    timer = Timer.periodic(interval, (_) => _poll());
  }

  Future<bool> _probe() async {
    try {
      final r = await Process.run('which', [executable]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _poll() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final state = await _read();
      if (state != last) {
        last = state;
        if (!controller.isClosed) controller.add(state);
      }
    } finally {
      _inFlight = false;
    }
  }

  Future<MediaState> _read() async {
    try {
      final r = await Process.run(executable, [
        'metadata',
        '--format',
        '{{status}}|{{title}}|{{artist}}|{{position}}|{{mpris:length}}|{{rate}}',
      ]).timeout(const Duration(seconds: 3));

      if (r.exitCode != 0) return MediaState.idle;

      final line = (r.stdout as String).trim();
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
    } catch (_) {
      return MediaState.idle;
    }
  }

  Future<void> playPause() => _control('play-pause');
  Future<void> next() => _control('next');
  Future<void> previous() => _control('previous');
  Future<void> seek(int seconds) => _controlArgs(['position', '$seconds']);
  Future<void> rewind(int seconds) => _controlArgs(['position', '${seconds}-']);
  Future<void> fastForward(int seconds) => _controlArgs(['position', '${seconds}+']);
  Future<void> setPlaybackRate(double rate) => _controlArgs(['rate', rate.toString()]);

  Future<void> _control(String verb) => _controlArgs([verb]);

  Future<void> _controlArgs(List<String> args) async {
    if (!available) return;
    try {
      await Process.run(executable, args);
      Timer(const Duration(milliseconds: 120), _poll);
    } catch (e) {
      stderr.writeln('playerctl $args falhou:$e');
    }
  }

  Future<void> dispose() async {
    timer?.cancel();
    await controller.close();
  }
}