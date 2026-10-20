import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

class WindowController with WindowListener {
  static final instance = WindowController._();

  WindowController._();

  bool _isSpotlightActive = false;
  bool _wasHiddenBeforeSpotlight = false;
  Size _normalSize = const Size(1280, 820);
  static const Size normalMinSize = Size(1024, 700);
  static const Size spotlightSize = Size(620, 110);
  static const Size spotlightMinSize = Size(560, 90);
  bool _wasMaximized = false;

  bool get isSpotlightActive => _isSpotlightActive;
  bool get wasHiddenBeforeSpotlight => _wasHiddenBeforeSpotlight;

  Future<bool> isHiddenOrMinimized() async {
    final isVisible = await windowManager.isVisible();
    final isMinimized = await windowManager.isMinimized();
    return !isVisible || isMinimized;
  }

  Future<void> init({required bool hidden}) async {
    await windowManager.ensureInitialized();

    windowManager.addListener(this);

    await windowManager.setPreventClose(true);

    const options = WindowOptions(
      size: Size(1280, 820),
      minimumSize: normalMinSize,
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
    await windowManager.hide();
  }

  Future<void> showAndFocus() async {
    await windowManager.setSkipTaskbar(false);

    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  Future<bool> openSpotlight({bool? wasHidden}) async {
    _wasHiddenBeforeSpotlight = wasHidden ?? await isHiddenOrMinimized();

    if (_wasHiddenBeforeSpotlight) {
      _wasMaximized = await windowManager.isMaximized();
      if (!_wasMaximized) {
        try {
          _normalSize = await windowManager.getSize();
        } catch (_) {}
      }
      await windowManager.setTitle('Hub Agent Search');
      await windowManager.setMinimumSize(spotlightMinSize);
      await windowManager.setMaximumSize(spotlightSize);
      await windowManager.setSize(spotlightSize);
      await windowManager.center();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      await windowManager.focus();
    } else {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.focus();
    }
    _isSpotlightActive = true;
    return _wasHiddenBeforeSpotlight;
  }

  Future<void> closeSpotlight() async {
    if (!_isSpotlightActive) return;
    _isSpotlightActive = false;

    await windowManager.setAlwaysOnTop(false);

    if (_wasHiddenBeforeSpotlight) {
      await hide();
      await windowManager.setTitle('Hub Agent CMS');
      await windowManager.setMaximumSize(const Size(-1, -1));
      await windowManager.setMinimumSize(normalMinSize);
      await windowManager.setSize(_normalSize);
      if (_wasMaximized) {
        await windowManager.maximize();
      }
    }
  }

  @override
  void onWindowClose() {
    if (_isSpotlightActive) {
      closeSpotlight();
    } else {
      hide();
    }
  }

  void dispose() {
    windowManager.removeListener(this);
  }
}
