import 'package:meta/meta.dart';

/// Volume do sink padrao. Int 0-100 conforme o contrato (nao float).
@immutable
class MasterVolume {
  final int value;
  final bool muted;

  const MasterVolume({required this.value, this.muted = false});

  /// Contrato: `nodes/+/audio/volume` -> { value: 0-100 }.
  /// `muted` NAO e publicado: o tablet nao o espera. Mantido aqui porque o
  /// CMS usa, e porque wpctl reporta mute junto do volume.
  Map<String, dynamic> toJson() => {'value': value};

  @override
  bool operator ==(Object o) =>
      o is MasterVolume && o.value == value && o.muted == muted;

  @override
  int get hashCode => Object.hash(value, muted);
}

/// Um stream individual do mixer (sink-input no PulseAudio/PipeWire).
@immutable
class AppVolume {
  /// Indice do sink-input, como string. ATENCAO: e volatil — muda quando o
  /// app reinicia. O tablet deve tratar a lista como efemera.
  final String id;

  /// application.name, com fallback para media.name e depois para "app <id>".
  final String name;

  /// 0-100 int.
  final int volume;

  const AppVolume({required this.id, required this.name, required this.volume});

  /// Contrato: [ { id, name, volume } ]. Ordem das chaves importa.
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'volume': volume};

  @override
  bool operator ==(Object o) =>
      o is AppVolume && o.id == id && o.name == name && o.volume == volume;

  @override
  int get hashCode => Object.hash(id, name, volume);
}
