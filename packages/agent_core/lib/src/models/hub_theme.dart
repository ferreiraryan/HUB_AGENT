import 'package:meta/meta.dart';

import '../util/hex_color.dart';

/// Tema que o dashboard aplica.
///
/// Exatamente tres cores: o contrato canonico do tablet nao tem borderRadius
/// nem qualquer outro campo. Nao adicione sem mudar o dashboard junto.
@immutable
class HubTheme {
  /// ARGB (0xAARRGGBB) aqui dentro; vira "#rrggbb" no JSON.
  final int bgColor;
  final int cardColor;
  final int accentColor;

  const HubTheme({
    required this.bgColor,
    required this.cardColor,
    required this.accentColor,
  });

  /// Catppuccin Mocha, usado quando nao ha layout.json no disco.
  static const HubTheme fallback = HubTheme(
    bgColor: 0xFF11111B,
    cardColor: 0xFF1E1E2E,
    accentColor: 0xFFCBA6F7,
  );

  factory HubTheme.fromJson(Map<String, dynamic> json) => HubTheme(
        bgColor: hexToArgb(json['bgColor'] as String),
        cardColor: hexToArgb(json['cardColor'] as String),
        accentColor: hexToArgb(json['accentColor'] as String),
      );

  /// Ordem das chaves segue o contrato. Nao reordene.
  Map<String, dynamic> toJson() => {
        'bgColor': argbToHex(bgColor),
        'cardColor': argbToHex(cardColor),
        'accentColor': argbToHex(accentColor),
      };

  HubTheme copyWith({int? bgColor, int? cardColor, int? accentColor}) =>
      HubTheme(
        bgColor: bgColor ?? this.bgColor,
        cardColor: cardColor ?? this.cardColor,
        accentColor: accentColor ?? this.accentColor,
      );

  @override
  bool operator ==(Object o) =>
      o is HubTheme &&
      o.bgColor == bgColor &&
      o.cardColor == cardColor &&
      o.accentColor == accentColor;

  @override
  int get hashCode => Object.hash(bgColor, cardColor, accentColor);
}
