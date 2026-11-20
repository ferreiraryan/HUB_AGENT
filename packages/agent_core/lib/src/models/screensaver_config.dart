/// Modelos de configuração da Tela de Suspensão (Ambient Studio).
///
/// Persistido isoladamente em `screensaver.json` e publicado em
/// `nodes/{deviceId}/screensaver` para manter o contrato Golden do `layout.json`.
class ScreensaverWidget {
  final String id;
  final String type; // clock | weather | pc_stats | media | batteries | pomodoro | todos | network | image | text
  final double x; // 0..100 (%)
  final double y; // 0..100 (%)
  final double w; // 8..100 (%)
  final double h; // 8..100 (%)
  final int zIndex;
  final String cardStyle; // glass | solid | outline | minimal
  final String? accentColor;
  final double opacity; // 0.2..1.0
  final double scale; // 0.6..1.8
  final String align; // left | center | right
  final Map<String, dynamic> config;

  const ScreensaverWidget({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.zIndex = 1,
    this.cardStyle = 'glass',
    this.accentColor,
    this.opacity = 1.0,
    this.scale = 1.0,
    this.align = 'center',
    this.config = const {},
  });

  static double _clampD(num? v, double min, double max, double fallback) {
    if (v == null) return fallback;
    final d = v.toDouble();
    if (d.isNaN || d.isInfinite) return fallback;
    if (d < min) return min;
    if (d > max) return max;
    return d;
  }

  factory ScreensaverWidget.fromJson(Map<String, dynamic> json) {
    final w = _clampD(json['w'] as num?, 8, 100, 30);
    final h = _clampD(json['h'] as num?, 8, 100, 24);
    final x = _clampD(json['x'] as num?, 0, 100 - w, 10);
    final y = _clampD(json['y'] as num?, 0, 100 - h, 10);
    final rawCfg = json['config'];
    return ScreensaverWidget(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : 'w_${DateTime.now().microsecondsSinceEpoch}',
      type: (json['type'] as String?) ?? 'clock',
      x: x,
      y: y,
      w: w,
      h: h,
      zIndex: (json['z_index'] as num?)?.toInt() ?? 1,
      cardStyle: (json['card_style'] as String?) ?? 'glass',
      accentColor: json['accent_color'] as String?,
      opacity: _clampD(json['opacity'] as num?, 0.15, 1.0, 1.0),
      scale: _clampD(json['scale'] as num?, 0.6, 1.8, 1.0),
      align: (json['align'] as String?) ?? 'center',
      config: rawCfg is Map
          ? Map<String, dynamic>.from(rawCfg)
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'x': double.parse(x.toStringAsFixed(2)),
        'y': double.parse(y.toStringAsFixed(2)),
        'w': double.parse(w.toStringAsFixed(2)),
        'h': double.parse(h.toStringAsFixed(2)),
        'z_index': zIndex,
        'card_style': cardStyle,
        if (accentColor != null && accentColor!.isNotEmpty)
          'accent_color': accentColor,
        'opacity': double.parse(opacity.toStringAsFixed(2)),
        'scale': double.parse(scale.toStringAsFixed(2)),
        'align': align,
        'config': config,
      };

  ScreensaverWidget copyWith({
    String? id,
    String? type,
    double? x,
    double? y,
    double? w,
    double? h,
    int? zIndex,
    String? cardStyle,
    String? accentColor,
    bool clearAccentColor = false,
    double? opacity,
    double? scale,
    String? align,
    Map<String, dynamic>? config,
  }) {
    final nextW = (w ?? this.w).clamp(8.0, 100.0);
    final nextH = (h ?? this.h).clamp(8.0, 100.0);
    final nextX = (x ?? this.x).clamp(0.0, 100.0 - nextW);
    final nextY = (y ?? this.y).clamp(0.0, 100.0 - nextH);
    return ScreensaverWidget(
      id: id ?? this.id,
      type: type ?? this.type,
      x: nextX,
      y: nextY,
      w: nextW,
      h: nextH,
      zIndex: zIndex ?? this.zIndex,
      cardStyle: cardStyle ?? this.cardStyle,
      accentColor: clearAccentColor ? null : (accentColor ?? this.accentColor),
      opacity: (opacity ?? this.opacity).clamp(0.15, 1.0),
      scale: (scale ?? this.scale).clamp(0.6, 1.8),
      align: align ?? this.align,
      config: config ?? this.config,
    );
  }
}

class ScreensaverConfig {
  final String backgroundStyle; // oled_black | aurora | starfield | particles | mesh_glow | matrix_rain | image
  final String backgroundColor;
  final String accentColor;
  final String? backgroundImage; // Data URI (JPG/PNG/GIF)
  final String backgroundFit; // cover | contain
  final double backgroundDim; // 0.0..0.85
  final String animationSpeed; // slow | normal | vivid
  final bool burnInProtection;
  final bool showWakeHint;
  final String weatherCity;
  final String weatherUnit; // C | F
  final List<ScreensaverWidget> widgets;

  const ScreensaverConfig({
    this.backgroundStyle = 'aurora',
    this.backgroundColor = '#06070d',
    this.accentColor = '#cba6f7',
    this.backgroundImage,
    this.backgroundFit = 'cover',
    this.backgroundDim = 0.35,
    this.animationSpeed = 'normal',
    this.burnInProtection = true,
    this.showWakeHint = true,
    this.weatherCity = 'São Paulo',
    this.weatherUnit = 'C',
    this.widgets = const [],
  });

  factory ScreensaverConfig.fromJson(Map<String, dynamic> json) {
    final rawWidgets = json['widgets'];
    final list = <ScreensaverWidget>[];
    if (rawWidgets is List) {
      for (final item in rawWidgets) {
        if (item is Map) {
          list.add(ScreensaverWidget.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return ScreensaverConfig(
      backgroundStyle: (json['background_style'] as String?) ?? 'aurora',
      backgroundColor: (json['background_color'] as String?) ?? '#06070d',
      accentColor: (json['accent_color'] as String?) ?? '#cba6f7',
      backgroundImage: json['background_image'] as String?,
      backgroundFit: (json['background_fit'] as String?) ?? 'cover',
      backgroundDim:
          ((json['background_dim'] as num?)?.toDouble() ?? 0.35).clamp(0.0, 0.85),
      animationSpeed: (json['animation_speed'] as String?) ?? 'normal',
      burnInProtection: json['burn_in_protection'] as bool? ?? true,
      showWakeHint: json['show_wake_hint'] as bool? ?? true,
      weatherCity: (json['weather_city'] as String?) ?? 'São Paulo',
      weatherUnit: (json['weather_unit'] as String?) == 'F' ? 'F' : 'C',
      widgets: List.unmodifiable(list),
    );
  }

  Map<String, dynamic> toJson() => {
        'background_style': backgroundStyle,
        'background_color': backgroundColor,
        'accent_color': accentColor,
        if (backgroundImage != null && backgroundImage!.isNotEmpty)
          'background_image': backgroundImage,
        'background_fit': backgroundFit,
        'background_dim': double.parse(backgroundDim.toStringAsFixed(2)),
        'animation_speed': animationSpeed,
        'burn_in_protection': burnInProtection,
        'show_wake_hint': showWakeHint,
        'weather_city': weatherCity,
        'weather_unit': weatherUnit,
        'widgets': widgets.map((w) => w.toJson()).toList(),
      };

  ScreensaverConfig copyWith({
    String? backgroundStyle,
    String? backgroundColor,
    String? accentColor,
    String? backgroundImage,
    bool clearBackgroundImage = false,
    String? backgroundFit,
    double? backgroundDim,
    String? animationSpeed,
    bool? burnInProtection,
    bool? showWakeHint,
    String? weatherCity,
    String? weatherUnit,
    List<ScreensaverWidget>? widgets,
  }) {
    return ScreensaverConfig(
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundImage: clearBackgroundImage
          ? null
          : (backgroundImage ?? this.backgroundImage),
      backgroundFit: backgroundFit ?? this.backgroundFit,
      backgroundDim: (backgroundDim ?? this.backgroundDim).clamp(0.0, 0.85),
      animationSpeed: animationSpeed ?? this.animationSpeed,
      burnInProtection: burnInProtection ?? this.burnInProtection,
      showWakeHint: showWakeHint ?? this.showWakeHint,
      weatherCity: weatherCity ?? this.weatherCity,
      weatherUnit: weatherUnit ?? this.weatherUnit,
      widgets: widgets != null ? List.unmodifiable(widgets) : this.widgets,
    );
  }
}

/// Presets prontos de Tela de Suspensão para seleção rápida no CMS.
class ScreensaverPresets {
  static ScreensaverConfig auroraDesk({String city = 'São Paulo'}) =>
      ScreensaverConfig(
        backgroundStyle: 'aurora',
        backgroundColor: '#06070d',
        accentColor: '#cba6f7',
        animationSpeed: 'normal',
        burnInProtection: true,
        showWakeHint: true,
        weatherCity: city,
        widgets: const [
          ScreensaverWidget(
            id: 'clock_main',
            type: 'clock',
            x: 5,
            y: 10,
            w: 48,
            h: 38,
            zIndex: 2,
            cardStyle: 'minimal',
            align: 'left',
            config: {
              'clock_style': 'digital',
              'show_seconds': true,
              'show_date': true,
              'format_24h': true,
            },
          ),
          ScreensaverWidget(
            id: 'weather_main',
            type: 'weather',
            x: 58,
            y: 10,
            w: 37,
            h: 38,
            zIndex: 2,
            cardStyle: 'glass',
            config: {
              'show_forecast': true,
              'show_humidity': true,
              'show_feels_like': true,
              'show_wind': false,
            },
          ),
          ScreensaverWidget(
            id: 'pc_stats_main',
            type: 'pc_stats',
            x: 5,
            y: 54,
            w: 44,
            h: 34,
            zIndex: 2,
            cardStyle: 'glass',
            config: {
              'layout': 'rings',
              'show_cpu': true,
              'show_ram': true,
              'show_disk': true,
              'show_temp': true,
            },
          ),
          ScreensaverWidget(
            id: 'media_main',
            type: 'media',
            x: 52,
            y: 54,
            w: 43,
            h: 20,
            zIndex: 2,
            cardStyle: 'glass',
            config: {
              'show_controls': true,
              'show_vinyl': true,
            },
          ),
          ScreensaverWidget(
            id: 'batteries_main',
            type: 'batteries',
            x: 52,
            y: 77,
            w: 43,
            h: 11,
            zIndex: 2,
            cardStyle: 'glass',
            config: {
              'show_tablet': true,
              'show_pc': true,
              'show_bluetooth': true,
            },
          ),
        ],
      );

  static ScreensaverConfig minimalOled({String city = 'São Paulo'}) =>
      ScreensaverConfig(
        backgroundStyle: 'oled_black',
        backgroundColor: '#000000',
        accentColor: '#89b4fa',
        animationSpeed: 'slow',
        burnInProtection: true,
        showWakeHint: false,
        weatherCity: city,
        widgets: const [
          ScreensaverWidget(
            id: 'clock_oled',
            type: 'clock',
            x: 15,
            y: 18,
            w: 70,
            h: 38,
            zIndex: 2,
            cardStyle: 'minimal',
            align: 'center',
            scale: 1.15,
            config: {
              'clock_style': 'minimal',
              'show_seconds': false,
              'show_date': true,
              'format_24h': true,
            },
          ),
          ScreensaverWidget(
            id: 'weather_oled',
            type: 'weather',
            x: 25,
            y: 60,
            w: 50,
            h: 16,
            zIndex: 2,
            cardStyle: 'minimal',
            config: {
              'show_forecast': false,
              'show_humidity': true,
              'show_feels_like': false,
              'show_wind': false,
            },
          ),
          ScreensaverWidget(
            id: 'media_oled',
            type: 'media',
            x: 25,
            y: 78,
            w: 50,
            h: 14,
            zIndex: 2,
            cardStyle: 'minimal',
            config: {
              'show_controls': false,
              'show_vinyl': false,
            },
          ),
        ],
      );

  static ScreensaverConfig cyberTelemetry({String city = 'São Paulo'}) =>
      ScreensaverConfig(
        backgroundStyle: 'particles',
        backgroundColor: '#050811',
        accentColor: '#94e2d5',
        animationSpeed: 'normal',
        burnInProtection: true,
        showWakeHint: true,
        weatherCity: city,
        widgets: const [
          ScreensaverWidget(
            id: 'clock_cyber',
            type: 'clock',
            x: 4,
            y: 6,
            w: 36,
            h: 32,
            zIndex: 2,
            cardStyle: 'outline',
            accentColor: '#94e2d5',
            config: {
              'clock_style': 'split',
              'show_seconds': true,
              'show_date': true,
              'format_24h': true,
            },
          ),
          ScreensaverWidget(
            id: 'pc_cyber',
            type: 'pc_stats',
            x: 43,
            y: 6,
            w: 53,
            h: 38,
            zIndex: 2,
            cardStyle: 'glass',
            accentColor: '#89b4fa',
            config: {
              'layout': 'bars',
              'show_cpu': true,
              'show_ram': true,
              'show_disk': true,
              'show_temp': true,
            },
          ),
          ScreensaverWidget(
            id: 'net_cyber',
            type: 'network',
            x: 4,
            y: 42,
            w: 36,
            h: 24,
            zIndex: 2,
            cardStyle: 'glass',
            accentColor: '#a6e3a1',
            config: {'show_sparkline': true},
          ),
          ScreensaverWidget(
            id: 'pomo_cyber',
            type: 'pomodoro',
            x: 43,
            y: 48,
            w: 25,
            h: 22,
            zIndex: 2,
            cardStyle: 'glass',
            accentColor: '#f38ba8',
            config: {'show_cycle_dots': true},
          ),
          ScreensaverWidget(
            id: 'weather_cyber',
            type: 'weather',
            x: 71,
            y: 48,
            w: 25,
            h: 22,
            zIndex: 2,
            cardStyle: 'glass',
            config: {
              'show_forecast': false,
              'show_humidity': true,
              'show_feels_like': false,
              'show_wind': false,
            },
          ),
          ScreensaverWidget(
            id: 'todos_cyber',
            type: 'todos',
            x: 4,
            y: 70,
            w: 92,
            h: 22,
            zIndex: 2,
            cardStyle: 'glass',
            config: {'max_items': 3},
          ),
        ],
      );

  static ScreensaverConfig photoFrame({String city = 'São Paulo'}) =>
      ScreensaverConfig(
        backgroundStyle: 'starfield',
        backgroundColor: '#070812',
        accentColor: '#f5c2e7',
        animationSpeed: 'slow',
        burnInProtection: true,
        showWakeHint: true,
        weatherCity: city,
        widgets: const [
          ScreensaverWidget(
            id: 'photo_hero',
            type: 'image',
            x: 5,
            y: 8,
            w: 44,
            h: 82,
            zIndex: 1,
            cardStyle: 'glass',
            config: {
              'fit': 'cover',
              'border_radius': 20,
              'floating_anim': 'float',
            },
          ),
          ScreensaverWidget(
            id: 'clock_photo',
            type: 'clock',
            x: 53,
            y: 10,
            w: 42,
            h: 30,
            zIndex: 2,
            cardStyle: 'minimal',
            align: 'left',
            config: {
              'clock_style': 'digital',
              'show_seconds': false,
              'show_date': true,
              'format_24h': true,
            },
          ),
          ScreensaverWidget(
            id: 'weather_photo',
            type: 'weather',
            x: 53,
            y: 44,
            w: 42,
            h: 22,
            zIndex: 2,
            cardStyle: 'glass',
            config: {
              'show_forecast': false,
              'show_humidity': true,
              'show_feels_like': true,
              'show_wind': false,
            },
          ),
          ScreensaverWidget(
            id: 'media_photo',
            type: 'media',
            x: 53,
            y: 70,
            w: 42,
            h: 20,
            zIndex: 2,
            cardStyle: 'glass',
            config: {
              'show_controls': true,
              'show_vinyl': true,
            },
          ),
        ],
      );

  static Map<String, ScreensaverConfig> all({String city = 'São Paulo'}) => {
        'Aurora Desk': auroraDesk(city: city),
        'Minimal OLED': minimalOled(city: city),
        'Cyber Telemetry': cyberTelemetry(city: city),
        'Photo Frame': photoFrame(city: city),
      };
}
