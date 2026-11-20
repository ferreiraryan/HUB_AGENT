import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';

class ImagePickResult {
  final String dataUri;
  final String? staticDataUri;
  final bool isGif;

  const ImagePickResult({
    required this.dataUri,
    this.staticDataUri,
    this.isGif = false,
  });
}

/// Helper para seleção, processamento e conversão de imagens e GIFs locais para Data URI Base64.
class ImageIconHelper {
  static const acceptedImageGroup = XTypeGroup(
    label: 'Imagens e GIFs',
    extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'ico', 'gif'],
  );

  /// Verifica se os bytes correspondem à assinatura de arquivo GIF (GIF87a ou GIF89a).
  static bool isGifBytes(Uint8List bytes) {
    if (bytes.length < 3) return false;
    return bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46; // "GIF"
  }

  /// Verifica se a string informada é um GIF (Data URI ou extensão).
  static bool isGif(String? value) {
    if (value == null) return false;
    final lower = value.toLowerCase();
    return lower.startsWith('data:image/gif') || lower.endsWith('.gif');
  }

  /// Processa bytes crus de imagem, redimensionando via engine gráfica do Flutter e gerando PNG Base64 compacto.
  static Future<String> processImageBytes(
    Uint8List rawBytes, {
    int targetSize = 96,
  }) async {
    final codec = await ui.instantiateImageCodec(
      rawBytes,
      targetWidth: targetSize,
      targetHeight: targetSize,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final byteData =
            await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw Exception(
              'Não foi possível codificar os bytes da imagem para PNG.');
        }
        final pngBytes = byteData.buffer.asUint8List();
        return 'data:image/png;base64,${base64Encode(pngBytes)}';
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Processa imagem para tela de suspensão / banner preservando a proporção original.
  /// Se for GIF animado, mantém os bytes originais intactos para preservar a animação.
  static Future<String> processBannerImageBytes(
    Uint8List rawBytes, {
    int maxDimension = 800,
  }) async {
    if (isGifBytes(rawBytes)) {
      return 'data:image/gif;base64,${base64Encode(rawBytes)}';
    }
    final probe = await ui.instantiateImageCodec(rawBytes);
    final first = await probe.getNextFrame();
    final origW = first.image.width;
    final origH = first.image.height;
    first.image.dispose();
    probe.dispose();

    int? targetW;
    int? targetH;
    if (origW > maxDimension || origH > maxDimension) {
      if (origW >= origH) {
        targetW = maxDimension;
      } else {
        targetH = maxDimension;
      }
    }

    final codec = await ui.instantiateImageCodec(
      rawBytes,
      targetWidth: targetW,
      targetHeight: targetH,
    );
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (byteData == null) {
      throw Exception('Não foi possível codificar a imagem para PNG.');
    }
    final pngBytes = byteData.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(pngBytes)}';
  }

  /// Verifica se a string informada é um Data URI de imagem Base64.
  static bool isImageDataUri(String? value) {
    if (value == null) return false;
    return value.startsWith('data:image/');
  }

  static final Map<String, Uint8List> _bytesCache = {};
  static const int _maxCacheEntries = 80;
  static const int _maxCacheBytes = 8 * 1024 * 1024; // 8 MB
  static int _currentCacheBytes = 0;

  /// Extrai os bytes de um Data URI Base64 com cache LRU limitado em bytes
  /// para reaproveitar instâncias de Uint8List sem acumular RAM.
  static Uint8List? extractBytes(String? dataUri) {
    if (dataUri == null || !dataUri.startsWith('data:image/')) return null;

    final cached = _bytesCache.remove(dataUri);
    if (cached != null) {
      _bytesCache[dataUri] = cached; // promove para mais recente (LRU)
      return cached;
    }

    try {
      final commaIndex = dataUri.indexOf(',');
      final base64Str =
          commaIndex != -1 ? dataUri.substring(commaIndex + 1) : dataUri;
      final bytes = base64Decode(base64Str);

      if (bytes.length <= _maxCacheBytes) {
        while (_bytesCache.isNotEmpty &&
            (_bytesCache.length >= _maxCacheEntries ||
                _currentCacheBytes + bytes.length > _maxCacheBytes)) {
          final oldestKey = _bytesCache.keys.first;
          final removed = _bytesCache.remove(oldestKey);
          if (removed != null) _currentCacheBytes -= removed.length;
        }
        _bytesCache[dataUri] = bytes;
        _currentCacheBytes += bytes.length;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Limpa o cache de bytes decodificados em memória.
  static void clearCache() {
    _bytesCache.clear();
    _currentCacheBytes = 0;
  }
}
