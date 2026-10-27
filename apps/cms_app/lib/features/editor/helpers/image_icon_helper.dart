import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';

/// Helper para seleção, processamento e conversão de imagens locais para Data URI Base64.
class ImageIconHelper {
  static const acceptedImageGroup = XTypeGroup(
    label: 'Imagens',
    extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'ico'],
  );

  /// Abre o seletor nativo de arquivos do sistema operacional para escolher uma imagem.
  static Future<String?> pickAndProcessImage({int targetSize = 96}) async {
    final xFile = await openFile(acceptedTypeGroups: [acceptedImageGroup]);
    if (xFile == null) return null;

    final bytes = await xFile.readAsBytes();
    return processImageBytes(bytes, targetSize: targetSize);
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

