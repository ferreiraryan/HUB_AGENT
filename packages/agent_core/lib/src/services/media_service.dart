import 'dart:async';
import 'dart:io';

import '../models/media_state.dart';

/// Wrapper de `playerctl` por polling.
///
/// Polling de 1s em vez de `playerctl --follow` de proposito: o --follow morre
/// silenciosamente quando o player some e volta, e resupervisionar um processo
/// filho custa mais complexidade do que um Process.run barato por segundo.
class MediaService {
  final Duration interval;
  final String executable;

  Timer? _timer;
  MediaState _last = MediaState.idle;
  bool _available = true;
  bool _inFlight = false;

  final _controller = StreamController<MediaState>.broadcast();

  MediaService({
    this.interval = const Duration(seconds: 1),
    this.executable = 'playerctl',
  });

  /// Emite SO quando o estado muda. Republicar o mesmo payload a cada segundo
  /// inundaria o broker e o tablet sem motivo.
  Stream<MediaState> get changes => _controller.stream;

  MediaState get current => _last;
  bool get isAvailable => _available;

  Future<void> start() async {
    _available = await _probe();
    if (!_available) {
      stderr.writeln('playerctl nao encontrado: modulo de media desativado');
      return;
    }
    await _poll();
    _timer = Timer.periodic(interval, (_) => _poll());
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
    if (_inFlight) return; // nao empilha se o playerctl travar
    _inFlight = true;
    try {
      final state = await _read();
      if (state != _last) {
        _last = state;
        if (!_controller.isClosed) _controller.add(state);
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

      // Sem player rodando, playerctl sai com codigo != 0.
      if (r.exitCode != 0) return MediaState.idle;

      final line = (r.stdout as String).trim();
      if (line.isEmpty) return MediaState.idle;

      // split com limite implicito: titulos podem conter "|".
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

  // ------------------------------------------------------------- controle

  Future<void> playPause() => _control('play-pause');
  Future<void> next() => _control('next');
  Future<void> previous() => _control('previous');

  Future<void> _control(String verb) async {
    if (!_available) return;
    try {
      await Process.run(executable, [verb]);
      // Antecipa o poll: o usuario apertou o botao e espera feedback imediato.
      Timer(const Duration(milliseconds: 120), _poll);
    } catch (e) {
      stderr.writeln('playerctl $verb falhou: $e');
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}
