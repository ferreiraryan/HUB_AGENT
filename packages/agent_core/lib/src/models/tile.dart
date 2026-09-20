import 'package:meta/meta.dart';

/// Um botao da grid do dashboard.
///
/// IMPORTANTE: nenhum subtipo carrega `cmd`. O contrato canonico do tablet nao
/// tem esse campo — o tablet so publica `{action: <id>}` e o agente resolve o
/// que executar consultando [Layout.bindings], que fica no disco e nunca vai
/// para o MQTT.
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
    // Contrato: `type` omitido significa "shortcut".
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
      _ => throw FormatException('tipo de tile desconhecido: "$type"'),
    };
  }
}

/// Dispara `{action: <id>}` no tablet. O agente decide o que isso significa:
/// pode ser uma acao embutida (play_pause, next...) ou um binding de processo.
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

/// Navega para a pagina [target].
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

/// Volta para "home".
///
/// Opcional: o tablet injeta um back automatico em qualquer pagina != home que
/// nao tenha um. Existe aqui para quando o usuario quiser controlar a posicao.
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
