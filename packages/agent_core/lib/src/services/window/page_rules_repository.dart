import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Repositório isolado para regras de Auto-Switch de páginas por app ativo
/// (`page_rules.json`), mantendo o contrato Golden de `layout.json` intacto.
///
/// Formato: `{"dev": ["code", "cursor"], "games": ["steam", "valorant"]}`.
class PageRulesRepository {
  final File file;
  final _ctl = StreamController<Map<String, List<String>>>.broadcast();
  Map<String, List<String>> _rules = const {};

  PageRulesRepository({required this.file});

  Stream<Map<String, List<String>>> get changes => _ctl.stream;
  Map<String, List<String>> get current => _rules;

  Future<void> load() async {
    try {
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final parsed = <String, List<String>>{};
          for (final e in decoded.entries) {
            if (e.value is List) {
              final list = (e.value as List)
                  .map((x) => x.toString().trim().toLowerCase())
                  .where((x) => x.isNotEmpty)
                  .toList();
              if (list.isNotEmpty) {
                parsed[e.key.toString()] = List.unmodifiable(list);
              }
            }
          }
          _rules = Map.unmodifiable(parsed);
        }
      }
    } catch (_) {
      _rules = const {};
    }
  }

  Future<void> setTriggersForPage(String pageId, List<String> processes) async {
    final next = Map<String, List<String>>.of(_rules);
    final cleaned = processes
        .map((p) => p.trim().toLowerCase().replaceAll('.exe', ''))
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
    if (cleaned.isEmpty) {
      next.remove(pageId);
    } else {
      next[pageId] = List.unmodifiable(cleaned);
    }
    _rules = Map.unmodifiable(next);
    await _writeAtomic();
    if (!_ctl.isClosed) _ctl.add(_rules);
  }

  /// Encontra a página associada a um nome de processo (ex: `"code"`).
  String? matchPageForProcess(String processName) {
    final norm = processName.trim().toLowerCase().replaceAll('.exe', '');
    if (norm.isEmpty) return null;
    for (final entry in _rules.entries) {
      for (final trigger in entry.value) {
        if (norm == trigger || norm.contains(trigger)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  Future<void> _writeAtomic() async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(_rules));
    await tmp.rename(file.path);
  }

  Future<void> dispose() async {
    await _ctl.close();
  }
}
