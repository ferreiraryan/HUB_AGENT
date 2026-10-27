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

  /// Abre o seletor nativo para escolher imagem ou GIF.
  static Future<ImagePickResult?> pickAndProcessImage({int targetSize = 96}) async {
    final xFile = await openFile(acceptedTypeGroups: [acceptedImageGroup]);
    if (xFile == null) return null;

    final bytes = await xFile.readAsBytes();
    final isGifFile = isGifBytes(bytes) || xFile.name.toLowerCase().endsWith('.gif');

    if (isGifFile) {
      final gifDataUri = 'data:image/gif;base64,${base64Encode(bytes)}';
      String? staticDataUri;
      try {
        // Extrai o primeiro frame como PNG estático para os modos on_tap / while_playing
        staticDataUri = await processImageBytes(bytes, targetSize: targetSize);
      } catch (_) {
        staticDataUri = gifDataUri;
      }
      return ImagePickResult(
        dataUri: gifDataUri,
        staticDataUri: staticDataUri,
        isGif: true,
      );
    }

    final pngDataUri = await processImageBytes(bytes, targetSize: targetSize);
    return ImagePickResult(
      dataUri: pngDataUri,
      staticDataUri: pngDataUri,
      isGif: false,
    );
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
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Não foi possível codificar os bytes da imagem para PNG.');
    }
    final pngBytes = byteData.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(pngBytes)}';
  }

  /// Verifica se a string informada é um Data URI de imagem Base64.
  static bool isImageDataUri(String? value) {
    if (value == null) return false;
    return value.startsWith('data:image/');
  }

  /// Extrai os bytes de um Data URI Base64. Retorna null se for inválido.
  static Uint8List? extractBytes(String? dataUri) {
    if (dataUri == null || !dataUri.startsWith('data:image/')) return null;
    try {
      final commaIndex = dataUri.indexOf(',');
      final base64Str =
          commaIndex != -1 ? dataUri.substring(commaIndex + 1) : dataUri;
      return base64Decode(base64Str);
    } catch (_) {
      return null;
    }
  }
}
