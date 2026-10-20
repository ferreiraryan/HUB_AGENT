import 'package:meta/meta.dart';

@immutable
sealed class Tile {
  final String id;
  final String icon;
  final String label;
  final int width;
  final int height;

  const Tile({
    required this.id,
    required this.icon,
    required this.label,
    this.width = 1,
    this.height = 1,
  });

  bool get is1x1 => width == 1 && height == 1;
  bool get is2x1 => width == 2 && height == 1;
  bool get is1x2 => width == 1 && height == 2;
  bool get is2x2 => width == 2 && height == 2;

  String get type;
  Map<String, dynamic> toJson();

  factory Tile.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final icon = (json['icon'] as String?) ?? '';
    final label = (json['label'] as String?) ?? '';
    final type = (json['type'] as String?) ?? 'shortcut';

    final rawW = (json['width'] as num?)?.toInt() ?? (json['cols'] as num?)?.toInt();
    final rawH = (json['height'] as num?)?.toInt() ?? (json['rows'] as num?)?.toInt();
    final defaultW = (type == 'slider' || type == 'stat') ? 2 : 1;
    final width = (rawW ?? defaultW).clamp(1, 2);
    final height = (rawH ?? 1).clamp(1, 2);

    return switch (type) {
      'shortcut' => ShortcutTile(
          id: id,
          icon: icon,
          label: label,
          width: width,
          height: height,
        ),
      'folder' => FolderTile(
          id: id,
          icon: icon,
          label: label,
          target: json['target'] as String,
          width: width,
          height: height,
        ),
      'back' => BackTile(
          id: id,
          icon: icon,
          label: label,
          width: width,
          height: height,
        ),
      'slider' => SliderTile(
          id: id,
          icon: icon,
          label: label,
          width: width,
          height: height,
          source: SliderSource.fromJson(
              (json['source'] as Map?)?.cast<String, dynamic>() ??
                  const {'kind': 'master_volume'}),
        ),
      'stat' => StatTile(
          id: id,
          icon: icon,
          label: label,
          width: width,
          height: height,
          source: StatSource.fromJson(
              (json['source'] as Map?)?.cast<String, dynamic>() ??
                  const {'kind': 'cpu', 'field': 'load', 'unit': '%'}),
        ),
      'sound' => SoundTile(
          id: id,
          icon: icon,
          label: label,
          soundId: (json['sound_id'] as String?) ?? id,
          width: width,
          height: height,
        ),
      _ => throw FormatException('tipo de tile desconhecido: "$type"'),
    };
  }
}

final class ShortcutTile extends Tile {
  const ShortcutTile({
    required super.id,
    required super.icon,
    required super.label,
    super.width = 1,
    super.height = 1,
  });

  @override
  String get type => 'shortcut';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'shortcut',
        'id': id,
        'icon': icon,
        'label': label,
        if (width != 1) 'width': width,
        if (height != 1) 'height': height,
      };

  ShortcutTile copyWith({
    String? id,
    String? icon,
    String? label,
    int? width,
    int? height,
  }) =>
      ShortcutTile(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  @override
  bool operator ==(Object other) =>
      other is ShortcutTile &&
      other.id == id &&
      other.icon == icon &&
      other.label == label &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(type, id, icon, label, width, height);
}

final class FolderTile extends Tile {
  final String target;

  const FolderTile({
    required super.id,
    required super.icon,
    required super.label,
    required this.target,
    super.width = 1,
    super.height = 1,
  });

  @override
  String get type => 'folder';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'folder',
        'id': id,
        'icon': icon,
        'label': label,
        'target': target,
        if (width != 1) 'width': width,
        if (height != 1) 'height': height,
      };

  FolderTile copyWith({
    String? id,
    String? icon,
    String? label,
    String? target,
    int? width,
    int? height,
  }) =>
      FolderTile(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
        target: target ?? this.target,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  @override
  bool operator ==(Object other) =>
      other is FolderTile &&
      other.id == id &&
      other.icon == icon &&
      other.label == label &&
      other.target == target &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(type, id, icon, label, target, width, height);
}

final class BackTile extends Tile {
  const BackTile({
    required super.id,
    required super.icon,
    required super.label,
    super.width = 1,
    super.height = 1,
  });

  @override
  String get type => 'back';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'back',
        'id': id,
        'icon': icon,
        'label': label,
        if (width != 1) 'width': width,
        if (height != 1) 'height': height,
      };

  BackTile copyWith({
    String? id,
    String? icon,
    String? label,
    int? width,
    int? height,
  }) =>
      BackTile(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  @override
  bool operator ==(Object other) =>
      other is BackTile &&
      other.id == id &&
      other.icon == icon &&
      other.label == label &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(type, id, icon, label, width, height);
}

@immutable
class SliderSource {
  final String kind;
  final String? match;
  final List<String>? cmd;

  const SliderSource({
    required this.kind,
    this.match,
    this.cmd,
  });

  static const String kindMasterVolume = 'master_volume';
  static const String kindAppVolume = 'app_volume';
  static const String kindBrightness = 'brightness';
  static const String kindCustom = 'custom';

  static const Set<String> validKinds = {
    kindMasterVolume,
    kindAppVolume,
    kindBrightness,
    kindCustom,
  };

  factory SliderSource.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String? ?? kindMasterVolume;
    if (!validKinds.contains(kind)) {
      throw FormatException('kind de slider desconhecido: "$kind"');
    }
    return SliderSource(
      kind: kind,
      match: json['match'] as String?,
      cmd: json['cmd'] == null ? null : List<String>.from(json['cmd'] as List),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (match != null) 'match': match,
        if (cmd != null) 'cmd': cmd,
      };

  SliderSource copyWith({
    String? kind,
    String? match,
    List<String>? cmd,
    bool clearMatch = false,
    bool clearCmd = false,
  }) =>
      SliderSource(
        kind: kind ?? this.kind,
        match: clearMatch ? null : (match ?? this.match),
        cmd: clearCmd ? null : (cmd ?? this.cmd),
      );

  @override
  bool operator ==(Object other) =>
      other is SliderSource &&
      other.kind == kind &&
      other.match == match &&
      (other.cmd == null && cmd == null ||
          other.cmd != null &&
              cmd != null &&
              other.cmd!.join('\u0000') == cmd!.join('\u0000'));

  @override
  int get hashCode => Object.hash(
        kind,
        match,
        cmd == null ? 0 : Object.hashAll(cmd!),
      );
}

final class SliderTile extends Tile {
  final SliderSource source;

  const SliderTile({
    required super.id,
    required super.icon,
    required super.label,
    super.width = 2,
    super.height = 1,
    required this.source,
  });

  @override
  String get type => 'slider';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'slider',
        'id': id,
        'icon': icon,
        'label': label,
        if (width != 2) 'width': width,
        if (height != 1) 'height': height,
        'source': source.toJson(),
      };

  SliderTile copyWith({
    String? id,
    String? icon,
    String? label,
    int? width,
    int? height,
    SliderSource? source,
  }) =>
      SliderTile(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
        width: width ?? this.width,
        height: height ?? this.height,
        source: source ?? this.source,
      );

  @override
  bool operator ==(Object other) =>
      other is SliderTile &&
      other.id == id &&
      other.icon == icon &&
      other.label == label &&
      other.width == width &&
      other.height == height &&
      other.source == source;

  @override
  int get hashCode => Object.hash(type, id, icon, label, width, height, source);
}

@immutable
class StatSource {
  final String kind;
  final String field;
  final String unit;

  const StatSource({
    required this.kind,
    required this.field,
    required this.unit,
  });

  static const String kindCpu = 'cpu';
  static const String kindRam = 'ram';
  static const String kindDisk = 'disk';
  static const Set<String> validKinds = {kindCpu, kindRam, kindDisk};

  factory StatSource.fromJson(Map<String, dynamic> j) {
    final kind = j['kind'] as String? ?? kindCpu;
    if (!validKinds.contains(kind)) {
      throw FormatException('kind de stat desconhecido: "$kind"');
    }
    return StatSource(
      kind: kind,
      field: j['field'] as String? ?? 'load',
      unit: j['unit'] as String? ?? '%',
    );
  }

  Map<String, dynamic> toJson() => {'kind': kind, 'field': field, 'unit': unit};

  StatSource copyWith({String? kind, String? field, String? unit}) =>
      StatSource(
        kind: kind ?? this.kind,
        field: field ?? this.field,
        unit: unit ?? this.unit,
      );

  @override
  bool operator ==(Object other) =>
      other is StatSource &&
      other.kind == kind &&
      other.field == field &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(kind, field, unit);
}

final class StatTile extends Tile {
  final StatSource source;

  const StatTile({
    required super.id,
    required super.icon,
    required super.label,
    super.width = 2,
    super.height = 1,
    required this.source,
  });

  @override
  String get type => 'stat';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'stat',
        'id': id,
        'icon': icon,
        'label': label,
        if (width != 2) 'width': width,
        if (height != 1) 'height': height,
        'source': source.toJson(),
      };

  StatTile copyWith({
    String? id,
    String? icon,
    String? label,
    int? width,
    int? height,
    StatSource? source,
  }) =>
      StatTile(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
        width: width ?? this.width,
        height: height ?? this.height,
        source: source ?? this.source,
      );

  @override
  bool operator ==(Object other) =>
      other is StatTile &&
      other.id == id &&
      other.icon == icon &&
      other.label == label &&
      other.width == width &&
      other.height == height &&
      other.source == source;

  @override
  int get hashCode => Object.hash(type, id, icon, label, width, height, source);
}

final class SoundTile extends Tile {
  final String soundId;

  const SoundTile({
    required super.id,
    required super.icon,
    required super.label,
    required this.soundId,
    super.width = 1,
    super.height = 1,
  });

  @override
  String get type => 'sound';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'sound',
        'id': id,
        'icon': icon,
        'label': label,
        'sound_id': soundId,
        if (width != 1) 'width': width,
        if (height != 1) 'height': height,
      };

  SoundTile copyWith({
    String? id,
    String? icon,
    String? label,
    String? soundId,
    int? width,
    int? height,
  }) =>
      SoundTile(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
        soundId: soundId ?? this.soundId,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  @override
  bool operator ==(Object other) =>
      other is SoundTile &&
      other.id == id &&
      other.icon == icon &&
      other.label == label &&
      other.soundId == soundId &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(type, id, icon, label, soundId, width, height);
}

