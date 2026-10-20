import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'tile_grid_layout.dart';

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

  void substituirLayout(Layout novo, {bool preserveBindings = false}) {
    var aplicar = novo;

    if (preserveBindings) {
      final bindingsMesclados = <String, List<List<String>>>{};

      final idsNoNovo =
          novo.pages.values.expand((l) => l).map((t) => t.id).toSet();

      for (final id in idsNoNovo) {
        final antigo = state.layout.bindingFor(id);
        final novoB = novo.bindingFor(id);

        if (novoB != null && novoB.isNotEmpty) {
          bindingsMesclados[id] = novoB;
        } else if (antigo != null && antigo.isNotEmpty) {
          bindingsMesclados[id] = antigo;
        }
      }

      aplicar = novo.copyWith(bindings: bindingsMesclados);
    }

    _mutate((_) => aplicar);

    if (!aplicar.pages.containsKey(state.currentPage)) {
      selectPage(Layout.homePage);
    }

    final tileAinda = aplicar
        .tilesOf(state.currentPage)
        .any((t) => t.id == state.selectedTileId);
    if (!tileAinda) {
      selectTile(null);
    }
  }

  Set<(int, int)> _reservedCellsFor(Layout layout, String pageId) {
    final tiles = layout.tilesOf(pageId);
    final needsAutoBack =
        pageId != Layout.homePage && !tiles.any((t) => t is BackTile);
    return needsAutoBack ? const {(0, 0)} : const {};
  }

  void upsertTile(String pageId, Tile tile) => _mutate((l) {
        final existingTiles = l.tilesOf(pageId);
        final exists = existingTiles.any((t) => t.id == tile.id);
        var tileToSave = tile;
        if (!exists && (tile.x == null || tile.y == null)) {
          final reserved = _reservedCellsFor(l, pageId);
          final normalized = TileGridMetrics.normalizeCoordinates(
            existingTiles,
            cols: kGridColumns,
            reservedCells: reserved,
          );
          final metrics = TileGridMetrics.calculate(
            tiles: normalized,
            containerWidth: 1000,
            crossAxisCount: kGridColumns,
          );
          final free = metrics.findFirstFreeCell(
            tile.width,
            tile.height,
            reservedCells: reserved,
          );
          tileToSave = tile.copyWithPosition(x: free.$1, y: free.$2);
          final nextList = [...normalized, tileToSave];
          return l.setPageTiles(pageId, nextList);
        }
        return l.upsertTile(pageId, tileToSave);
      });

  void resizeTile(String pageId, String tileId, int newWidth, int newHeight) =>
      _mutate((l) {
        final reserved = _reservedCellsFor(l, pageId);
        final updatedTiles = TileGridMetrics.resizeTileWithCollisionResolution(
          tiles: l.tilesOf(pageId),
          tileId: tileId,
          newWidth: newWidth,
          newHeight: newHeight,
          cols: kGridColumns,
          reservedCells: reserved,
        );
        return l.setPageTiles(pageId, updatedTiles);
      });

  void moveTileToCell(
    String fromPage,
    String tileId,
    String toPage,
    int targetCol,
    int targetRow,
  ) =>
      _mutate((l) {
        if (fromPage == toPage) {
          final reserved = _reservedCellsFor(l, toPage);
          final updatedTiles = TileGridMetrics.placeOrSwapTile(
            tiles: l.tilesOf(toPage),
            tileId: tileId,
            targetCol: targetCol,
            targetRow: targetRow,
            cols: kGridColumns,
            reservedCells: reserved,
          );
          return l.setPageTiles(toPage, updatedTiles);
        } else {
          final sourceTiles = List<Tile>.of(l.tilesOf(fromPage));
          final idx = sourceTiles.indexWhere((t) => t.id == tileId);
          if (idx < 0) return l;
          final movingTile = sourceTiles.removeAt(idx);
          final next = l.setPageTiles(fromPage, sourceTiles);
          final reserved = _reservedCellsFor(next, toPage);
          final destWithMoving = [
            ...next.tilesOf(toPage),
            movingTile.copyWithPosition(x: targetCol, y: targetRow),
          ];
          final updatedDest = TileGridMetrics.placeOrSwapTile(
            tiles: destWithMoving,
            tileId: tileId,
            targetCol: targetCol,
            targetRow: targetRow,
            cols: kGridColumns,
            reservedCells: reserved,
          );
          return next.setPageTiles(toPage, updatedDest);
        }
      });

  void replaceTile(String pageId, String oldId, Tile newTile) {
    _mutate((l) => l.replaceTile(pageId, oldId, newTile));
    if (state.selectedTileId == oldId) {
      selectTile(newTile.id);
    }
  }

  void removeTile(String pageId, String tileId) =>
      _mutate((l) => l.removeTile(pageId, tileId));

  void reorderTile(String pageId, int oldIndex, int newIndex) =>
      _mutate((l) => l.reorderTile(pageId, oldIndex, newIndex));

  void moveTile(String fromPage, String tileId, String toPage, {int? index}) =>
      _mutate((l) => l.moveTile(fromPage, tileId, toPage, index: index));

  void addPage(String pageId) => _mutate((l) => l.addPage(pageId));

  void removePage(String pageId) => _mutate((l) => l.removePage(pageId));

  void setBinding(String id, List<List<String>>? cmds) =>
      _mutate((l) => l.setBinding(id, cmds));

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
    NotifierProvider<EditorController, EditorState>(() => EditorController());
