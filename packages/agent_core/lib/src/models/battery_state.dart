import 'package:meta/meta.dart';

@immutable
class BatteryDevice {
  final String id;
  final String name;
  final String kind; // laptop | headphones | mouse | keyboard | gamepad | other
  final int percent;
  final bool charging;

  const BatteryDevice({
    required this.id,
    required this.name,
    required this.kind,
    required this.percent,
    this.charging = false,
  });

  factory BatteryDevice.fromJson(Map<String, dynamic> json) => BatteryDevice(
        id: (json['id'] as String?) ?? 'bat',
        name: (json['name'] as String?) ?? 'Dispositivo',
        kind: (json['kind'] as String?) ?? 'other',
        percent: ((json['percent'] as num?)?.round() ?? 0).clamp(0, 100),
        charging: json['charging'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'percent': percent,
        'charging': charging,
      };

  @override
  bool operator ==(Object other) =>
      other is BatteryDevice &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.percent == percent &&
      other.charging == charging;

  @override
  int get hashCode => Object.hash(id, name, kind, percent, charging);
}

@immutable
class BatterySnapshot {
  final List<BatteryDevice> devices;

  const BatterySnapshot({this.devices = const []});

  Map<String, dynamic> toJson() => {
        'devices': devices.map((d) => d.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) {
    if (other is! BatterySnapshot) return false;
    if (other.devices.length != devices.length) return false;
    for (var i = 0; i < devices.length; i++) {
      if (other.devices[i] != devices[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(devices);
}
