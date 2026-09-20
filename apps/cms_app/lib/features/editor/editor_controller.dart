import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class EditorState {
  final Layout layout;
  final String currentPage;
  final String? selectedTileId;
  final List<Layout> undoStack;
  final List<Layout> redoStack;
  final bool dirty;
  final Layout? externalLayout;

  const EditorState({
    required this.layout,
    this.currentPage = Layout.homePage,
    this.selectedTileId,
    this.undoStack = const [],
    this.redoStack = const [],
    this.dirty = false,
    this.externalLayout,
  });

  EditorState copyWith({
    Layout? layout,
    String? currentPage,
    String? Function()? selectedTileId,
    List<Layout>? undoStack,
    List<Layout>? redoStack,
    bool? dirty,
    Layout? Function()? externalLayout,
  }) {
    return EditorState(
      layout: layout ?? this.layout,
      currentPage: currentPage ?? this.currentPage,
      selectedTileId:
          selectedTileId != null ? selectedTileId() : this.selectedTileId,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      dirty: dirty ?? this.dirty,
      externalLayout:
          externalLayout != null ? externalLayout() : this.externalLayout,
    );
  }
}

class EditorController extends Notifier<EditorState> {
  Timer? _debounceTimer;
  Future<void> _writeChain = Future.value();

  @override
  EditorState build() {
    final repository = ref.read(agentRuntimeProvider).repository;

    Layout initialLayout;
    if (repository.isLoaded) {
      initialLayout = repository.current;
    } else {
      final config = ref.read(agentConfigProvider);
      initialLayout = Layout.initial(config.deviceId);
    }

    final sub = repository.changes.listen(_onRepositoryChange);

    ref.onDispose(() {
      _debounceTimer?.cancel();
      sub.cancel();
    });

    return EditorState(layout: initialLayout);
  }

  void _onRepositoryChange(Layout incoming) {
    if (incoming == state.layout) return;

    if (!state.dirty) {
      state = state.copyWith(layout: incoming);
    } else {
      state = state.copyWith(externalLayout: () => incoming);
    }
  }

  void _mutate(Layout Function(Layout) mutator) {
    final nextLayout = mutator(state.layout);
    if (nextLayout == state.layout) return;

    final newUndo = List<Layout>.of(state.undoStack)..add(state.layout);
    if (newUndo.length > 50) {
      newUndo.removeAt(0);
    }

    state = state.copyWith(
      layout: nextLayout,
      undoStack: newUndo,
      redoStack: const [],
      dirty: true,
    );

    _scheduleSave(nextLayout);
  }

  void _scheduleSave(Layout layout) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _writeChain = _writeChain.then((_) async {
        ref.read(agentRuntimeProvider).repository.save(layout);
      });
    });
  }

  void upsertTile(String pageId, Tile tile) =>
      _mutate((l) => l.upsertTile(pageId, tile));

  void removeTile(String pageId, String tileId) =>
      _mutate((l) => l.removeTile(pageId, tileId));

  void reorderTile(String pageId, int oldIndex, int newIndex) =>
      _mutate((l) => l.reorderTile(pageId, oldIndex, newIndex));

  void moveTile(String fromPage, String tileId, String toPage, {int? index}) =>
      _mutate((l) => l.moveTile(fromPage, tileId, toPage, index: index));

  void addPage(String pageId) => _mutate((l) => l.addPage(pageId));

  void removePage(String pageId) => _mutate((l) => l.removePage(pageId));

  void setBinding(String id, List<String>? argv) =>
      _mutate((l) => l.setBinding(id, argv));

  void updateTheme(HubTheme theme) => _mutate((l) => l.copyWith(theme: theme));

  void undo() {
    if (state.undoStack.isEmpty) return;

    final popped = state.undoStack.last;
    final newUndo = List<Layout>.of(state.undoStack)..removeLast();
    final newRedo = List<Layout>.of(state.redoStack)..add(state.layout);

    state = state.copyWith(
      layout: popped,
      undoStack: newUndo,
      redoStack: newRedo,
      dirty: true,
    );

    _scheduleSave(popped);
  }

  void redo() {
    if (state.redoStack.isEmpty) return;

    final popped = state.redoStack.last;
    final newRedo = List<Layout>.of(state.redoStack)..removeLast();
    final newUndo = List<Layout>.of(state.undoStack)..add(state.layout);

    state = state.copyWith(
      layout: popped,
      undoStack: newUndo,
      redoStack: newRedo,
      dirty: true,
    );

    _scheduleSave(popped);
  }

  void selectTile(String? id) {
    state = state.copyWith(selectedTileId: () => id);
  }

  void selectPage(String pageId) {
    state = state.copyWith(currentPage: pageId);
  }

  Future<void> flush() async {
    _debounceTimer?.cancel();
    await _writeChain;
    final repo = ref.read(agentRuntimeProvider).repository;
    repo.save(state.layout);
    await repo.flush();
    state = state.copyWith(dirty: false);
  }

  void discardExternal() {
    state = state.copyWith(externalLayout: () => null);
  }

  void acceptExternal() {
    final external = state.externalLayout;
    if (external == null) return;

    state = state.copyWith(
      layout: external,
      externalLayout: () => null,
      dirty: false,
    );
  }
}

final editorControllerProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);
