import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_controller.dart';
import 'tile_card.dart';

class PreviewPanel extends ConsumerStatefulWidget {
  const PreviewPanel({super.key});

  @override
  ConsumerState<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends ConsumerState<PreviewPanel> {
  int? _targetGap;

  int _calcularGap(double dx, double dy, Size box, int nTiles) {
    const maxExtent = 140.0;
    const spacing = 16.0;
    const pad = 16.0;

    final usableW = box.width - pad * 2;
    final cols = (usableW / (maxExtent + spacing)).ceil().clamp(1, 999);
    final tileW = (usableW - (cols - 1) * spacing) / cols;
    final tileH = tileW;

    final lx = (dx - pad).clamp(0.0, usableW);
    final ly = (dy - pad).clamp(0.0, double.infinity);

    final colF = lx / (tileW + spacing);
    final col = colF.floor().clamp(0, cols - 1);
    final row = (ly / (tileH + spacing)).floor();

    final offsetX = lx - col * (tileW + spacing);
    final isRightHalf = offsetX > tileW / 2;

    var gap = row * cols + col;
    if (isRightHalf) gap += 1;

    return gap.clamp(0, nTiles);
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

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black, width: 12),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            layout.deviceName,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white54),
                          ),
                        ),
                        Expanded(
                          child: tiles.isEmpty && !needsAutoBack
                              ? const Center(
                                  child: Text(
                                    'Página vazia',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final boxSize = Size(constraints.maxWidth,
                                        constraints.maxHeight);

                                    return DragTarget<TileDragPayload>(
                                      onWillAcceptWithDetails: (_) => true,
                                      onMove: (details) {
                                        final box = context.findRenderObject()
                                            as RenderBox?;
                                        if (box == null) return;
                                        final local =
                                            box.globalToLocal(details.offset);
                                        var gap = _calcularGap(local.dx,
                                            local.dy, boxSize, tiles.length);

                                        // Não permite inserir antes do botão Voltar automático
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

                                        // Ajuste do gap visual para o gap real (sem contar o botão Voltar automático)
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
                                        return Stack(
                                          children: [
                                            GridView.builder(
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              padding: const EdgeInsets.all(16),
                                              gridDelegate:
                                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                                maxCrossAxisExtent: 140,
                                                mainAxisSpacing: 16,
                                                crossAxisSpacing: 16,
                                                childAspectRatio: 1.0,
                                              ),
                                              itemCount: tiles.length,
                                              itemBuilder: (context, index) {
                                                final tile = tiles[index];
                                                final isAutoBack =
                                                    needsAutoBack && index == 0;

                                                Widget card = TileCard(
                                                  tile: tile,
                                                  theme: theme,
                                                  index: index,
                                                  selected:
                                                      state.selectedTileId ==
                                                          tile.id,
                                                  fromPage: isAutoBack
                                                      ? null
                                                      : state.currentPage,
                                                  onTap: () {
                                                    final notifier = ref.read(
                                                        editorControllerProvider
                                                            .notifier);
                                                    if (isAutoBack) {
                                                      notifier.selectPage(
                                                          Layout.homePage);
                                                      return;
                                                    }
                                                    notifier
                                                        .selectTile(tile.id);
                                                  },
                                                  onDoubleTap: () {
                                                    final notifier = ref.read(
                                                        editorControllerProvider
                                                            .notifier);
                                                    if (tile is FolderTile) {
                                                      notifier.selectPage(
                                                          tile.target);
                                                    } else if (tile
                                                        is BackTile) {
                                                      notifier.selectPage(
                                                          Layout.homePage);
                                                    }
                                                  },
                                                );

                                                if (isAutoBack) {
                                                  card = Opacity(
                                                    opacity: 0.6,
                                                    child: Stack(
                                                      children: [
                                                        Positioned.fill(
                                                            child: card),
                                                        Positioned(
                                                          top: 4,
                                                          right: 4,
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        2),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .black54,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: const Text(
                                                                'auto',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    color: Colors
                                                                        .white)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }

                                                return card;
                                              },
                                            ),
                                            if (_targetGap != null)
                                              _GapPlaceholder(
                                                gap: _targetGap!,
                                                nTiles: tiles.length,
                                                boxSize: boxSize,
                                                accentColor:
                                                    Color(theme.accentColor),
                                              ),
                                          ],
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
      ),
    );
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
                  _createTile(ref, state, 'shortcut', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Pasta'),
                onTap: () {
                  Navigator.pop(ctx);
                  _createTile(ref, state, 'folder', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Voltar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _createTile(ref, state, 'back', context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _generateId(EditorState state, String prefix) {
    final allIds = state.layout.pages.values
        .expand((list) => list)
        .map((t) => t.id)
        .toSet();
    int i = 1;
    while (allIds.contains('${prefix}_$i')) {
      i++;
    }
    return '${prefix}_$i';
  }

  void _createTile(
      WidgetRef ref, EditorState state, String type, BuildContext context) {
    final id = _generateId(state, type);
    Tile newTile;

    switch (type) {
      case 'shortcut':
        newTile = ShortcutTile(id: id, icon: '⚡', label: 'Novo atalho');
        break;
      case 'folder':
        final availablePages = state.layout.pages.keys
            .where((k) => k != state.currentPage)
            .toList();
        if (availablePages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Crie uma página antes de adicionar uma pasta')),
          );
          return;
        }
        newTile = FolderTile(
            id: id,
            icon: '📁',
            label: 'Nova pasta',
            target: availablePages.first);
        break;
      case 'back':
        newTile = BackTile(id: id, icon: '⬅️', label: 'Voltar');
        break;
      default:
        return;
    }

    final notifier = ref.read(editorControllerProvider.notifier);
    notifier.upsertTile(state.currentPage, newTile);
    notifier.selectTile(newTile.id);
  }
}

class _GapPlaceholder extends StatelessWidget {
  final int gap;
  final int nTiles;
  final Size boxSize;
  final Color accentColor;

  const _GapPlaceholder({
    required this.gap,
    required this.nTiles,
    required this.boxSize,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    const maxExtent = 140.0;
    const spacing = 16.0;
    const pad = 16.0;

    final usableW = boxSize.width - pad * 2;
    final cols = (usableW / (maxExtent + spacing)).ceil().clamp(1, 999);
    final tileW = (usableW - (cols - 1) * spacing) / cols;
    final tileH = tileW;

    int col;
    int row;

    if (gap == nTiles && nTiles > 0) {
      col = (nTiles - 1) % cols + 1;
      row = (nTiles - 1) ~/ cols;
    } else {
      col = gap % cols;
      row = gap ~/ cols;
    }

    if (col >= cols) {
      col = 0;
      row += 1;
    }

    double left = pad + col * (tileW + spacing) - spacing / 2;
    left -= 2;

    final top = pad + row * (tileH + spacing);

    return Positioned(
      left: left,
      top: top,
      width: 4,
      height: tileH,
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
