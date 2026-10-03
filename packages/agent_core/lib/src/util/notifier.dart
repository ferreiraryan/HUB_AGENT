// packages/agent_core/lib/src/util/notifier.dart

class AgentNotifier<T> {
  T _value;
  final _listeners = <void Function(T)>[];

  AgentNotifier(this._value);

  T get value => _value;

  set value(T v) {
    if (v == _value) return;
    _value = v;
    for (final l in _listeners) {
      l(v);
    }
  }

  void addListener(void Function(T) l) => _listeners.add(l);
  void removeListener(void Function(T) l) => _listeners.remove(l);
}
