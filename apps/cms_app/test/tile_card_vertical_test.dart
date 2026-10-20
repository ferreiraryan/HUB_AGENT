import 'package:agent_core/agent_core.dart';
import 'package:cms_app/features/editor/tile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testTheme = HubTheme.fallback;

  testWidgets('Renderiza SliderTile vertical 1x2 com texto longo em 2 linhas',
      (tester) async {
    const slider = SliderTile(
      id: 'vol_master',
      icon: 'volume_up',
      label: 'Volume Master do Sistema',
      source: SliderSource(kind: SliderSource.kindMasterVolume),
      width: 1,
      height: 2,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 240,
            child: TileCard(
              tile: slider,
              theme: testTheme,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final labelFinder = find.text('Volume Master do Sistema');
    expect(labelFinder, findsOneWidget);

    final textWidget = tester.widget<Text>(labelFinder);
    expect(textWidget.maxLines, equals(2));
    expect(textWidget.textAlign, equals(TextAlign.center));
  });

  testWidgets('Renderiza StatTile vertical 1x2 com texto longo em 2 linhas',
      (tester) async {
    const stat = StatTile(
      id: 'cpu_stat',
      icon: 'memory',
      label: 'Uso de Processador Principal',
      source: StatSource(kind: 'cpu', field: 'load', unit: '%'),
      width: 1,
      height: 2,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 240,
            child: TileCard(
              tile: stat,
              theme: testTheme,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final labelFinder = find.text('Uso de Processador Principal');
    expect(labelFinder, findsOneWidget);

    final textWidget = tester.widget<Text>(labelFinder);
    expect(textWidget.maxLines, equals(2));
    expect(textWidget.textAlign, equals(TextAlign.center));
  });
}
