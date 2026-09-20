/// Conversao entre inteiros ARGB (0xAARRGGBB) e as strings "#rrggbb" do contrato.
///
/// O nucleo guarda cores como `int` justamente para nao depender de `dart:ui`.
/// Na camada Flutter: `Color(theme.accentColor)` e `color.value` fecham o ciclo.
library;

/// `0xFFCBA6F7` -> `"#cba6f7"`. O alpha e descartado: o contrato nao o preve.
String argbToHex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Aceita `#rgb`, `#rrggbb` e `#aarrggbb` (com ou sem `#`).
/// Lanca [FormatException] em entrada invalida.
int hexToArgb(String input) {
  var s = input.trim().replaceFirst('#', '');
  if (s.length == 3) {
    s = s.split('').map((c) => '$c$c').join();
  }
  if (s.length == 6) {
    s = 'ff$s';
  }
  if (s.length != 8 || !RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(s)) {
    throw FormatException('cor invalida: "$input"');
  }
  return int.parse(s, radix: 16);
}
