import 'dart:convert';
import 'dart:io';

import '../../models/todo_state.dart';

class TodoRepository {
  final File file;
  Future<void> _writeChain = Future.value();

  TodoRepository({required this.file});

  Future<TodoState> load() async {
    try {
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          return TodoState.fromJson(json);
        }
      }
    } catch (e) {
      final backup = File('${file.path}.bak');
      try {
        if (await file.exists()) await file.copy(backup.path);
      } catch (_) {}
      stderr.writeln('todos.json invalido ($e). Backup em ${backup.path}');
    }

    final initial = TodoState.empty;
    await save(initial);
    return initial;
  }

  Future<void> save(TodoState state) {
    _writeChain = _writeChain.then((_) async {
      await _writeNow(state);
    }).catchError((Object e) {
      stderr.writeln('falha ao gravar todos.json: $e');
    });
    return _writeChain;
  }

  Future<void> _writeNow(TodoState state) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await tmp.writeAsString(encoder.convert(state.toJson()), flush: true);
    await tmp.rename(file.path);
  }

  Future<void> flush() async {
    await _writeChain;
  }
}

