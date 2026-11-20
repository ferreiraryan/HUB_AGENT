import 'dart:async';
import 'dart:math';

import '../../models/todo_state.dart';
import 'todo_repository.dart';

class TodoService {
  final TodoRepository repository;
  TodoState _state = TodoState.empty;
  final _controller = StreamController<TodoState>.broadcast();
  final _rnd = Random();
  bool _initialized = false;

  TodoService({required this.repository});

  TodoState get current => _state;
  Stream<TodoState> get changes => _controller.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _state = await repository.load();
    if (!_controller.isClosed) _controller.add(_state);
  }

  Future<void> addItem(String text) async {
    final sanitized = text.trim();
    if (sanitized.isEmpty) return;
    final truncated = sanitized.length > 120 ? sanitized.substring(0, 120) : sanitized;

    final now = DateTime.now().millisecondsSinceEpoch;
    final randHex = _rnd.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final newItem = TodoItem(
      id: 'todo_${now}_$randHex',
      text: truncated,
      done: false,
      createdAt: now,
    );

    final nextItems = [newItem, ..._state.items];
    _state = TodoState.fromItems(nextItems);
    await repository.save(_state);
    if (!_controller.isClosed) _controller.add(_state);
  }

  Future<void> toggleItem(String itemId) async {
    final index = _state.items.indexWhere((it) => it.id == itemId);
    if (index < 0) return;

    final currentItem = _state.items[index];
    final updated = currentItem.copyWith(done: !currentItem.done);

    final nextItems = List<TodoItem>.of(_state.items);
    nextItems[index] = updated;

    _state = TodoState.fromItems(nextItems);
    await repository.save(_state);
    if (!_controller.isClosed) _controller.add(_state);
  }

  Future<void> removeItem(String itemId) async {
    final nextItems = _state.items.where((it) => it.id != itemId).toList();
    if (nextItems.length == _state.items.length) return;

    _state = TodoState.fromItems(nextItems);
    await repository.save(_state);
    if (!_controller.isClosed) _controller.add(_state);
  }

  Future<void> clearDone() async {
    final nextItems = _state.items.where((it) => !it.done).toList();
    if (nextItems.length == _state.items.length) return;

    _state = TodoState.fromItems(nextItems);
    await repository.save(_state);
    if (!_controller.isClosed) _controller.add(_state);
  }

  Future<void> dispose() async {
    await repository.flush();
    await _controller.close();
  }
}

