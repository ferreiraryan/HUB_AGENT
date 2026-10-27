import 'package:flutter/material.dart';
import '../emoji_picker.dart';
import '../helpers/image_icon_helper.dart';

/// Widget universal para renderização de ícone de um Tile no CMS Desktop.
/// Suporta:
/// 1. Imagens e GIFs em Data URI Base64 (`data:image/...`)
/// 2. Nomes de ícones Material Symbols mapeados em [iconMap]
/// 3. Emojis Unicode e texto arbitrário
/// 4. Alternância entre staticIcon e animação conforme animationMode
class TileIconView extends StatelessWidget {
  final String? icon;
  final String? staticIcon;
  final String? animationMode;
  final double size;
  final Color? color;

  const TileIconView({
    super.key,
    required this.icon,
    this.staticIcon,
    this.animationMode,
    this.size = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Se o modo for 'on_tap' e existir staticIcon, exibe o frame estático no canvas
    final effective = (animationMode == 'on_tap' && staticIcon != null && staticIcon!.isNotEmpty)
        ? staticIcon
        : icon;
    final raw = effective?.trim();

    if (raw == null || raw.isEmpty) {
      return Icon(
        Icons.widgets,
        size: size,
        color: color ?? Colors.white70,
      );
    }

    // 1. Imagem personalizada ou GIF Base64
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
