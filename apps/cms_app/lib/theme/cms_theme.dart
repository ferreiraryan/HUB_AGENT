import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';

class TabletThemePreset {
  final String name;
  final HubTheme theme;

  const TabletThemePreset({
    required this.name,
    required this.theme,
  });
}

abstract final class CmsTheme {
  static const Color crust = Color(0xFF11111B);
  static const Color mantle = Color(0xFF181825);
  static const Color base = Color(0xFF1E1E2E);
  static const Color surface0 = Color(0xFF28293D);
  static const Color surface1 = Color(0xFF313244);
  static const Color border = Color(0xFF36384E);
  static const Color textPrimary = Color(0xFFCDD6F4);
  static const Color textSecondary = Color(0xFFA6ADC8);
  static const Color accent = Color(0xFFCBA6F7);
  static const Color green = Color(0xFFA6E3A1);
  static const Color peach = Color(0xFFFAB387);
  static const Color red = Color(0xFFF38BA8);
  static const Color blue = Color(0xFF89B4FA);

  static const List<TabletThemePreset> tabletPresets = [
    TabletThemePreset(
      name: 'Catppuccin Mocha',
      theme: HubTheme(
        bgColor: 0xFF11111B,
        cardColor: 0xFF1E1E2E,
        accentColor: 0xFFCBA6F7,
      ),
    ),
    TabletThemePreset(
      name: 'OLED Minimal',
      theme: HubTheme(
        bgColor: 0xFF000000,
        cardColor: 0xFF121216,
        accentColor: 0xFFE4E4E7,
      ),
    ),
    TabletThemePreset(
      name: 'Nord Slate',
      theme: HubTheme(
        bgColor: 0xFF191D26,
        cardColor: 0xFF242A38,
        accentColor: 0xFF88C0D0,
      ),
    ),
    TabletThemePreset(
      name: 'Tokyo Night',
      theme: HubTheme(
        bgColor: 0xFF16161E,
        cardColor: 0xFF1F2335,
        accentColor: 0xFF7AA2F7,
      ),
    ),
    TabletThemePreset(
      name: 'Forest Emerald',
      theme: HubTheme(
        bgColor: 0xFF0E1512,
        cardColor: 0xFF17221D,
        accentColor: 0xFF52D1A0,
      ),
    ),
    TabletThemePreset(
      name: 'Warm Amber',
      theme: HubTheme(
        bgColor: 0xFF14110F,
        cardColor: 0xFF201B17,
        accentColor: 0xFFF5A97F,
      ),
    ),
  ];

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: crust,
      secondary: blue,
      onSecondary: crust,
      surface: base,
      onSurface: textPrimary,
      error: red,
      onError: crust,
      outline: border,
      surfaceContainerHighest: surface1,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: mantle,
      canvasColor: base,
      cardColor: base,
      dividerColor: Colors.white10,
      dialogTheme: DialogThemeData(
        backgroundColor: base,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface1,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mantle,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: crust,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
      ),
    );
  }
}
