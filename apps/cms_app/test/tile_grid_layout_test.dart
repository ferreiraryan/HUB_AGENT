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
  });
}

