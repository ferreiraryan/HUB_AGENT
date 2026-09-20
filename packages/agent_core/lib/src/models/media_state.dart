import 'package:meta/meta.dart';

enum PlaybackStatus {
  playing('Playing'),
  paused('Paused'),
  stopped('Stopped');

  final String wire;
  const PlaybackStatus(this.wire);

  /// playerctl devolve "Playing"/"Paused"/"Stopped"; qualquer outra coisa
  /// (inclusive erro por falta de player) vira Stopped.
  static PlaybackStatus parse(String? raw) => switch (raw?.trim()) {
        'Playing' => PlaybackStatus.playing,
        'Paused' => PlaybackStatus.paused,
        _ => PlaybackStatus.stopped,
      };
}

@immutable
class MediaState {
  final PlaybackStatus status;
  final String title;
  final String artist;

  const MediaState({
    required this.status,
    this.title = '',
    this.artist = '',
  });

  static const MediaState idle = MediaState(status: PlaybackStatus.stopped);

  /// Contrato: { status, title, artist }. Ordem das chaves importa.
  Map<String, dynamic> toJson() =>
      {'status': status.wire, 'title': title, 'artist': artist};

  @override
  bool operator ==(Object o) =>
      o is MediaState &&
      o.status == status &&
      o.title == title &&
      o.artist == artist;

  @override
  int get hashCode => Object.hash(status, title, artist);
}
