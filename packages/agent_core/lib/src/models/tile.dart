import 'package:meta/meta.dart';

@immutable
sealed class Tile {
  final String id;
  final String icon;
  final String label;

  const Tile({required this.id, required this.icon, required this.label});

  String get type;
  Map<String, dynamic> toJson();

  factory Tile.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final icon = (json['icon'] as String?) ?? '';
    final label = (json['label'] as String?) ?? '';
    final type = (json['type'] as String?) ?? 'shortcut';

    return switch (type) {
      'shortcut' => ShortcutTile(id: id, icon: icon, label: label),
      'folder' => FolderTile(
          id: id,
          icon: icon,
          label: label,
          target: json['target'] as String,
        ),
      'back' => BackTile(id: id, icon: icon, label: label),
      'slider' => SliderTile(
          id: id,
          icon: icon,
          label: label,
          source: SliderSource.fromJson(
              (json['source'] as Map?)?.cast<String, dynamic>() ??
                  const {'kind': 'master_volume'}),
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
  });

  @override
  String get type => 'shortcut';

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'shortcut', 'id': id, 'icon': icon, 'label': label};

  ShortcutTile copyWith({String? id, String? icon, String? label}) =>
      ShortcutTile(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object o) =>
      o is ShortcutTile && o.id == id && o.icon == icon && o.label == label;

  @override
  int get hashCode => Object.hash(type, id, icon, label);
}

final class FolderTile extends Tile {
  final String target;

  const FolderTile({
    required super.id,
    required super.icon,
    required super.label,
    required this.target,
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
      };

  FolderTile copyWith(
          {String? id, String? icon, String? label, String? target}) =>
      FolderTile(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
        target: target ?? this.target,
      );

  @override
  bool operator ==(Object o) =>
      o is FolderTile &&
      o.id == id &&
      o.icon == icon &&
      o.label == label &&
      o.target == target;

  @override
  int get hashCode => Object.hash(type, id, icon, label, target);
}

final class BackTile extends Tile {
  const BackTile({
    required super.id,
    required super.icon,
    required super.label,
  });

  @override
  String get type => 'back';

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'back', 'id': id, 'icon': icon, 'label': label};

  BackTile copyWith({String? id, String? icon, String? label}) => BackTile(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object o) =>
      o is BackTile && o.id == id && o.icon == icon && o.label == label;

  @override
  int get hashCode => Object.hash(type, id, icon, label);
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
  bool operator ==(Object o) =>
      o is SliderSource &&
      o.kind == kind &&
      o.match == match &&
      (o.cmd == null && cmd == null ||
          o.cmd != null &&
              cmd != null &&
              o.cmd!.join('\u0000') == cmd!.join('\u0000'));

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
        'source': source.toJson(),
      };

  SliderTile copyWith({
    String? id,
    String? icon,
    String? label,
    SliderSource? source,
  }) =>
      SliderTile(
        id: id ?? this.id,
        icon: icon ?? this.icon,
        label: label ?? this.label,
        source: source ?? this.source,
      );

  @override
  bool operator ==(Object o) =>
      o is SliderTile &&
      o.id == id &&
      o.icon == icon &&
      o.label == label &&
      o.source == source;

  @override
  int get hashCode => Object.hash(type, id, icon, label, source);
}
