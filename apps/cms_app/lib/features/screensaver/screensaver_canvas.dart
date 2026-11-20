import 'dart:async';
import 'dart:math' as math;

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/cms_theme.dart';
import '../editor/helpers/image_icon_helper.dart';
import 'screensaver_controller.dart';

Color parseHexOrDefault(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  final clean = hex.replaceAll('#', '').trim();
  if (clean.length == 6) {
    final v = int.tryParse('FF$clean', radix: 16);
    if (v != null) return Color(v);
  } else if (clean.length == 8) {
    final v = int.tryParse(clean, radix: 16);
    if (v != null) return Color(v);
  }
  return fallback;
}

class ScreensaverCanvas extends ConsumerStatefulWidget {
  const ScreensaverCanvas({super.key});

  @override
  ConsumerState<ScreensaverCanvas> createState() => _ScreensaverCanvasState();
}

class _ScreensaverCanvasState extends ConsumerState<ScreensaverCanvas> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  bool _guideH = false;
  bool _guideV = false;

  // Estado temporário durante drag/resize para fluidez sem encher undo stack
  String? _draggingId;
  Offset? _dragStartLocal;
  ScreensaverWidget? _dragOrigin;
  String? _resizeMode; // null = move, 'br', 'r', 'b'

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  double _snap(double value, bool snapEnabled) {
    if (!snapEnabled) return value;
    return (value / 2.0).round() * 2.0;
  }

  void _startInteraction(
    ScreensaverWidget w,
    Offset localPos, {
    String? resizeMode,
  }) {
    ref.read(screensaverControllerProvider.notifier).selectWidget(w.id);
    setState(() {
      _draggingId = w.id;
      _dragStartLocal = localPos;
      _dragOrigin = w;
      _resizeMode = resizeMode;
    });
  }

  void _updateInteraction(Offset localPos, Size canvasSize) {
    if (_draggingId == null || _dragStartLocal == null || _dragOrigin == null) {
      return;
    }
    final state = ref.read(screensaverControllerProvider);
    final notifier = ref.read(screensaverControllerProvider.notifier);
    final dxPct = ((localPos.dx - _dragStartLocal!.dx) / canvasSize.width) * 100.0;
    final dyPct = ((localPos.dy - _dragStartLocal!.dy) / canvasSize.height) * 100.0;
    final orig = _dragOrigin!;

    if (_resizeMode == null) {
      var nextX = _snap((orig.x + dxPct).clamp(0.0, 100.0 - orig.w), state.snapToGrid);
      var nextY = _snap((orig.y + dyPct).clamp(0.0, 100.0 - orig.h), state.snapToGrid);

      // Snap magnético no centro (50%)
      final centerX = nextX + orig.w / 2;
      final centerY = nextY + orig.h / 2;
      final snapV = (centerX - 50.0).abs() < 1.6;
      final snapH = (centerY - 50.0).abs() < 1.6;
      if (snapV) nextX = (50.0 - orig.w / 2).clamp(0.0, 100.0 - orig.w);
      if (snapH) nextY = (50.0 - orig.h / 2).clamp(0.0, 100.0 - orig.h);

      if (_guideV != snapV || _guideH != snapH) {
        setState(() {
          _guideV = snapV;
          _guideH = snapH;
        });
      }

      notifier.updateWidget(
        orig.id,
        (w) => w.copyWith(x: nextX, y: nextY),
        recordUndo: false,
      );
    } else {
      var nextW = orig.w;
      var nextH = orig.h;
      if (_resizeMode == 'br' || _resizeMode == 'r') {
        nextW = _snap((orig.w + dxPct).clamp(10.0, 100.0 - orig.x), state.snapToGrid);
      }
      if (_resizeMode == 'br' || _resizeMode == 'b') {
        nextH = _snap((orig.h + dyPct).clamp(10.0, 100.0 - orig.y), state.snapToGrid);
      }
      notifier.updateWidget(
        orig.id,
        (w) => w.copyWith(w: nextW, h: nextH),
        recordUndo: false,
      );
    }
  }

  void _endInteraction() {
    if (_draggingId != null) {
      setState(() {
        _draggingId = null;
        _dragStartLocal = null;
        _dragOrigin = null;
        _resizeMode = null;
        _guideH = false;
        _guideV = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(screensaverControllerProvider);
    final config = editorState.config;
    final bgColor = parseHexOrDefault(config.backgroundColor, const Color(0xFF06070D));
    final accent = parseHexOrDefault(config.accentColor, const Color(0xFFCBA6F7));

    final sortedWidgets = [...config.widgets]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onTap: () => ref
                    .read(screensaverControllerProvider.notifier)
                    .selectWidget(null),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. Camada de fundo
                        _BackgroundPreview(
                          config: config,
                          bgColor: bgColor,
                          accent: accent,
                        ),

                        // 2. Grade de referência
                        if (editorState.showGrid)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _GridOverlayPainter(),
                            ),
                          ),

                        // 3. Guias de centralização
                        if (_guideV)
                          IgnorePointer(
                            child: Center(
                              child: Container(
                                width: 1.5,
                                height: double.infinity,
                                color: CmsTheme.blue.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        if (_guideH)
                          IgnorePointer(
                            child: Center(
                              child: Container(
                                height: 1.5,
                                width: double.infinity,
                                color: CmsTheme.blue.withValues(alpha: 0.8),
                              ),
                            ),
                          ),

                        // 4. Widgets posicionados em %
                        for (final w in sortedWidgets)
                          _buildPositionedWidget(
                            w,
                            size: size,
                            isSelected: w.id == editorState.selectedWidgetId,
                            globalAccent: accent,
                            weather: editorState.weatherPreview,
                          ),

                        // 5. Dica "Toque para voltar"
                        if (config.showWakeHint)
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 8,
                            child: IgnorePointer(
                              child: Text(
                                'TOQUE PARA VOLTAR',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.8,
                                  color: Colors.white24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPositionedWidget(
    ScreensaverWidget w, {
    required Size size,
    required bool isSelected,
    required Color globalAccent,
    required WeatherState? weather,
  }) {
    final left = (w.x / 100.0) * size.width;
    final top = (w.y / 100.0) * size.height;
    final width = (w.w / 100.0) * size.width;
    final height = (w.h / 100.0) * size.height;
    final accent = parseHexOrDefault(w.accentColor, globalAccent);

    BoxDecoration cardDecoration;
    switch (w.cardStyle) {
      case 'solid':
        cardDecoration = BoxDecoration(
          color: const Color(0xFF181825).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        );
        break;
      case 'outline':
        cardDecoration = BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.4),
        );
        break;
      case 'minimal':
        cardDecoration = BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        );
        break;
      case 'glass':
      default:
        cardDecoration = BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        );
        break;
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Área principal arrastável
          Positioned.fill(
            child: GestureDetector(
              onTap: () => ref
                  .read(screensaverControllerProvider.notifier)
                  .selectWidget(w.id),
              onPanStart: (d) => _startInteraction(w, d.globalPosition),
              onPanUpdate: (d) => _updateInteraction(d.globalPosition, size),
              onPanEnd: (_) => _endInteraction(),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Opacity(
                  opacity: w.opacity,
                  child: Container(
                    decoration: cardDecoration.copyWith(
                      border: isSelected
                          ? Border.all(color: CmsTheme.blue, width: 2)
                          : cardDecoration.border,
                    ),
                    padding: w.type == 'image'
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(10),
                    clipBehavior: Clip.antiAlias,
                    child: _WidgetLivePreview(
                      widget: w,
                      accent: accent,
                      now: _now,
                      weather: weather,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Etiqueta de seleção no topo
          if (isSelected)
            Positioned(
              left: 0,
              top: -20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CmsTheme.blue,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${_labelForType(w.type)} · ${w.w.round()}%×${w.h.round()}%',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF11111B),
                  ),
                ),
              ),
            ),

          // Alça de redimensionamento (canto inferior direito)
          if (isSelected)
            Positioned(
              right: -6,
              bottom: -6,
              child: GestureDetector(
                onPanStart: (d) =>
                    _startInteraction(w, d.globalPosition, resizeMode: 'br'),
                onPanUpdate: (d) => _updateInteraction(d.globalPosition, size),
                onPanEnd: (_) => _endInteraction(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: CmsTheme.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _labelForType(String type) {
    switch (type) {
      case 'clock':
        return 'Relógio';
      case 'weather':
        return 'Clima';
      case 'pc_stats':
        return 'Status PC';
      case 'media':
        return 'Mídia';
      case 'batteries':
        return 'Baterias';
      case 'pomodoro':
        return 'Pomodoro';
      case 'todos':
        return 'Tarefas';
      case 'network':
        return 'Rede';
      case 'image':
        return 'Imagem/GIF';
      case 'text':
        return 'Texto';
      default:
        return type;
    }
  }
}

class _BackgroundPreview extends StatelessWidget {
  final ScreensaverConfig config;
  final Color bgColor;
  final Color accent;

  const _BackgroundPreview({
    required this.config,
    required this.bgColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (config.backgroundStyle == 'image' &&
        config.backgroundImage != null &&
        config.backgroundImage!.isNotEmpty) {
      final bytes = ImageIconHelper.extractBytes(config.backgroundImage);
      return Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            Image.memory(
              bytes,
              fit: config.backgroundFit == 'contain'
                  ? BoxFit.contain
                  : BoxFit.cover,
              gaplessPlayback: true,
            ),
          Container(
            color: Colors.black.withValues(alpha: config.backgroundDim),
          ),
        ],
      );
    }

    switch (config.backgroundStyle) {
      case 'aurora':
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.55, -0.45),
              radius: 1.15,
              colors: [
                accent.withValues(alpha: 0.32),
                const Color(0xFF89B4FA).withValues(alpha: 0.14),
                bgColor,
              ],
            ),
          ),
        );
      case 'mesh_glow':
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.25),
                bgColor,
                const Color(0xFF94E2D5).withValues(alpha: 0.20),
              ],
            ),
          ),
        );
      case 'starfield':
      case 'particles':
      case 'matrix_rain':
        return CustomPaint(
          painter: _AnimatedStyleStaticPreviewPainter(
            style: config.backgroundStyle,
            accent: accent,
          ),
        );
      case 'oled_black':
      default:
        return Container(color: bgColor);
    }
  }
}

class _AnimatedStyleStaticPreviewPainter extends CustomPainter {
  final String style;
  final Color accent;

  _AnimatedStyleStaticPreviewPainter({
    required this.style,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    if (style == 'starfield') {
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.65);
      for (var i = 0; i < 65; i++) {
        final x = rng.nextDouble() * size.width;
        final y = rng.nextDouble() * size.height;
        final r = 0.6 + rng.nextDouble() * 1.4;
        paint.color = Colors.white.withValues(alpha: 0.2 + rng.nextDouble() * 0.7);
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    } else if (style == 'particles') {
      final pts = List.generate(
        26,
        (_) => Offset(
          rng.nextDouble() * size.width,
          rng.nextDouble() * size.height,
        ),
      );
      final linePaint = Paint()
        ..color = accent.withValues(alpha: 0.18)
        ..strokeWidth = 1;
      final dotPaint = Paint()..color = accent.withValues(alpha: 0.7);
      for (var i = 0; i < pts.length; i++) {
        canvas.drawCircle(pts[i], 2.2, dotPaint);
        for (var j = i + 1; j < pts.length; j++) {
          if ((pts[i] - pts[j]).distance < 110) {
            canvas.drawLine(pts[i], pts[j], linePaint);
          }
        }
      }
    } else if (style == 'matrix_rain') {
      final paint = Paint()
        ..color = accent.withValues(alpha: 0.25)
        ..strokeWidth = 2;
      for (var i = 0; i < 24; i++) {
        final x = (i + 0.5) * (size.width / 24);
        final top = rng.nextDouble() * size.height * 0.5;
        final len = 30 + rng.nextDouble() * 90;
        canvas.drawLine(Offset(x, top), Offset(x, top + len), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedStyleStaticPreviewPainter old) =>
      old.style != style || old.accent != accent;
}

class _GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const steps = 10;
    for (var i = 1; i < steps; i++) {
      final x = (size.width / steps) * i;
      final y = (size.height / steps) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WidgetLivePreview extends StatelessWidget {
  final ScreensaverWidget widget;
  final Color accent;
  final DateTime now;
  final WeatherState? weather;

  const _WidgetLivePreview({
    required this.widget,
    required this.accent,
    required this.now,
    required this.weather,
  });

  Alignment _alignment() {
    switch (widget.align) {
      case 'left':
        return Alignment.centerLeft;
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.center;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: _alignment(),
      child: _buildInner(),
    );
  }

  Widget _buildInner() {
    switch (widget.type) {
      case 'clock':
        final hh = now.hour.toString().padLeft(2, '0');
        final mm = now.minute.toString().padLeft(2, '0');
        final ss = now.second.toString().padLeft(2, '0');
        final showSec = widget.config['show_seconds'] as bool? ?? true;
        final showDate = widget.config['show_date'] as bool? ?? true;
        final style = widget.config['clock_style'] as String? ?? 'digital';
        if (style == 'analog') {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: CustomPaint(
                  painter: _MiniAnalogClockPainter(now: now, accent: accent),
                ),
              ),
              if (showDate) ...[
                const SizedBox(height: 6),
                Text(
                  '${now.day}/${now.month}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: widget.align == 'left'
              ? CrossAxisAlignment.start
              : widget.align == 'right'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$hh:$mm',
                  style: TextStyle(
                    fontSize: 44 * widget.scale,
                    fontWeight: style == 'minimal'
                        ? FontWeight.w200
                        : FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                if (showSec)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      ss,
                      style: TextStyle(
                        fontSize: 18 * widget.scale,
                        fontWeight: FontWeight.w500,
                        color: accent,
                      ),
                    ),
                  ),
              ],
            ),
            if (showDate)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Quinta-feira, ${now.day}/${now.month}',
                  style: TextStyle(
                    fontSize: 12 * widget.scale,
                    color: Colors.white60,
                  ),
                ),
              ),
          ],
        );

      case 'weather':
        final temp = weather != null ? '${weather!.temp.round()}°${weather!.unit}' : '24°C';
        final city = weather?.city ?? 'Clima';
        final cond = weather?.condition ?? 'Parcialmente nublado';
        final showFc = widget.config['show_forecast'] as bool? ?? true;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wb_sunny_rounded, color: accent, size: 28),
                const SizedBox(width: 8),
                Text(
                  temp,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Text(
              '$city · $cond',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
            if (showFc) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _MiniForecastPill('Sex', '26°'),
                  SizedBox(width: 6),
                  _MiniForecastPill('Sáb', '23°'),
                  SizedBox(width: 6),
                  _MiniForecastPill('Dom', '27°'),
                ],
              ),
            ],
          ],
        );

      case 'pc_stats':
        final layout = widget.config['layout'] as String? ?? 'rings';
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              layout == 'rings' ? 'STATUS DO PC (ANÉIS)' : 'STATUS DO PC',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniStatBadge('CPU', '34%', accent),
                const SizedBox(width: 8),
                _MiniStatBadge('RAM', '58%', const Color(0xFF89B4FA)),
                const SizedBox(width: 8),
                _MiniStatBadge('SSD', '71%', const Color(0xFFA6E3A1)),
              ],
            ),
          ],
        );

      case 'media':
        final showControls = widget.config['show_controls'] as bool? ?? true;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.album_rounded, color: accent, size: 26),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Now Playing',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                Text(
                  'Artista — Faixa atual',
                  style: TextStyle(fontSize: 10.5, color: Colors.white54),
                ),
              ],
            ),
            if (showControls) ...[
              const SizedBox(width: 10),
              const Icon(Icons.skip_previous_rounded,
                  size: 16, color: Colors.white70),
              Icon(Icons.play_arrow_rounded, size: 18, color: accent),
              const Icon(Icons.skip_next_rounded,
                  size: 16, color: Colors.white70),
            ],
          ],
        );

      case 'batteries':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.battery_charging_full,
                size: 15, color: Color(0xFFA6E3A1)),
            SizedBox(width: 4),
            Text('Tablet 84%', style: TextStyle(fontSize: 11, color: Colors.white)),
            SizedBox(width: 10),
            Icon(Icons.bluetooth, size: 14, color: Color(0xFF89B4FA)),
            SizedBox(width: 3),
            Text('Fone 62%', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        );

      case 'pomodoro':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('FOCO', style: TextStyle(fontSize: 9.5, color: accent, fontWeight: FontWeight.w700)),
            const Text('25:00', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        );

      case 'todos':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TAREFAS', style: TextStyle(fontSize: 9.5, color: accent, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('○ Revisar tarefas pendentes', style: TextStyle(fontSize: 11, color: Colors.white70)),
            const Text('○ Atualizar dashboard', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        );

      case 'network':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_rounded, color: accent, size: 20),
            const SizedBox(width: 8),
            const Text('↓ 12.4 MB/s  ↑ 2.1 MB/s',
                style: TextStyle(fontSize: 11.5, color: Colors.white)),
          ],
        );

      case 'image':
        final dataUri = widget.config['image_data'] as String?;
        final bytes = ImageIconHelper.extractBytes(dataUri);
        final radius = (widget.config['border_radius'] as num?)?.toDouble() ?? 14;
        if (bytes != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.memory(
              bytes,
              width: 240,
              height: 240,
              fit: widget.config['fit'] == 'contain'
                  ? BoxFit.contain
                  : BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 32, color: accent),
            const SizedBox(height: 4),
            const Text(
              'Escolha uma imagem\nno inspetor →',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: Colors.white54),
            ),
          ],
        );

      case 'text':
      default:
        final content =
            widget.config['content'] as String? ?? 'Hub Agent — Modo Ambiente';
        final fs = (widget.config['font_size'] as num?)?.toDouble() ?? 18;
        return Text(
          content,
          style: TextStyle(
            fontSize: fs,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        );
    }
  }
}

class _MiniForecastPill extends StatelessWidget {
  final String day;
  final String temp;
  const _MiniForecastPill(this.day, this.temp);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$day $temp',
          style: const TextStyle(fontSize: 10, color: Colors.white70)),
    );
  }
}

class _MiniStatBadge extends StatelessWidget {
  final String label;
  final String val;
  final Color color;
  const _MiniStatBadge(this.label, this.val, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w700)),
          Text(val,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MiniAnalogClockPainter extends CustomPainter {
  final DateTime now;
  final Color accent;
  _MiniAnalogClockPainter({required this.now, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final hAngle = ((now.hour % 12) + now.minute / 60) * (math.pi / 6) - math.pi / 2;
    final mAngle = now.minute * (math.pi / 30) - math.pi / 2;
    final sAngle = now.second * (math.pi / 30) - math.pi / 2;

    canvas.drawLine(
      c,
      c + Offset(math.cos(hAngle) * r * 0.5, math.sin(hAngle) * r * 0.5),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      c,
      c + Offset(math.cos(mAngle) * r * 0.74, math.sin(mAngle) * r * 0.74),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      c,
      c + Offset(math.cos(sAngle) * r * 0.82, math.sin(sAngle) * r * 0.82),
      Paint()
        ..color = accent
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniAnalogClockPainter old) =>
      old.now.second != now.second;
}
