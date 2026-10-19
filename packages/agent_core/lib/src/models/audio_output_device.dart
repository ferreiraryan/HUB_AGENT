import 'package:meta/meta.dart';

/// Dispositivo de saída de áudio (fone, alto-falante, cabo de áudio virtual).
@immutable
class AudioOutputDevice {
  final String id;
  final String name;
  final bool isDefault;

  const AudioOutputDevice({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  factory AudioOutputDevice.fromJson(Map<String, dynamic> json) =>
      AudioOutputDevice(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Dispositivo Desconhecido',
        isDefault: json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_default': isDefault,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioOutputDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isDefault == other.isDefault;

  @override
  int get hashCode => Object.hash(id, name, isDefault);

  @override
  String toString() =>
      'AudioOutputDevice(id: $id, name: $name, isDefault: $isDefault)';
}

