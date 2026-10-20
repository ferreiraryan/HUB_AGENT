import 'dart:math' as math;
import 'package:agent_core/agent_core.dart';
import 'package:flutter/widgets.dart';

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
  final double totalHeight;
  final List<TilePlacement> placements;

  const TileGridMetrics({
    required this.crossAxisCount,
    required this.cellWidth,
    required this.cellHeight,
    required this.spacing,
    required this.padding,
    required this.rowCount,
    required this.totalHeight,
    required this.placements,
  });

  static TileGridMetrics calculate({
    required List<Tile> tiles,
    required double containerWidth,
    double maxCrossAxisExtent = 140.0,
    double spacing = 16.0,
    double padding = 16.0,
    double? cellHeight,
  }) {
    final usableW = (containerWidth - padding * 2).clamp(1.0, double.infinity);
    final cols = ((usableW + spacing) / (maxCrossAxisExtent + spacing))
        .ceil()
        .clamp(1, 999);
    final cWidth = (usableW - (cols - 1) * spacing) / cols;
    final cHeight = cellHeight ?? cWidth;

    final occupied = <List<bool>>[];
    final placements = <TilePlacement>[];

    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      final w = tile.width.clamp(1, cols);
      final h = tile.height.clamp(1, 2);

      int row = 0;
      int col = 0;
      bool found = false;

      while (!found) {
        while (occupied.length <= row + h) {
          occupied.add(List<bool>.filled(cols, false));
        }

        for (int c = 0; c <= cols - w; c++) {
          bool canFit = true;
          for (int dr = 0; dr < h; dr++) {
            for (int dc = 0; dc < w; dc++) {
              if (occupied[row + dr][c + dc]) {
                canFit = false;
                break;
              }
            }
            if (!canFit) break;
          }

          if (canFit) {
            col = c;
            found = true;
            break;
          }
        }

        if (!found) {
          row++;
        }
      }

      for (int dr = 0; dr < h; dr++) {
        for (int dc = 0; dc < w; dc++) {
          occupied[row + dr][col + dc] = true;
        }
      }

      placements.add(TilePlacement(
        tile: tile,
        index: i,
        col: col,
        row: row,
        width: w,
        height: h,
      ));
    }

    final rowCount = placements.isEmpty
        ? 0
        : placements.map((p) => p.row + p.height).reduce(math.max);

    final totalHeight = rowCount == 0
        ? padding * 2
        : padding * 2 + rowCount * cHeight + (rowCount - 1) * spacing;

    return TileGridMetrics(
      crossAxisCount: cols,
      cellWidth: cWidth,
      cellHeight: cHeight,
      spacing: spacing,
      padding: padding,
      rowCount: rowCount,
      totalHeight: totalHeight,
      placements: placements,
    );
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

      // Se o cursor estiver dentro ou muito perto da caixa deste tile
      if (rect.inflate(spacing / 2).contains(localPos)) {
        if (localPos.dx < rect.center.dx) {
          return p.index;
        } else {
          return p.index + 1;
        }
      }
    }

    // Se estiver após o último tile
    final lastRect = placements.last.getRect(
      pad: padding,
      spacing: spacing,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
    );
    if (localPos.dy > lastRect.bottom) {
      return tileCount;
    }

    // Fallback: distância euclidiana ao centro dos placements
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

