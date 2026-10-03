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
        '{{status}}|{{title}}|{{artist}}',
      ]).timeout(const Duration(seconds: 3));

      if (r.exitCode != 0) return MediaState.idle;

      final line = (r.stdout as String).trim();
      if (line.isEmpty) return MediaState.idle;

      final first = line.indexOf('|');
      final second = first < 0 ? -1 : line.indexOf('|', first + 1);
      if (first < 0 || second < 0) return MediaState.idle;

      return MediaState(
        status: PlaybackStatus.parse(line.substring(0, first)),
        title: line.substring(first + 1, second).trim(),
        artist: line.substring(second + 1).trim(),
      );
    } catch (_) {
      return MediaState.idle;
    }
  }

  Future<void> playPause() => _control('play-pause');
  Future<void> next() => _control('next');
  Future<void> previous() => _control('previous');

  Future<void> _control(String verb) async {
    if (!available) return;
    try {
      await Process.run(executable, [verb]);
      Timer(const Duration(milliseconds: 120), _poll);
    } catch (e) {
      stderr.writeln('playerctl $verb falhou:$e');
    }
  }

  Future<void> dispose() async {
    timer?.cancel();
    await controller.close();
  }
}