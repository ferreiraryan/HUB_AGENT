import 'package:meta/meta.dart';

/// Estado de reprodução de áudio do Sound Pad.
///
/// Reflete se há algum som sendo reproduzido no momento e qual o seu ID,
/// permitindo que os clientes (como o tablet) atualizem seus tiles.
@immutable
class SoundPlaybackState {
  final String? soundId;
  final bool isPlaying;

  const SoundPlaybackState({
    required this.soundId,
    required this.isPlaying,
  });

  static const SoundPlaybackState idle = SoundPlaybackState(
    soundId: null,
    isPlaying: false,
  );

  factory SoundPlaybackState.playing(String soundId) => SoundPlaybackState(
        soundId: soundId,
        isPlaying: true,
      );

  factory SoundPlaybackState.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String?;
    final isPlaying = (status == 'playing') || (json['is_playing'] == true);
    final soundId = (json['playing'] ?? json['sound_id'] ?? json['current_sound_id']) as String?;
    return SoundPlaybackState(
      soundId: soundId,
      isPlaying: isPlaying && soundId != null,
    );
  }

  Map<String, dynamic> toJson() => {
        'current_sound_id': isPlaying ? soundId : null,
        'is_playing': isPlaying,
        'playing': isPlaying ? soundId : null,
        'status': isPlaying ? 'playing' : 'idle',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoundPlaybackState &&
          runtimeType == other.runtimeType &&
          soundId == other.soundId &&
          isPlaying == other.isPlaying;

  @override
  int get hashCode => Object.hash(soundId, isPlaying);

  @override
  String toString() =>
      'SoundPlaybackState(soundId: $soundId, isPlaying: $isPlaying)';
}

