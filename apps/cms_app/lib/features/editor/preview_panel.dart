import 'dart:math' as math;
import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'create_tile_dialog.dart';
import 'editor_controller.dart';
import 'tile_card.dart';
import 'tile_grid_layout.dart';

class PreviewPanel extends ConsumerStatefulWidget {
  const PreviewPanel({super.key});

  @override
  ConsumerState<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends ConsumerState<PreviewPanel> {
  (int col, int row, int w, int h)? _targetCell;
  double _zoom = 1.0;

  Widget _buildZoomToolbar() {
    final zoomPct = (_zoom * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 6, right: 4),
            child: Text(
              'Grade 6×3',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(width: 1, height: 14, color: Colors.white12),
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Diminuir escala visual (mantém 6 colunas)',
            onPressed: _zoom > 0.61
                ? () => setState(() => _zoom = math.max(0.6, _zoom - 0.1))
                : null,
          ),
          InkWell(
            onTap: () => setState(() => _zoom = 1.0),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '$zoomPct%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Aumentar escala visual (mantém 6 colunas)',
            onPressed: _zoom < 1.39
                ? () => setState(() => _zoom = math.min(1.4, _zoom + 0.1))
                : null,
          ),
        ],
      ),
    );
  }

  Tile? _findTileInLayout(Layout layout, String pageId, String tileId) {
    for (final t in layout.tilesOf(pageId)) {
      if (t.id == tileId) return t;
    }
    for (final list in layout.pages.values) {
      for (final t in list) {
        if (t.id == tileId) return t;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorControllerProvider);
    final layout = state.layout;
    final theme = layout.theme;

    final realTiles = layout.tilesOf(state.currentPage);
    final tiles = List<Tile>.from(realTiles);

    final needsAutoBack = state.currentPage != Layout.homePage &&
        !tiles.any((t) => t is BackTile);

    if (needsAutoBack) {
      tiles.insert(
        0,
        const BackTile(
          id: '__auto_back__',
          icon: '⬅️',
          label: 'Voltar',
          x: 0,
          y: 0,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const marginH = 20.0;
        const marginV = 16.0;
        const zoomBarHeight = 42.0;

        final availW = math.max(100.0, constraints.maxWidth - (marginH * 2));
        final availH = math.max(
            100.0, constraints.maxHeight - (marginV * 2) - zoomBarHeight);

        // Proporção do painel de atalhos do tablet (6 colunas × 3 linhas visíveis)
        const aspect = 16.0 / 10.0;
        double tabletW = availW;
        double tabletH = tabletW / aspect;
        if (tabletH > availH) {
          tabletH = availH;
          tabletW = tabletH * aspect;
        }

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildZoomToolbar(),
              SizedBox(
                width: tabletW,
                height: tabletH,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF181825),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFF313244), width: 4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Color(theme.bgColor),
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  layout.deviceName,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.white54),
                                ),
                              ),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, gridConstraints) {
                                    final boardWidth =
                                        gridConstraints.maxWidth * _zoom;
                                    final metrics = TileGridMetrics.calculate(
                                      tiles: tiles,
                                      containerWidth: boardWidth,
                                      crossAxisCount: kGridColumns,
                                      minRows: kMinGridRows,
                                      spacing: 12 * _zoom,
                                      padding: 16 * _zoom,
                                    );

                                    final contentHeight = math.max(
                                      gridConstraints.maxHeight,
                                      metrics.totalHeight,
                                    );

                                    return SingleChildScrollView(
                                      child: Center(
                                        child: SizedBox(
                                          width: boardWidth,
                                          height: contentHeight,
                                          child: Builder(
                                            builder: (boardContext) {
                                              return DragTarget<
                                                  TileDragPayload>(
                                                onWillAcceptWithDetails: (_) =>
                                                    true,
                                                onMove: (details) {
                                                  final box = boardContext
                                                          .findRenderObject()
                                                      as RenderBox?;
                                                  if (box == null) return;
                                                  final local =
                                                      box.globalToLocal(
                                                          details.offset);
                                                  final dragged =
                                                      _findTileInLayout(
                                                    layout,
                                                    details.data.fromPage,
                                                    details.data.tileId,
                                                  );
                                                  final dw = (dragged?.width ??
                                                          1)
                                                      .clamp(1, kGridColumns);
                                                  final dh = (dragged?.height ??
                                                          1)
                                                      .clamp(1, 2);

                                                  var (col, row) =
                                                      metrics.cellAtOffset(
                                                    local,
                                                    tileWidth: dw,
                                                    tileHeight: dh,
                                                  );
                                                  if (needsAutoBack &&
                                                      col == 0 &&
                                                      row == 0) {
                                                    col = 1;
                                                  }
                                                  final nextTarget =
                                                      (col, row, dw, dh);
                                                  if (_targetCell !=
                                                      nextTarget) {
                                                    setState(() => _targetCell =
                                                        nextTarget);
                                                  }
                                                },
                                                onLeave: (_) => setState(
                                                    () => _targetCell = null),
                                                onAcceptWithDetails: (d) {
                                                  final target = _targetCell;
                                                  setState(
                                                      () => _targetCell = null);
                                                  if (target == null) return;

                                                  final payload = d.data;
                                                  final notifier = ref.read(
                                                      editorControllerProvider
                                                          .notifier);
                                                  notifier.moveTileToCell(
                                                    payload.fromPage,
                                                    payload.tileId,
                                                    state.currentPage,
                                                    target.$1,
                                                    target.$2,
                                                  );
                                                },
                                                builder: (context, candidate,
                                                    rejected) {
                                                  return Stack(
                                                    children: [
                                                      // Grade de quadrados base (clicáveis para adicionar em célula vazia)
                                                      for (int r = 0;
                                                          r <
                                                              metrics
                                                                  .visibleRowCount;
                                                          r++)
                                                        for (int c = 0;
                                                            c <
                                                                metrics
                                                                    .crossAxisCount;
                                                            c++)
                                                          Positioned.fromRect(
                                                            rect: metrics
                                                                .getSpanRect(
                                                                    c, r, 1, 1),
                                                            child:
                                                                _EmptyGridCell(
                                                              col: c,
                                                              row: r,
                                                              onTap: () =>
                                                                  _showAddMenu(
                                                                context,
                                                                ref,
                                                                state,
                                                                targetCell: (
                                                                  c,
                                                                  r
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      // Realce de destino durante o drag
                                                      if (_targetCell != null)
                                                        Positioned.fromRect(
                                                          rect: metrics
                                                              .getSpanRect(
                                                            _targetCell!.$1,
                                                            _targetCell!.$2,
                                                            _targetCell!.$3,
                                                            _targetCell!.$4,
                                                          ),
                                                          child:
                                                              _CellTargetHighlight(
                                                            accentColor: Color(
                                                                theme
                                                                    .accentColor),
                                                          ),
                                                        ),
                                                      // Widgets posicionados na grade
                                                      for (final p in metrics
                                                          .placements)
                                                        Positioned.fromRect(
                                                          rect: p.getRect(
                                                            pad:
                                                                metrics.padding,
                                                            spacing:
                                                                metrics.spacing,
                                                            cellWidth: metrics
                                                                .cellWidth,
                                                            cellHeight: metrics
                                                                .cellHeight,
                                                          ),
                                                          child: _buildTileCard(
                                                            context,
                                                            ref,
                                                            state,
                                                            theme,
                                                            p.tile,
                                                            p.index,
                                                            needsAutoBack,
                                                          ),
                                                        ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: FloatingActionButton.small(
                              tooltip: 'Adicionar widget no próximo quadrado livre',
                              onPressed: () =>
                                  _showAddMenu(context, ref, state),
                              child: const Icon(Icons.add),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTileCard(
    BuildContext context,
    WidgetRef ref,
    EditorState state,
    HubTheme theme,
    Tile tile,
    int index,
    bool needsAutoBack,
  ) {
    final isAutoBack = needsAutoBack && tile.id == '__auto_back__';

    Widget card = TileCard(
      tile: tile,
      theme: theme,
      index: index,
      selected: state.selectedTileId == tile.id,
      fromPage: isAutoBack ? null : state.currentPage,
      onTap: () {
        final notifier = ref.read(editorControllerProvider.notifier);
        if (isAutoBack) {
          notifier.selectPage(Layout.homePage);
          return;
        }
        notifier.selectTile(tile.id);
      },
      onDoubleTap: () {
        final notifier = ref.read(editorControllerProvider.notifier);
        if (tile is FolderTile) {
          notifier.selectPage(tile.target);
        } else if (tile is BackTile) {
          notifier.selectPage(Layout.homePage);
        }
      },
    );

    if (isAutoBack) {
      card = Opacity(
        opacity: 0.6,
        child: Stack(
          children: [
            Positioned.fill(child: card),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('auto',
                    style: TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }

    return card;
  }

  void _showAddMenu(
    BuildContext context,
    WidgetRef ref,
    EditorState state, {
    (int col, int row)? targetCell,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (targetCell != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_on, size: 16, color: Colors.white54),
                      const SizedBox(width: 8),
                      Text(
                        'Adicionar na coluna ${targetCell.$1 + 1}, linha ${targetCell.$2 + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.flash_on),
                title: const Text('Atalho'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'shortcut', context,
                      targetCell: targetCell);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Pasta'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'folder', context,
                      targetCell: targetCell);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Voltar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'back', context,
                      targetCell: targetCell);
                },
              ),
              ListTile(
                leading: const Icon(Icons.linear_scale),
                title: const Text('Slider'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'slider', context,
                      targetCell: targetCell);
                },
              ),
              ListTile(
                leading: const Icon(Icons.monitor_heart),
                title: const Text('Stat (CPU/RAM/Disco)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'stat', context,
                      targetCell: targetCell);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.music_note, color: Colors.deepPurpleAccent),
                title: const Text('Som (Sound Pad)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'sound', context,
                      targetCell: targetCell);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.toggle_on_outlined, color: Colors.tealAccent),
                title: const Text('Alternador (Toggle A/B)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'toggle', context,
                      targetCell: targetCell);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCreateTile(
    WidgetRef ref,
    EditorState state,
    String type,
    BuildContext context, {
    (int col, int row)? targetCell,
  }) async {
    var tile = await showCreateTileDialog(
      context: context,
      type: type,
      state: state,
    );
    if (tile == null) return;

    final notifier = ref.read(editorControllerProvider.notifier);
    if (targetCell != null) {
      final col = targetCell.$1.clamp(0, kGridColumns - tile.width);
      final row = math.max(0, targetCell.$2);
      tile = tile.copyWithPosition(x: col, y: row);
    }
    notifier.upsertTile(state.currentPage, tile);
    if (targetCell != null) {
      notifier.moveTileToCell(
        state.currentPage,
        tile.id,
        state.currentPage,
        targetCell.$1,
        targetCell.$2,
      );
    }
    notifier.selectTile(tile.id);
  }
}

class _EmptyGridCell extends StatefulWidget {
  final int col;
  final int row;
  final VoidCallback onTap;

  const _EmptyGridCell({
    required this.col,
    required this.row,
    required this.onTap,
  });

  @override
  State<_EmptyGridCell> createState() => _EmptyGridCellState();
}

class _EmptyGridCellState extends State<_EmptyGridCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.015),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.07),
              width: 1,
            ),
          ),
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hovered ? 0.6 : 0.15,
              child: const Icon(
                Icons.add,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CellTargetHighlight extends StatelessWidget {
  final Color accentColor;

  const _CellTargetHighlight({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.9),
            width: 2,
          ),
        ),
      ),
    );
  }
}
