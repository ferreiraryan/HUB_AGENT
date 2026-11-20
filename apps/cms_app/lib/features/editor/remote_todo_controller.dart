import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../system/window_controller.dart';
import 'remote_search_controller.dart';

class RemoteTodoState {
  final bool isOpen;
  final bool wasHidden;

  const RemoteTodoState({
    this.isOpen = false,
    this.wasHidden = false,
  });

  RemoteTodoState copyWith({
    bool? isOpen,
    bool? wasHidden,
  }) {
    return RemoteTodoState(
      isOpen: isOpen ?? this.isOpen,
      wasHidden: wasHidden ?? this.wasHidden,
    );
  }
}

class RemoteTodoController extends Notifier<RemoteTodoState> {
  StreamSubscription<void>? _todoSub;

  @override
  RemoteTodoState build() {
    final runtime = ref.watch(agentRuntimeProvider);

    _todoSub?.cancel();
    _todoSub = runtime.remoteTodoPrompts.listen((_) {
      open();
    });

    ref.onDispose(() {
      _todoSub?.cancel();
    });

    return const RemoteTodoState();
  }

  Future<void> open() async {
    // Se a busca estiver aberta, fecha antes
    if (ref.read(remoteSearchControllerProvider).isOpen) {
      await ref.read(remoteSearchControllerProvider.notifier).close();
    }

    final wasHidden = await WindowController.instance.isHiddenOrMinimized();
    state = RemoteTodoState(
      isOpen: true,
      wasHidden: wasHidden,
    );
    await WindowController.instance.openSpotlight(
      wasHidden: wasHidden,
      title: 'Nova Tarefa — Hub Agent',
      onBlur: close,
    );
  }

  Future<void> submit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      await ref.read(agentRuntimeProvider).todo.addItem(trimmed);
    }
    await close();
  }

  Future<void> close() async {
    if (!state.isOpen) return;
    await WindowController.instance.closeSpotlight();
    state = const RemoteTodoState(isOpen: false, wasHidden: false);
  }
}

final remoteTodoControllerProvider =
    NotifierProvider<RemoteTodoController, RemoteTodoState>(
  RemoteTodoController.new,
);

