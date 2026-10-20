import 'dart:math' as math;
import 'package:agent_core/agent_core.dart';
import 'package:flutter/widgets.dart';

const int kGridColumns = 6;
const int kMinGridRows = 3;

@immutable
class TilePlacement {
  final Tile tile;
  final int index;
  final int col;
  final int row;
  final int width;
  final int height;

  const TilePlacement({
    required this.tile,
    required this.index,
    required this.col,
    required this.row,
    required this.width,
    required this.height,
  });

  Rect getRect({
    required double pad,
    required double spacing,
    required double cellWidth,
    required double cellHeight,
  }) {
    final left = pad + col * (cellWidth + spacing);
    final top = pad + row * (cellHeight + spacing);
    final w = width * cellWidth + (width - 1) * spacing;
    final h = height * cellHeight + (height - 1) * spacing;
    return Rect.fromLTWH(left, top, w, h);
  }
}

class TileGridMetrics {
  final int crossAxisCount;
  final double cellWidth;
  final double cellHeight;
  final double spacing;
  final double padding;
  final int rowCount;
  final int visibleRowCount;
  final double totalHeight;
  final List<TilePlacement> placements;

  const TileGridMetrics({
    required this.crossAxisCount,
    required this.cellWidth,
    required this.cellHeight,
    required this.spacing,
    required this.padding,
    required this.rowCount,
    required this.visibleRowCount,
    required this.totalHeight,
    required this.placements,
  });

  static TileGridMetrics calculate({
    required List<Tile> tiles,
    required double containerWidth,
    int? crossAxisCount,
    double? maxCrossAxisExtent,
    int minRows = kMinGridRows,
    double spacing = 12.0,
    double padding = 16.0,
    double? cellHeight,
  }) {
    final usableW = (containerWidth - padding * 2).clamp(1.0, double.infinity);
    final int cols;
    if (crossAxisCount != null) {
      cols = crossAxisCount.clamp(1, 99);
    } else if (maxCrossAxisExtent != null) {
      cols = ((usableW + spacing) / (maxCrossAxisExtent + spacing))
          .ceil()
          .clamp(1, 999);
    } else {
      cols = kGridColumns;
    }

    final cWidth = (usableW - (cols - 1) * spacing) / cols;
    final cHeight = cellHeight ?? cWidth;

    final occupied = <List<bool>>[];
    void ensureRows(int targetRowExclusive) {
      while (occupied.length < targetRowExclusive) {
        occupied.add(List<bool>.filled(cols, false));
      }
    }

    bool canFitAt(int r, int c, int w, int h) {
      if (c < 0 || c + w > cols || r < 0) return false;
      ensureRows(r + h);
      for (int dr = 0; dr < h; dr++) {
        for (int dc = 0; dc < w; dc++) {
          if (occupied[r + dr][c + dc]) return false;
        }
      }
      return true;
    }

    void markOccupied(int r, int c, int w, int h) {
      ensureRows(r + h);
      for (int dr = 0; dr < h; dr++) {
        for (int dc = 0; dc < w; dc++) {
          occupied[r + dr][c + dc] = true;
        }
      }
    }

    final placementsByIndex = List<TilePlacement?>.filled(tiles.length, null);
    final unpositionedIndices = <int>[];

    // Passo 1: Posicionar tiles com coordenadas (x, y) explícitas
    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      if (tile.x != null && tile.y != null) {
        final w = tile.width.clamp(1, cols);
        final h = tile.height.clamp(1, 2);
        final col = tile.x!.clamp(0, cols - w);
        final row = math.max(0, tile.y!);
        if (canFitAt(row, col, w, h)) {
          markOccupied(row, col, w, h);
          placementsByIndex[i] = TilePlacement(
            tile: tile,
            index: i,
            col: col,
            row: row,
            width: w,
            height: h,
          );
        } else {
          unpositionedIndices.add(i);
        }
      } else {
        unpositionedIndices.add(i);
      }
    }

    // Passo 2: Alocar primeira célula livre para tiles sem (x, y) ou em colisão
    for (final i in unpositionedIndices) {
      final tile = tiles[i];
      final w = tile.width.clamp(1, cols);
      final h = tile.height.clamp(1, 2);

      int row = 0;
      int col = 0;
      bool found = false;

      while (!found) {
        ensureRows(row + h);
        for (int c = 0; c <= cols - w; c++) {
          if (canFitAt(row, c, w, h)) {
            col = c;
            found = true;
            break;
          }
        }
        if (!found) {
          row++;
        }
      }

      markOccupied(row, col, w, h);
      placementsByIndex[i] = TilePlacement(
        tile: tile,
        index: i,
        col: col,
        row: row,
        width: w,
        height: h,
      );
    }

    final placements = placementsByIndex.whereType<TilePlacement>().toList();

    final rowCount = placements.isEmpty
        ? 0
        : placements.map((p) => p.row + p.height).reduce(math.max);

    final visibleRowCount = math.max(minRows, rowCount + 1);

    final totalHeight = visibleRowCount == 0
        ? padding * 2
        : padding * 2 +
            visibleRowCount * cHeight +
            (visibleRowCount - 1) * spacing;

    return TileGridMetrics(
      crossAxisCount: cols,
      cellWidth: cWidth,
      cellHeight: cHeight,
      spacing: spacing,
      padding: padding,
      rowCount: rowCount,
      visibleRowCount: visibleRowCount,
      totalHeight: totalHeight,
      placements: placements,
    );
  }

  Rect getSpanRect(int col, int row, int width, int height) {
    final left = padding + col * (cellWidth + spacing);
    final top = padding + row * (cellHeight + spacing);
    final w = width * cellWidth + (width - 1) * spacing;
    final h = height * cellHeight + (height - 1) * spacing;
    return Rect.fromLTWH(left, top, w, h);
  }

  /// Converte um Offset local da grade em coordenadas de célula (col, row).
  (int col, int row) cellAtOffset(
    Offset localPos, {
    int tileWidth = 1,
    int tileHeight = 1,
  }) {
    final w = tileWidth.clamp(1, crossAxisCount);
    final stepX = cellWidth + spacing;
    final stepY = cellHeight + spacing;

    final rawCol = ((localPos.dx - padding) / stepX).floor();
    final rawRow = ((localPos.dy - padding) / stepY).floor();

    final col = rawCol.clamp(0, crossAxisCount - w);
    final row = math.max(0, rawRow);
    return (col, row);
  }

  /// Retorna a primeira coordenada (col, row) livre onde caiba um bloco w × h.
  (int col, int row) findFirstFreeCell(
    int width,
    int height, {
    String? ignoreTileId,
    Set<(int, int)> reservedCells = const {},
  }) {
    final w = width.clamp(1, crossAxisCount);
    final h = height.clamp(1, 2);

    bool isCellOccupied(int c, int r) {
      if (reservedCells.contains((c, r))) return true;
      for (final p in placements) {
        if (ignoreTileId != null && p.tile.id == ignoreTileId) continue;
        if (c >= p.col &&
            c < p.col + p.width &&
            r >= p.row &&
            r < p.row + p.height) {
          return true;
        }
      }
      return false;
    }

    int row = 0;
    while (true) {
      for (int c = 0; c <= crossAxisCount - w; c++) {
        bool fits = true;
        for (int dr = 0; dr < h; dr++) {
          for (int dc = 0; dc < w; dc++) {
            if (isCellOccupied(c + dc, row + dr)) {
              fits = false;
              break;
            }
          }
          if (!fits) break;
        }
        if (fits) return (c, row);
      }
      row++;
    }
  }

  /// Normaliza todos os tiles da lista atribuindo coordenadas (x, y) explícitas.
  static List<Tile> normalizeCoordinates(
    List<Tile> tiles, {
    int cols = kGridColumns,
    Set<(int, int)> reservedCells = const {},
  }) {
    final dummyTiles = <Tile>[
      for (var i = 0; i < reservedCells.length; i++)
        BackTile(
          id: '__reserved_$i',
          icon: '',
          label: '',
          x: reservedCells.elementAt(i).$1,
          y: reservedCells.elementAt(i).$2,
        ),
      ...tiles,
    ];
    final metrics = calculate(
      tiles: dummyTiles,
      containerWidth: 1000,
      crossAxisCount: cols,
    );
    final result = <Tile>[];
    for (final p in metrics.placements) {
      if (p.tile.id.startsWith('__reserved_')) continue;
      result.add(p.tile.copyWithPosition(x: p.col, y: p.row));
    }
    return result;
  }

  /// Move um tile para (targetCol, targetRow). Se houver colisão com outro tile,
  /// realiza swap para a posição antiga (se couber) ou realoca na primeira célula livre.
  static List<Tile> placeOrSwapTile({
    required List<Tile> tiles,
    required String tileId,
    required int targetCol,
    required int targetRow,
    int cols = kGridColumns,
    Set<(int, int)> reservedCells = const {},
  }) {
    final normalized = normalizeCoordinates(
      tiles,
      cols: cols,
      reservedCells: reservedCells,
    );
    final movingIdx = normalized.indexWhere((t) => t.id == tileId);
    if (movingIdx < 0) return tiles;

    final moving = normalized[movingIdx];
    final w = moving.width.clamp(1, cols);
    final h = moving.height.clamp(1, 2);
    var col = targetCol.clamp(0, cols - w);
    var row = math.max(0, targetRow);

    // Não permite sobrepor células reservadas (ex: __auto_back__ em (0,0))
    bool hitsReserved(int c, int r, int tw, int th) {
      for (int dr = 0; dr < th; dr++) {
        for (int dc = 0; dc < tw; dc++) {
          if (reservedCells.contains((c + dc, r + dr))) return true;
        }
      }
      return false;
    }

    if (hitsReserved(col, row, w, h)) {
      if (col == 0 && cols > w && !hitsReserved(1, row, w, h)) {
        col = 1;
      } else {
        row = row + 1;
      }
    }

    final oldCol = moving.x ?? 0;
    final oldRow = moving.y ?? 0;
    if (col == oldCol && row == oldRow) {
      return normalized;
    }

    final movedTile = moving.copyWithPosition(x: col, y: row);

    bool rectsOverlap(
      int c1,
      int r1,
      int w1,
      int h1,
      int c2,
      int r2,
      int w2,
      int h2,
    ) {
      return c1 < c2 + w2 && c1 + w1 > c2 && r1 < r2 + h2 && r1 + h1 > r2;
    }

    final collidingIndices = <int>[];
    for (int i = 0; i < normalized.length; i++) {
      if (i == movingIdx) continue;
      final t = normalized[i];
      final tw = t.width.clamp(1, cols);
      final th = t.height.clamp(1, 2);
      if (rectsOverlap(col, row, w, h, t.x!, t.y!, tw, th)) {
        collidingIndices.add(i);
      }
    }

    final updated = List<Tile>.of(normalized);
    updated[movingIdx] = movedTile;

    if (collidingIndices.isEmpty) {
      return updated;
    }

    // Células ocupadas pelos tiles que NÃO colidiram + movedTile + reservedCells
    final occupied = <List<bool>>[];
    void mark(int r, int c, int tw, int th) {
      while (occupied.length < r + th) {
        occupied.add(List<bool>.filled(cols, false));
      }
      for (int dr = 0; dr < th; dr++) {
        for (int dc = 0; dc < tw; dc++) {
          occupied[r + dr][c + dc] = true;
        }
      }
    }

    bool fitsInOccupied(int r, int c, int tw, int th) {
      if (c < 0 || c + tw > cols || r < 0) return false;
      while (occupied.length < r + th) {
        occupied.add(List<bool>.filled(cols, false));
      }
      for (int dr = 0; dr < th; dr++) {
        for (int dc = 0; dc < tw; dc++) {
          if (occupied[r + dr][c + dc]) return false;
        }
      }
      return true;
    }

    for (final cell in reservedCells) {
      mark(cell.$2, cell.$1, 1, 1);
    }
    mark(row, col, w, h);

    for (int i = 0; i < updated.length; i++) {
      if (i == movingIdx || collidingIndices.contains(i)) continue;
      final t = updated[i];
      mark(t.y!, t.x!, t.width.clamp(1, cols), t.height.clamp(1, 2));
    }

    for (final ci in collidingIndices) {
      final ct = updated[ci];
      final cw = ct.width.clamp(1, cols);
      final ch = ct.height.clamp(1, 2);
      final swapCol = oldCol.clamp(0, cols - cw);
      final swapRow = math.max(0, oldRow);

      if (fitsInOccupied(swapRow, swapCol, cw, ch)) {
        mark(swapRow, swapCol, cw, ch);
        updated[ci] = ct.copyWithPosition(x: swapCol, y: swapRow);
      } else {
        int r = 0;
        int c = 0;
        bool found = false;
        while (!found) {
          for (int tryC = 0; tryC <= cols - cw; tryC++) {
            if (fitsInOccupied(r, tryC, cw, ch)) {
              c = tryC;
              found = true;
              break;
            }
          }
          if (!found) r++;
        }
        mark(r, c, cw, ch);
        updated[ci] = ct.copyWithPosition(x: c, y: r);
      }
    }

    return updated;
  }

  /// Redimensiona um tile mantendo sua âncora (x, y) (com clamp na borda direita)
  /// e realocando vizinhos caso o novo tamanho colida com eles.
  static List<Tile> resizeTileWithCollisionResolution({
    required List<Tile> tiles,
    required String tileId,
    required int newWidth,
    required int newHeight,
    int cols = kGridColumns,
    Set<(int, int)> reservedCells = const {},
  }) {
    final normalized = normalizeCoordinates(
      tiles,
      cols: cols,
      reservedCells: reservedCells,
    );
    final idx = normalized.indexWhere((t) => t.id == tileId);
    if (idx < 0) return tiles;

    final current = normalized[idx];
    final w = newWidth.clamp(1, cols);
    final h = newHeight.clamp(1, 2);
    final targetCol = (current.x ?? 0).clamp(0, cols - w);
    final targetRow = math.max(0, current.y ?? 0);

    final withNewSize = List<Tile>.of(normalized);
    withNewSize[idx] = current.copyWithPosition(
      width: w,
      height: h,
      x: targetCol,
      y: targetRow,
    );

    // Reutiliza placeOrSwapTile forçando a resolução de colisões a partir da âncora
    return _resolveCollisionsForAnchor(
      tiles: withNewSize,
      anchorIndex: idx,
      cols: cols,
      reservedCells: reservedCells,
    );
  }

  static List<Tile> _resolveCollisionsForAnchor({
    required List<Tile> tiles,
    required int anchorIndex,
    required int cols,
    required Set<(int, int)> reservedCells,
  }) {
    final anchor = tiles[anchorIndex];
    final aw = anchor.width.clamp(1, cols);
    final ah = anchor.height.clamp(1, 2);
    final acol = (anchor.x ?? 0).clamp(0, cols - aw);
    final arow = math.max(0, anchor.y ?? 0);

    bool rectsOverlap(
      int c1,
      int r1,
      int w1,
      int h1,
      int c2,
      int r2,
      int w2,
      int h2,
    ) {
      return c1 < c2 + w2 && c1 + w1 > c2 && r1 < r2 + h2 && r1 + h1 > r2;
    }

    final collidingIndices = <int>[];
    for (int i = 0; i < tiles.length; i++) {
      if (i == anchorIndex) continue;
      final t = tiles[i];
      final tw = t.width.clamp(1, cols);
      final th = t.height.clamp(1, 2);
      if (rectsOverlap(acol, arow, aw, ah, t.x!, t.y!, tw, th)) {
        collidingIndices.add(i);
      }
    }

    if (collidingIndices.isEmpty) return tiles;

    final occupied = <List<bool>>[];
    void mark(int r, int c, int tw, int th) {
      while (occupied.length < r + th) {
        occupied.add(List<bool>.filled(cols, false));
      }
      for (int dr = 0; dr < th; dr++) {
        for (int dc = 0; dc < tw; dc++) {
          occupied[r + dr][c + dc] = true;
        }
      }
    }

    bool fitsInOccupied(int r, int c, int tw, int th) {
      if (c < 0 || c + tw > cols || r < 0) return false;
      while (occupied.length < r + th) {
        occupied.add(List<bool>.filled(cols, false));
      }
      for (int dr = 0; dr < th; dr++) {
        for (int dc = 0; dc < tw; dc++) {
          if (occupied[r + dr][c + dc]) return false;
        }
      }
      return true;
    }

    for (final cell in reservedCells) {
      mark(cell.$2, cell.$1, 1, 1);
    }
    mark(arow, acol, aw, ah);

    for (int i = 0; i < tiles.length; i++) {
      if (i == anchorIndex || collidingIndices.contains(i)) continue;
      final t = tiles[i];
      mark(t.y!, t.x!, t.width.clamp(1, cols), t.height.clamp(1, 2));
    }

    final updated = List<Tile>.of(tiles);
    for (final ci in collidingIndices) {
      final ct = updated[ci];
      final cw = ct.width.clamp(1, cols);
      final ch = ct.height.clamp(1, 2);
      int r = ct.y ?? 0;
      int c = 0;
      bool found = false;
      // Tenta primeiro a partir da linha atual do item colidido, depois desde o topo
      for (int startRow in [r, 0]) {
        r = startRow;
        while (!found && r < 50) {
          for (int tryC = 0; tryC <= cols - cw; tryC++) {
            if (fitsInOccupied(r, tryC, cw, ch)) {
              c = tryC;
              found = true;
              break;
            }
          }
          if (!found) r++;
        }
        if (found) break;
      }
      mark(r, c, cw, ch);
      updated[ci] = ct.copyWithPosition(x: c, y: r);
    }

    return updated;
  }

  /// Determina o índice na lista de tiles onde o item deve ser solto dado a coordenada local do cursor.
  int findDropIndex(Offset localPos, {required int tileCount}) {
    if (placements.isEmpty) return 0;

    for (final p in placements) {
      final rect = p.getRect(
        pad: padding,
        spacing: spacing,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
      );

      if (rect.inflate(spacing / 2).contains(localPos)) {
        if (localPos.dx < rect.center.dx) {
          return p.index;
        } else {
          return p.index + 1;
        }
      }
    }

    final lastRect = placements.last.getRect(
      pad: padding,
      spacing: spacing,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
    );
    if (localPos.dy > lastRect.bottom) {
      return tileCount;
    }

    TilePlacement closest = placements.first;
    double minDistance = double.infinity;

    for (final p in placements) {
      final rect = p.getRect(
        pad: padding,
        spacing: spacing,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
      );
      final dist = (rect.center - localPos).distanceSquared;
      if (dist < minDistance) {
        minDistance = dist;
        closest = p;
      }
    }

    final cRect = closest.getRect(
      pad: padding,
      spacing: spacing,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
    );
    if (localPos.dx < cRect.center.dx) {
      return closest.index;
    } else {
      return (closest.index + 1).clamp(0, tileCount);
    }
  }
}
