import 'package:agent_core/agent_core.dart';
import 'package:cms_app/features/editor/tile_grid_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TileGridMetrics e TileGridPacker', () {
    test('Calcula colunas e placements para lista simples de 1x1', () {
      final tiles = [
        const ShortcutTile(id: 't1', icon: '1', label: '1'),
        const ShortcutTile(id: 't2', icon: '2', label: '2'),
        const ShortcutTile(id: 't3', icon: '3', label: '3'),
      ];

      final metrics = TileGridMetrics.calculate(
        tiles: tiles,
        containerWidth: 400,
        maxCrossAxisExtent: 140,
        spacing: 16,
        padding: 16,
      );

      expect(metrics.crossAxisCount, greaterThanOrEqualTo(2));
      expect(metrics.placements.length, equals(3));
      expect(metrics.placements[0].col, equals(0));
      expect(metrics.placements[0].row, equals(0));
      expect(metrics.placements[1].col, equals(1));
      expect(metrics.placements[1].row, equals(0));
    });

    test('Empacota tile 2x1 e preenche a linha seguinte', () {
      final tiles = [
        const ShortcutTile(id: 's2x1', icon: '2', label: 'Largo', width: 2, height: 1),
        const ShortcutTile(id: 's1', icon: '1', label: 'Item 1', width: 1, height: 1),
      ];

      // Se cols == 2
      final metrics = TileGridMetrics.calculate(
        tiles: tiles,
        containerWidth: 320,
        maxCrossAxisExtent: 140,
        spacing: 16,
        padding: 16,
      );

      expect(metrics.crossAxisCount, equals(2));
      expect(metrics.placements[0].col, equals(0));
      expect(metrics.placements[0].row, equals(0));
      expect(metrics.placements[0].width, equals(2));

      // Segundo item deve ir para a próxima linha col 0
      expect(metrics.placements[1].col, equals(0));
      expect(metrics.placements[1].row, equals(1));
    });

    test('Empacota tile 2x2 e posiciona itens adjacentes corretamente', () {
      final tiles = [
        const ShortcutTile(id: 's2x2', icon: '4', label: 'Grande', width: 2, height: 2),
        const ShortcutTile(id: 's1', icon: '1', label: 'Item 1', width: 1, height: 1),
        const ShortcutTile(id: 's2', icon: '2', label: 'Item 2', width: 1, height: 1),
      ];

      // Se cols == 3
      final metrics = TileGridMetrics.calculate(
        tiles: tiles,
        containerWidth: 480,
        maxCrossAxisExtent: 140,
        spacing: 16,
        padding: 16,
      );

      expect(metrics.crossAxisCount, equals(3));
      // 2x2 ocupa cols 0 e 1 nas rows 0 e 1
      expect(metrics.placements[0].col, equals(0));
      expect(metrics.placements[0].row, equals(0));

      // s1 cabe na col 2 row 0
      expect(metrics.placements[1].col, equals(2));
      expect(metrics.placements[1].row, equals(0));

      // s2 cabe na col 2 row 1
      expect(metrics.placements[2].col, equals(2));
      expect(metrics.placements[2].row, equals(1));
    });

    test('findDropIndex retorna índice correto com base na posição local', () {
      final tiles = [
        const ShortcutTile(id: 't1', icon: '1', label: '1'),
        const ShortcutTile(id: 't2', icon: '2', label: '2'),
      ];

      final metrics = TileGridMetrics.calculate(
        tiles: tiles,
        containerWidth: 320,
        maxCrossAxisExtent: 140,
        spacing: 16,
        padding: 16,
      );

      final r0 = metrics.placements[0].getRect(
        pad: metrics.padding,
        spacing: metrics.spacing,
        cellWidth: metrics.cellWidth,
        cellHeight: metrics.cellHeight,
      );

      // Ponto na metade esquerda do primeiro tile -> targetIndex 0
      final idxLeft = metrics.findDropIndex(
        Offset(r0.left + 5, r0.center.dy),
        tileCount: 2,
      );
      expect(idxLeft, equals(0));

      // Ponto na metade direita do primeiro tile -> targetIndex 1
      final idxRight = metrics.findDropIndex(
        Offset(r0.right - 5, r0.center.dy),
        tileCount: 2,
      );
      expect(idxRight, equals(1));
    });

    test('Posiciona tiles nas coordenadas explicitas (x, y) deixando quadrados vazios', () {
      final tiles = [
        const ShortcutTile(id: 'a', icon: '1', label: 'A', x: 0, y: 0),
        const ShortcutTile(id: 'b', icon: '2', label: 'B', x: 4, y: 2, width: 2, height: 1),
      ];

      final metrics = TileGridMetrics.calculate(
        tiles: tiles,
        containerWidth: 748,
        crossAxisCount: kGridColumns,
      );

      expect(metrics.crossAxisCount, equals(6));
      expect(metrics.placements[0].col, equals(0));
      expect(metrics.placements[0].row, equals(0));
      expect(metrics.placements[1].col, equals(4));
      expect(metrics.placements[1].row, equals(2));
      expect(metrics.placements[1].width, equals(2));
    });

    test('placeOrSwapTile move para quadrado vazio e faz swap quando ocupado', () {
      final initial = [
        const ShortcutTile(id: 't1', icon: '1', label: '1', x: 0, y: 0),
        const ShortcutTile(id: 't2', icon: '2', label: '2', x: 2, y: 1),
      ];

      // Move t1 para quadrado vazio (5, 2)
      final movedEmpty = TileGridMetrics.placeOrSwapTile(
        tiles: initial,
        tileId: 't1',
        targetCol: 5,
        targetRow: 2,
      );
      expect(movedEmpty[0].x, equals(5));
      expect(movedEmpty[0].y, equals(2));
      expect(movedEmpty[1].x, equals(2));
      expect(movedEmpty[1].y, equals(1));

      // Move t1 de (5, 2) para cima de t2 em (2, 1) -> swap!
      final swapped = TileGridMetrics.placeOrSwapTile(
        tiles: movedEmpty,
        tileId: 't1',
        targetCol: 2,
        targetRow: 1,
      );
      expect(swapped[0].x, equals(2));
      expect(swapped[0].y, equals(1));
      expect(swapped[1].x, equals(5));
      expect(swapped[1].y, equals(2));
    });

    test('resizeTileWithCollisionResolution expande widget e realoca vizinho colidido', () {
      final initial = [
        const ShortcutTile(id: 't1', icon: '1', label: '1', x: 0, y: 0, width: 1, height: 1),
        const ShortcutTile(id: 't2', icon: '2', label: '2', x: 1, y: 0, width: 1, height: 1),
      ];

      final resized = TileGridMetrics.resizeTileWithCollisionResolution(
        tiles: initial,
        tileId: 't1',
        newWidth: 2,
        newHeight: 2,
      );

      expect(resized[0].x, equals(0));
      expect(resized[0].y, equals(0));
      expect(resized[0].width, equals(2));
      expect(resized[0].height, equals(2));

      // t2 não pode continuar em (1, 0) pois colide com t1 (0..1, 0..1)
      expect(resized[1].x, equals(2));
      expect(resized[1].y, equals(0));
    });
  });
}

