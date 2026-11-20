import 'dart:async';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../features/editor/helpers/image_icon_helper.dart';

/// Gerencia caches gráficos do Flutter e solicita ao SO a devolução de páginas
/// residentes ociosas (`SetProcessWorkingSetSizeEx` no Windows / `malloc_trim`
/// no Linux) quando a janela é minimizada para a bandeja.
class MemoryTrimmer {
  static const _channel = MethodChannel('hub_agent/memory');

  /// Limite máximo do ImageCache enquanto a janela do editor está visível (24 MB).
  static const int activeImageCacheBytes = 24 * 1024 * 1024;
  static const int activeImageCacheEntries = 150;

  /// Configura limites econômicos para o ImageCache quando o editor está aberto.
  static void restoreUiMemory() {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSize = activeImageCacheEntries;
    cache.maximumSizeBytes = activeImageCacheBytes;
  }

  /// Libera texturas, bitmaps decodificados, cache Base64 e solicita trim ao SO.
  static Future<void> hibernateUiMemory() async {
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.clear();
      cache.clearLiveImages();
      cache.maximumSize = 0;
      cache.maximumSizeBytes = 0;
    } catch (_) {}

    ImageIconHelper.clearCache();

    // Aguarda a desmontagem efetiva da árvore antes de devolver páginas ao SO.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await trimNativeWorkingSet();
  }

  /// Invoca o canal nativo do runner (`SetProcessWorkingSetSizeEx` / `malloc_trim`).
  static Future<void> trimNativeWorkingSet() async {
    try {
      await _channel.invokeMethod<void>('trim');
    } on MissingPluginException {
      // Ignora em ambientes de widget test sem runner nativo.
    } catch (_) {}
  }
}
