import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

class WindowController with WindowListener {
  static final instance = WindowController._();

  WindowController._();

  Future<void> init({required bool hidden}) async {
    await windowManager.ensureInitialized();

    windowManager.addListener(this);

    // X esconde em vez de matar a aplicação. O único meio de sair será pelo tray.
    await windowManager.setPreventClose(true);

    const options = WindowOptions(
      size: Size(1280, 820),
      minimumSize: Size(1024, 700),
      center: true,
      title: 'Hub Agent CMS',
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      if (hidden) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }

  Future<void> showAndFocus() async {
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }

  void dispose() {
    windowManager.removeListener(this);
  }
}
