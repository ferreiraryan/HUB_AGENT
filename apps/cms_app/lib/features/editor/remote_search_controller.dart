import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../system/window_controller.dart';

class RemoteSearchState {
  final bool isOpen;
  final String query;
  final bool wasHidden;

  const RemoteSearchState({
    this.isOpen = false,
    this.query = '',
    this.wasHidden = false,
  });

  RemoteSearchState copyWith({
    bool? isOpen,
    String? query,
    bool? wasHidden,
  }) {
    return RemoteSearchState(
      isOpen: isOpen ?? this.isOpen,
      query: query ?? this.query,
      wasHidden: wasHidden ?? this.wasHidden,
    );
  }
}

class RemoteSearchController extends Notifier<RemoteSearchState> {
  StreamSubscription<void>? _searchSub;

  @override
  RemoteSearchState build() {
    final runtime = ref.watch(agentRuntimeProvider);

    _searchSub?.cancel();
    _searchSub = runtime.remoteSearchPrompts.listen((_) {
      open();
    });

    ref.onDispose(() {
      _searchSub?.cancel();
    });

    return const RemoteSearchState();
  }

  Future<void> open() async {
    final wasHidden = await WindowController.instance.isHiddenOrMinimized();
    // 1. Atualiza o estado ANTES do resize da janela, garantindo que o Flutter
    // monte a visualização correta sem tentar redimensionar a EditorPage.
    state = RemoteSearchState(
      isOpen: true,
      query: '',
      wasHidden: wasHidden,
    );
    // 2. Agora redimensiona/exibe a janela de forma segura
    await WindowController.instance.openSpotlight(wasHidden: wasHidden);
  }

  void updateQuery(String query) {
    state = state.copyWith(query: query);
    ref.read(agentRuntimeProvider).publishSearchQuery(query, active: true);
  }

  Future<void> close() async {
    if (!state.isOpen) return;
    ref.read(agentRuntimeProvider).publishSearchQuery(state.query, active: false);
    await WindowController.instance.closeSpotlight();
    state = const RemoteSearchState(isOpen: false, query: '', wasHidden: false);
  }
}

final remoteSearchControllerProvider =
    NotifierProvider<RemoteSearchController, RemoteSearchState>(
  RemoteSearchController.new,
);
