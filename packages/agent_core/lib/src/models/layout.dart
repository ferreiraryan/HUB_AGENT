import 'package:meta/meta.dart';

import 'hub_theme.dart';
import 'tile.dart';

enum IssueLevel { warning, error }

@immutable
class LayoutIssue {
  final IssueLevel level;
  final String message;
  final String? pageId;
  final String? tileId;

  const LayoutIssue(this.level, this.message, {this.pageId, this.tileId});

  @override
  String toString() => '[${level.name}] $message';
}

/// Estado completo do node.
///
/// DUAS SERIALIZACOES, de proposito:
///
///  - [toPublishJson] produz EXATAMENTE o contrato do tablet. E o que vai para
///    `nodes/$id/layout` com retain.
///  - [toDiskJson] e o superset persistido: contrato + [bindings].
///
/// [bindings] mapeia `id` de shortcut -> argv a executar. Ele existe porque o
/// contrato canonico nao tem campo `cmd` no tile, e mandar comando de shell
/// pelo MQTT seria uma superficie de ataque aberta: qualquer coisa com acesso
/// ao broker executaria codigo no PC. Com bindings, o tablet so consegue
/// disparar ids que o usuario ja autorizou no CMS.
@immutable
class Layout {
  final String deviceName;
  final HubTheme theme;

  /// Ordem de insercao importa: `home` sempre primeiro no JSON publicado.
  final Map<String, List<Tile>> pages;

  /// LOCAL. Nunca publicado. `id do shortcut` -> argv.
  final Map<String, List<String>> bindings;

  const Layout({
    required this.deviceName,
    required this.theme,
    required this.pages,
    this.bindings = const {},
  });

  static const String homePage = 'home';

  /// Ids tratados pelo agente e que, por isso, nao precisam de binding.
  static const Set<String> builtinActions = {
    'play_pause',
    'next',
    'prev',
    'set_volume',
    'set_app_volume',
  };

  factory Layout.initial(String deviceName) => Layout(
        deviceName: deviceName,
        theme: HubTheme.fallback,
        pages: {
          homePage: const [
            ShortcutTile(id: 'play_pause', icon: '\u{23EF}\u{FE0F}', label: 'Play'),
            ShortcutTile(id: 'next', icon: '\u{23ED}\u{FE0F}', label: 'Next'),
          ],
        },
      );

  /// Aceita tanto o JSON do disco (com bindings) quanto o puro do contrato.
  factory Layout.fromJson(Map<String, dynamic> json) {
    final rawPages = (json['pages'] as Map).cast<String, dynamic>();
    final pages = <String, List<Tile>>{};
    for (final e in rawPages.entries) {
      pages[e.key] = (e.value as List)
          .map((t) => Tile.fromJson((t as Map).cast<String, dynamic>()))
          .toList(growable: false);
    }

    final bindings = <String, List<String>>{};
    final rawBindings = json['bindings'];
    if (rawBindings is Map) {
      for (final e in rawBindings.entries) {
        bindings[e.key as String] = List<String>.from(e.value as List);
      }
    }

    return Layout(
      deviceName: json['deviceName'] as String,
      theme: HubTheme.fromJson((json['theme'] as Map).cast<String, dynamic>()),
      pages: pages,
      bindings: bindings,
    );
  }

  Map<String, dynamic> _orderedPages() {
    final ordered = <String, dynamic>{};
    if (pages.containsKey(homePage)) {
      ordered[homePage] = pages[homePage]!.map((t) => t.toJson()).toList();
    }
    for (final e in pages.entries) {
      if (e.key == homePage) continue;
      ordered[e.key] = e.value.map((t) => t.toJson()).toList();
    }
    return ordered;
  }

  /// O contrato canonico. Sem bindings, sem campo extra nenhum.
  Map<String, dynamic> toPublishJson() => {
        'deviceName': deviceName,
        'theme': theme.toJson(),
        'pages': _orderedPages(),
      };

  /// O que vai para o layout.json em disco.
  Map<String, dynamic> toDiskJson() => {
        'deviceName': deviceName,
        'theme': theme.toJson(),
        'pages': _orderedPages(),
        'bindings': {
          for (final e in bindings.entries) e.key: e.value,
        },
      };

  // ---------------------------------------------------------------- edicao

  List<Tile> tilesOf(String pageId) =>
      List.unmodifiable(pages[pageId] ?? const <Tile>[]);

  List<String>? bindingFor(String id) => bindings[id];

  Layout copyWith({
    String? deviceName,
    HubTheme? theme,
    Map<String, List<Tile>>? pages,
    Map<String, List<String>>? bindings,
  }) =>
      Layout(
        deviceName: deviceName ?? this.deviceName,
        theme: theme ?? this.theme,
        pages: pages ?? this.pages,
        bindings: bindings ?? this.bindings,
      );

  Map<String, List<Tile>> _mutablePages() =>
      {for (final e in pages.entries) e.key: List<Tile>.of(e.value)};

  Layout upsertTile(String pageId, Tile tile) {
    final next = _mutablePages();
    final list = next.putIfAbsent(pageId, () => <Tile>[]);
    final i = list.indexWhere((t) => t.id == tile.id);
    if (i >= 0) {
      list[i] = tile;
    } else {
      list.add(tile);
    }
    return copyWith(pages: next);
  }

  Layout removeTile(String pageId, String tileId) {
    final next = _mutablePages();
    next[pageId]?.removeWhere((t) => t.id == tileId);
    return copyWith(pages: next);
  }

  Layout reorderTile(String pageId, int oldIndex, int newIndex) {
    final next = _mutablePages();
    final list = next[pageId];
    if (list == null || oldIndex < 0 || oldIndex >= list.length) return this;
    final tile = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), tile);
    return copyWith(pages: next);
  }

  Layout moveTile(String fromPage, String tileId, String toPage, {int? index}) {
    final next = _mutablePages();
    final source = next[fromPage];
    if (source == null) return this;
    final i = source.indexWhere((t) => t.id == tileId);
    if (i < 0) return this;
    final tile = source.removeAt(i);
    final dest = next.putIfAbsent(toPage, () => <Tile>[]);
    dest.insert((index ?? dest.length).clamp(0, dest.length), tile);
    return copyWith(pages: next);
  }

  Layout addPage(String pageId) {
    if (pages.containsKey(pageId)) return this;
    final next = _mutablePages();
    next[pageId] = <Tile>[]; // o tablet injeta o back sozinho
    return copyWith(pages: next);
  }

  Layout removePage(String pageId) {
    if (pageId == homePage) return this;
    final next = _mutablePages();
    next.remove(pageId);
    for (final list in next.values) {
      list.removeWhere((t) => t is FolderTile && t.target == pageId);
    }
    return copyWith(pages: next);
  }

  /// Associa (ou remove, com [argv] nulo) um comando a um id de shortcut.
  Layout setBinding(String id, List<String>? argv) {
    final next = Map<String, List<String>>.of(bindings);
    if (argv == null || argv.isEmpty) {
      next.remove(id);
    } else {
      next[id] = List<String>.of(argv);
    }
    return copyWith(bindings: next);
  }

  // ------------------------------------------------------------ validacao

  /// Nao bloqueia publicacao: alimenta os badges de alerta do CMS.
  List<LayoutIssue> validate() {
    final issues = <LayoutIssue>[];

    if (!pages.containsKey(homePage)) {
      issues.add(const LayoutIssue(
          IssueLevel.error, 'a pagina "home" e obrigatoria'));
    }

    final reachable = <String>{homePage};
    // Ids podem repetir entre paginas (ex.: "next" na home e em media):
    // sao a MESMA acao. So duplicata na mesma pagina e erro.
    for (final entry in pages.entries) {
      final seen = <String>{};
      for (final tile in entry.value) {
        if (!seen.add(tile.id)) {
          issues.add(LayoutIssue(
              IssueLevel.error, 'id duplicado "${tile.id}" na mesma pagina',
              pageId: entry.key, tileId: tile.id));
        }
        switch (tile) {
          case FolderTile(:final target):
            reachable.add(target);
            if (!pages.containsKey(target)) {
              issues.add(LayoutIssue(IssueLevel.error,
                  'pasta aponta para "$target", que nao existe',
                  pageId: entry.key, tileId: tile.id));
            }
          case ShortcutTile():
            if (!builtinActions.contains(tile.id) &&
                !bindings.containsKey(tile.id)) {
              issues.add(LayoutIssue(IssueLevel.warning,
                  'shortcut sem comando associado: nada vai acontecer',
                  pageId: entry.key, tileId: tile.id));
            }
          case BackTile():
            break;
        }
        if (tile.label.trim().isEmpty) {
          issues.add(LayoutIssue(IssueLevel.warning, 'label vazio',
              pageId: entry.key, tileId: tile.id));
        }
      }
    }

    for (final pageId in pages.keys) {
      if (!reachable.contains(pageId)) {
        issues.add(LayoutIssue(IssueLevel.warning,
            'pagina orfa: nenhuma pasta aponta para ela',
            pageId: pageId));
      }
    }

    // Binding que nao corresponde a nenhum tile: lixo acumulado no disco.
    final allIds = pages.values.expand((l) => l).map((t) => t.id).toSet();
    for (final id in bindings.keys) {
      if (!allIds.contains(id)) {
        issues.add(LayoutIssue(
            IssueLevel.warning, 'binding orfao para id "$id"',
            tileId: id));
      }
    }

    return issues;
  }

  @override
  bool operator ==(Object o) {
    if (o is! Layout) return false;
    if (o.deviceName != deviceName || o.theme != theme) return false;
    if (o.pages.length != pages.length) return false;
    for (final e in pages.entries) {
      final other = o.pages[e.key];
      if (other == null || other.length != e.value.length) return false;
      for (var i = 0; i < other.length; i++) {
        if (other[i] != e.value[i]) return false;
      }
    }
    if (o.bindings.length != bindings.length) return false;
    for (final e in bindings.entries) {
      final other = o.bindings[e.key];
      if (other == null || other.join('\u0000') != e.value.join('\u0000')) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        deviceName,
        theme,
        Object.hashAll(pages.keys),
        Object.hashAll(pages.values.expand((l) => l)),
        Object.hashAll(bindings.keys),
      );
}
