import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

class WindowController with WindowListener {
  static final instance = WindowController._();

  WindowController._();

  bool _isSpotlightActive = false;
  bool _wasHiddenBeforeSpotlight = false;
  DateTime _spotlightOpenedAt = DateTime.fromMillisecondsSinceEpoch(0);
  VoidCallback? _onSpotlightBlur;
  Size _normalSize = const Size(1280, 820);
  static const Size normalMinSize = Size(1024, 700);
  static const Size spotlightSize = Size(600, 68);
  static const Size searchSpotlightSize = Size(640, 430);
  static const Size spotlightMinSize = Size(540, 62);
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

  Future<bool> openSpotlight({
    bool? wasHidden,
    String title = 'Hub Agent Search',
    VoidCallback? onBlur,
    Size? size,
  }) async {
    _wasHiddenBeforeSpotlight = wasHidden ?? await isHiddenOrMinimized();
    _onSpotlightBlur = onBlur;
    _spotlightOpenedAt = DateTime.now();
    final targetSize = size ?? spotlightSize;

    if (_wasHiddenBeforeSpotlight) {
      _wasMaximized = await windowManager.isMaximized();
      if (!_wasMaximized) {
        try {
          _normalSize = await windowManager.getSize();
        } catch (_) {}
      }
      await windowManager.setTitle(title);
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(true);
      await windowManager.setResizable(false);
      await windowManager.setMinimumSize(spotlightMinSize);
      await windowManager.setMaximumSize(targetSize);
      await windowManager.setSize(targetSize);
      await windowManager.center();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
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
    _onSpotlightBlur = null;

    await windowManager.setAlwaysOnTop(false);

    if (_wasHiddenBeforeSpotlight) {
      await hide();
      await windowManager.setTitleBarStyle(
        TitleBarStyle.normal,
        windowButtonVisibility: true,
      );
      await windowManager.setResizable(true);
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
  void onWindowBlur() {
    if (_isSpotlightActive && _wasHiddenBeforeSpotlight) {
      final elapsed = DateTime.now().difference(_spotlightOpenedAt);
      if (elapsed > const Duration(milliseconds: 400)) {
        final cb = _onSpotlightBlur;
        if (cb != null) {
          cb();
        } else {
          closeSpotlight();
        }
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
