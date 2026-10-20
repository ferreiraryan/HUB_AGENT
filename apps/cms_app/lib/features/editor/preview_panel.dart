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
  int? _targetGap;
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
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Diminuir tamanho dos widgets (Zoom -)',
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
            tooltip: 'Aumentar tamanho dos widgets (Zoom +)',
            onPressed: _zoom < 1.39
                ? () => setState(() => _zoom = math.min(1.4, _zoom + 0.1))
                : null,
          ),
        ],
      ),
    );
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
        const BackTile(id: '__auto_back__', icon: '⬅️', label: 'Voltar'),
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

        // AspectRatio 16 / 10
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
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x66000000),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
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
                                child: tiles.isEmpty && !needsAutoBack
                                    ? const Center(
                                        child: Text(
                                          'Página vazia',
                                          style:
                                              TextStyle(color: Colors.white54),
                                        ),
                                      )
                                    : LayoutBuilder(
                                        builder: (context, gridConstraints) {
                                          final metrics =
                                              TileGridMetrics.calculate(
                                            tiles: tiles,
                                            containerWidth:
                                                gridConstraints.maxWidth,
                                            maxCrossAxisExtent: 140 * _zoom,
                                            spacing: 16 * _zoom,
                                            padding: 16 * _zoom,
                                          );

                                    return DragTarget<TileDragPayload>(
                                      onWillAcceptWithDetails: (_) => true,
                                      onMove: (details) {
                                        final box = context.findRenderObject()
                                            as RenderBox?;
                                        if (box == null) return;
                                        final local =
                                            box.globalToLocal(details.offset);
                                        var gap = metrics.findDropIndex(local,
                                            tileCount: tiles.length);

                                        if (needsAutoBack && gap == 0) gap = 1;

                                        if (gap != _targetGap) {
                                          setState(() => _targetGap = gap);
                                        }
                                      },
                                      onLeave: (_) =>
                                          setState(() => _targetGap = null),
                                      onAcceptWithDetails: (d) {
                                        final gap = _targetGap;
                                        if (gap == null) return;

                                        final payload = d.data;
                                        final origemIndex = state.layout
                                            .tilesOf(state.currentPage)
                                            .indexWhere(
                                                (t) => t.id == payload.tileId);
                                        final notifier = ref.read(
                                            editorControllerProvider.notifier);

                                        final realGap =
                                            needsAutoBack ? gap - 1 : gap;

                                        if (payload.fromPage ==
                                            state.currentPage) {
                                          if (origemIndex < 0) return;
                                          var target = realGap;
                                          if (origemIndex < target) target -= 1;
                                          if (origemIndex == target) {
                                            setState(() => _targetGap = null);
                                            return;
                                          }
                                          notifier.reorderTile(
                                              state.currentPage,
                                              origemIndex,
                                              target);
                                        } else {
                                          notifier.moveTile(payload.fromPage,
                                              payload.tileId, state.currentPage,
                                              index: realGap);
                                        }
                                        setState(() => _targetGap = null);
                                      },
                                      builder: (context, candidate, rejected) {
                                        final contentHeight = math.max(
                                            gridConstraints.maxHeight,
                                            metrics.totalHeight);

                                        return SingleChildScrollView(
                                          child: SizedBox(
                                            width: gridConstraints.maxWidth,
                                            height: contentHeight,
                                            child: Stack(
                                              children: [
                                                for (final p in metrics.placements) ...[
                                                  Positioned.fromRect(
                                                    rect: p.getRect(
                                                      pad: metrics.padding,
                                                      spacing: metrics.spacing,
                                                      cellWidth: metrics.cellWidth,
                                                      cellHeight: metrics.cellHeight,
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
                                                if (_targetGap != null)
                                                  _GapPlaceholder(
                                                    gap: _targetGap!,
                                                    metrics: metrics,
                                                    accentColor: Color(theme.accentColor),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
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
                        onPressed: () => _showAddMenu(context, ref, state),
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
    final isAutoBack = needsAutoBack && index == 0;

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

  void _showAddMenu(BuildContext context, WidgetRef ref, EditorState state) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flash_on),
                title: const Text('Atalho'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'shortcut', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Pasta'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'folder', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Voltar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'back', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.linear_scale),
                title: const Text('Slider'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'slider', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.monitor_heart),
                title: const Text('Stat (CPU/RAM/Disco)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'stat', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.music_note, color: Colors.deepPurpleAccent),
                title: const Text('Som (Sound Pad)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleCreateTile(ref, state, 'sound', context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCreateTile(
      WidgetRef ref, EditorState state, String type, BuildContext context) async {
    final tile = await showCreateTileDialog(
      context: context,
      type: type,
      state: state,
    );
    if (tile == null) return;

    final notifier = ref.read(editorControllerProvider.notifier);
    notifier.upsertTile(state.currentPage, tile);
    notifier.selectTile(tile.id);
  }
}

class _GapPlaceholder extends StatelessWidget {
  final int gap;
  final TileGridMetrics metrics;
  final Color accentColor;

  const _GapPlaceholder({
    required this.gap,
    required this.metrics,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (metrics.placements.isEmpty) {
      return Positioned(
        left: metrics.padding,
        top: metrics.padding,
        width: 4,
        height: metrics.cellHeight,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    final double left;
    final double top;
    final double height;

    if (gap < metrics.placements.length) {
      final p = metrics.placements[gap];
      final rect = p.getRect(
        pad: metrics.padding,
        spacing: metrics.spacing,
        cellWidth: metrics.cellWidth,
        cellHeight: metrics.cellHeight,
      );
      left = rect.left - (metrics.spacing / 2) - 2;
      top = rect.top;
      height = rect.height;
    } else {
      final last = metrics.placements.last;
      final rect = last.getRect(
        pad: metrics.padding,
        spacing: metrics.spacing,
        cellWidth: metrics.cellWidth,
        cellHeight: metrics.cellHeight,
      );
      left = rect.right + (metrics.spacing / 2) - 2;
      top = rect.top;
      height = rect.height;
    }

    return Positioned(
      left: left.clamp(0.0, double.infinity),
      top: top.clamp(0.0, double.infinity),
      width: 4,
      height: height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
