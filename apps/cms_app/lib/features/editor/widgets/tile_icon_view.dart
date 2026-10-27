import 'package:flutter/material.dart';
import '../emoji_picker.dart';
import '../helpers/image_icon_helper.dart';

/// Widget universal para renderização de ícone de um Tile no CMS Desktop.
/// Suporta:
/// 1. Data URI de imagem Base64 (`data:image/png;base64,...`)
/// 2. Nomes de ícones Material Symbols mapeados em [iconMap]
/// 3. Emojis Unicode e texto arbitrário
class TileIconView extends StatelessWidget {
  final String? icon;
  final double size;
  final Color? color;

  const TileIconView({
    super.key,
    required this.icon,
    this.size = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final raw = icon?.trim();
    if (raw == null || raw.isEmpty) {
      return Icon(
        Icons.widgets,
        size: size,
        color: color ?? Colors.white70,
      );
    }

    // 1. Imagem personalizada Base64
    if (ImageIconHelper.isImageDataUri(raw)) {
      final bytes = ImageIconHelper.extractBytes(raw);
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.broken_image,
            size: size,
            color: color ?? Colors.white54,
          ),
        );
      }
      return Icon(
        Icons.broken_image,
        size: size,
        color: color ?? Colors.white54,
      );
    }

    // 2. Material Symbol mapeado
    if (iconMap.containsKey(raw)) {
      return Icon(
        iconMap[raw],
        size: size,
        color: color ?? Colors.white,
      );
    }

    // 3. Emoji Unicode ou caractere personalizado
    return Text(
      raw,
      style: TextStyle(
        fontSize: size,
        height: 1.1,
      ),
      textAlign: TextAlign.center,
    );
  }
}

