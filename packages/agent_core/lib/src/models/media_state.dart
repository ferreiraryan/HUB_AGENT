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
  final int? position;
  final int? duration;
  final double? playbackRate;

  const MediaState({
    required this.status,
    this.title = '',
    this.artist = '',
    this.position,
    this.duration,
    this.playbackRate,
  });

  static const MediaState idle = MediaState(status: PlaybackStatus.stopped);

  /// Contrato: { status, title, artist, [position], [duration], [playback_rate] }. Ordem das chaves importa.
  Map<String, dynamic> toJson() => {
        'status': status.wire,
        'title': title,
        'artist': artist,
        if (position != null) 'position': position,
        if (duration != null) 'duration': duration,
        if (playbackRate != null) 'playback_rate': playbackRate,
      };

  @override
  bool operator ==(Object other) =>
      other is MediaState &&
      other.status == status &&
      other.title == title &&
      other.artist == artist &&
      other.position == position &&
      other.duration == duration &&
      other.playbackRate == playbackRate;

  @override
  int get hashCode => Object.hash(status, title, artist, position, duration, playbackRate);
}
