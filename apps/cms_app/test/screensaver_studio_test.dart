import 'package:agent_core/agent_core.dart';
import 'package:cms_app/features/screensaver/screensaver_controller.dart';
import 'package:cms_app/features/screensaver/screensaver_studio_page.dart';
import 'package:cms_app/theme/cms_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ScreensaverController adiciona, move, duplica, remove e faz undo/redo', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(screensaverControllerProvider.notifier);
    final initialCount =
        container.read(screensaverControllerProvider).config.widgets.length;

    notifier.addWidget('image');
    var state = container.read(screensaverControllerProvider);
    expect(state.config.widgets.length, equals(initialCount + 1));
    final addedId = state.selectedWidgetId!;

    notifier.updateWidget(addedId, (w) => w.copyWith(x: 20, y: 30));
    state = container.read(screensaverControllerProvider);
    expect(state.selectedWidget?.x, equals(20));
    expect(state.selectedWidget?.y, equals(30));

    notifier.duplicateWidget(addedId);
    expect(
      container.read(screensaverControllerProvider).config.widgets.length,
      equals(initialCount + 2),
    );

    notifier.undo();
    expect(
      container.read(screensaverControllerProvider).config.widgets.length,
      equals(initialCount + 1),
    );

    notifier.redo();
    expect(
      container.read(screensaverControllerProvider).config.widgets.length,
      equals(initialCount + 2),
    );

    notifier.applyPreset(ScreensaverPresets.minimalOled());
    expect(
      container.read(screensaverControllerProvider).config.backgroundStyle,
      equals('oled_black'),
    );
  });

  testWidgets('ScreensaverStudioPage renderiza sem overflows', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: CmsTheme.dark(),
          home: const ScreensaverStudioPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ambient Studio — Tela de Suspensão'), findsOneWidget);
    expect(find.text('Testar no Tablet'), findsOneWidget);
    expect(find.text('Adicionar Widget'), findsOneWidget);
  });
}
