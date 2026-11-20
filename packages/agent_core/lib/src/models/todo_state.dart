import 'package:meta/meta.dart';

@immutable
class TodoItem {
  final String id;
  final String text;
  final bool done;
  final int createdAt;

  const TodoItem({
    required this.id,
    required this.text,
    this.done = false,
    required this.createdAt,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'] as String,
        text: (json['text'] as String?) ?? '',
        done: (json['done'] as bool?) ?? false,
        createdAt: (json['created_at'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'done': done,
        'created_at': createdAt,
      };

  TodoItem copyWith({
    String? id,
    String? text,
    bool? done,
    int? createdAt,
  }) =>
      TodoItem(
        id: id ?? this.id,
        text: text ?? this.text,
        done: done ?? this.done,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoItem &&
          other.id == id &&
          other.text == text &&
          other.done == done &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, text, done, createdAt);

  @override
  String toString() => 'TodoItem(id: $id, text: "$text", done: $done)';
}

@immutable
class TodoState {
  final int pending;
  final int total;
  final List<TodoItem> items;

  const TodoState({
    required this.pending,
    required this.total,
    required this.items,
  });

  factory TodoState.fromItems(List<TodoItem> items) {
    final pendingCount = items.where((it) => !it.done).length;
    return TodoState(
      pending: pendingCount,
      total: items.length,
      items: List.unmodifiable(items),
    );
  }

  factory TodoState.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    final items = rawItems
        .map((e) => TodoItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return TodoState.fromItems(items);
  }

  Map<String, dynamic> toJson() => {
        'pending': pending,
        'total': total,
        'items': items.map((it) => it.toJson()).toList(),
      };

  static const empty = TodoState(pending: 0, total: 0, items: []);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoState &&
          other.pending == pending &&
          other.total == total &&
          _listEquals(other.items, items);

  static bool _listEquals(List<TodoItem> a, List<TodoItem> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(pending, total, Object.hashAll(items));

  @override
  String toString() => 'TodoState(pending: $pending, total: $total, items: ${items.length})';
}

