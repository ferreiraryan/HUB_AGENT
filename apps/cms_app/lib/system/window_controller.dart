import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

class WindowController with WindowListener {
  static final instance = WindowController._();

  WindowController._();

  bool _hidden = false;

  Future<void> init({required bool hidden}) async {
    await windowManager.ensureInitialized();

    windowManager.addListener(this);

    await windowManager.setPreventClose(true);

    const options = WindowOptions(
      size: Size(1280, 820),
      minimumSize: Size(1024, 700),
      center: true,
      title: 'Hub Agent CMS',
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      if (hidden) {
        await hide();
      } else {
        await showAndFocus();
      }
    });
  }

  Future<void> hide() async {
    // Remove da barra de tarefas para agir como um daemon real de background
    await windowManager.setSkipTaskbar(true);
    _hidden = true;
    await windowManager.hide();
  }

  Future<void> showAndFocus() async {
    await windowManager.setSkipTaskbar(false);
    _hidden = false;

    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() {
    hide();
  }

  void dispose() {
    windowManager.removeListener(this);
  }
}
