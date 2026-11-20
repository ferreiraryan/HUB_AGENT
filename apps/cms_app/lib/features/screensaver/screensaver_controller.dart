import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class ScreensaverEditorState {
  final ScreensaverConfig config;
  final String? selectedWidgetId;
  final bool showGrid;
  final bool snapToGrid;
  final List<ScreensaverConfig> undoStack;
  final List<ScreensaverConfig> redoStack;
  final WeatherState? weatherPreview;
  final bool loadingWeather;

  const ScreensaverEditorState({
    required this.config,
    this.selectedWidgetId,
    this.showGrid = true,
    this.snapToGrid = true,
    this.undoStack = const [],
    this.redoStack = const [],
    this.weatherPreview,
    this.loadingWeather = false,
  });

  ScreensaverWidget? get selectedWidget {
    if (selectedWidgetId == null) return null;
    for (final w in config.widgets) {
      if (w.id == selectedWidgetId) return w;
    }
    return null;
  }

  ScreensaverEditorState copyWith({
    ScreensaverConfig? config,
    String? selectedWidgetId,
    bool clearSelection = false,
    bool? showGrid,
    bool? snapToGrid,
    List<ScreensaverConfig>? undoStack,
    List<ScreensaverConfig>? redoStack,
    WeatherState? weatherPreview,
    bool? loadingWeather,
  }) {
    return ScreensaverEditorState(
      config: config ?? this.config,
      selectedWidgetId: clearSelection
          ? null
          : (selectedWidgetId ?? this.selectedWidgetId),
      showGrid: showGrid ?? this.showGrid,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      weatherPreview: weatherPreview ?? this.weatherPreview,
      loadingWeather: loadingWeather ?? this.loadingWeather,
    );
  }
}

class ScreensaverController extends Notifier<ScreensaverEditorState> {
  StreamSubscription<WeatherState>? _weatherSub;

  @override
  ScreensaverEditorState build() {
    ScreensaverConfig initial = ScreensaverPresets.auroraDesk();
    WeatherState? initialWeather;

    try {
      final bridge = ref.watch(agentBridgeProvider);
      initial = bridge.currentScreensaver;
      initialWeather = bridge.currentWeather;
      _weatherSub?.cancel();
      _weatherSub = bridge.weatherUpdates.listen((w) {
        state = state.copyWith(weatherPreview: w, loadingWeather: false);
      });
    } catch (_) {
      // Testes isolados sem agentBridgeProvider
    }

    ref.onDispose(() {
      _weatherSub?.cancel();
    });

    return ScreensaverEditorState(
      config: initial,
      selectedWidgetId:
          initial.widgets.isNotEmpty ? initial.widgets.first.id : null,
      weatherPreview: initialWeather,
    );
  }

  void _commit(ScreensaverConfig next, {bool recordUndo = true}) {
    List<ScreensaverConfig> undo = state.undoStack;
    if (recordUndo) {
      final list = List<ScreensaverConfig>.of(state.undoStack)..add(state.config);
      if (list.length > 15) {
        list.removeAt(0);
      }
      undo = list;
    }
    state = state.copyWith(
      config: next,
      undoStack: undo,
      redoStack: recordUndo ? const [] : state.redoStack,
    );
    try {
      ref.read(agentBridgeProvider).updateScreensaver(next);
    } catch (_) {}
  }

  void selectWidget(String? id) {
    state = state.copyWith(
      selectedWidgetId: id,
      clearSelection: id == null,
    );
  }

  void toggleGrid() => state = state.copyWith(showGrid: !state.showGrid);
  void toggleSnap() => state = state.copyWith(snapToGrid: !state.snapToGrid);

  void undo() {
    if (state.undoStack.isEmpty) return;
    final prev = state.undoStack.last;
    final nextUndo = state.undoStack.sublist(0, state.undoStack.length - 1);
    final nextRedo = [...state.redoStack, state.config];
    state = state.copyWith(
      config: prev,
      undoStack: nextUndo,
      redoStack: nextRedo,
    );
    try {
      ref.read(agentBridgeProvider).updateScreensaver(prev);
    } catch (_) {}
  }

  void redo() {
    if (state.redoStack.isEmpty) return;
    final next = state.redoStack.last;
    final nextRedo = state.redoStack.sublist(0, state.redoStack.length - 1);
    final nextUndo = [...state.undoStack, state.config];
    state = state.copyWith(
      config: next,
      undoStack: nextUndo,
      redoStack: nextRedo,
    );
    try {
      ref.read(agentBridgeProvider).updateScreensaver(next);
    } catch (_) {}
  }

  void applyPreset(ScreensaverConfig preset) {
    _commit(preset.copyWith(
      weatherCity: state.config.weatherCity,
      weatherUnit: state.config.weatherUnit,
    ));
    state = state.copyWith(
      selectedWidgetId:
          preset.widgets.isNotEmpty ? preset.widgets.first.id : null,
      clearSelection: preset.widgets.isEmpty,
    );
  }

  void updateConfig(ScreensaverConfig Function(ScreensaverConfig c) fn) {
    _commit(fn(state.config));
  }

  Future<WeatherState?> refreshWeather({String? city, String? unit}) async {
    final targetCity = (city ?? state.config.weatherCity).trim();
    final targetUnit = unit ?? state.config.weatherUnit;
    if (city != null || unit != null) {
      _commit(state.config.copyWith(
        weatherCity: targetCity,
        weatherUnit: targetUnit,
      ));
    }
    state = state.copyWith(loadingWeather: true);
    try {
      final w = await ref
          .read(agentBridgeProvider)
          .configureWeather(city: targetCity, unit: targetUnit);
      state = state.copyWith(weatherPreview: w, loadingWeather: false);
      return w;
    } catch (_) {
      state = state.copyWith(loadingWeather: false);
      return null;
    }
  }

  void addWidget(String type) {
    final maxZ = state.config.widgets.fold<int>(
      0,
      (acc, w) => w.zIndex > acc ? w.zIndex : acc,
    );
    final id = '${type}_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final widget = _defaultWidgetFor(type, id: id, zIndex: maxZ + 1);
    _commit(state.config.copyWith(
      widgets: [...state.config.widgets, widget],
    ));
    selectWidget(id);
  }

  void removeWidget(String id) {
    final next = state.config.widgets.where((w) => w.id != id).toList();
    _commit(state.config.copyWith(widgets: next));
    if (state.selectedWidgetId == id) {
      selectWidget(next.isNotEmpty ? next.last.id : null);
    }
  }

  void duplicateWidget(String id) {
    final src = state.config.widgets.where((w) => w.id == id).firstOrNull;
    if (src == null) return;
    final newId = '${src.type}_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final copy = src.copyWith(
      id: newId,
      x: (src.x + 4).clamp(0, 100 - src.w),
      y: (src.y + 4).clamp(0, 100 - src.h),
      zIndex: src.zIndex + 1,
    );
    _commit(state.config.copyWith(
      widgets: [...state.config.widgets, copy],
    ));
    selectWidget(newId);
  }

  void updateWidget(
    String id,
    ScreensaverWidget Function(ScreensaverWidget w) fn, {
    bool recordUndo = true,
  }) {
    final list = [
      for (final w in state.config.widgets) w.id == id ? fn(w) : w,
    ];
    _commit(state.config.copyWith(widgets: list), recordUndo: recordUndo);
  }

  void bringToFront(String id) {
    final maxZ = state.config.widgets.fold<int>(
      0,
      (acc, w) => w.zIndex > acc ? w.zIndex : acc,
    );
    updateWidget(id, (w) => w.copyWith(zIndex: maxZ + 1));
  }

  void sendToBack(String id) {
    final minZ = state.config.widgets.fold<int>(
      1,
      (acc, w) => w.zIndex < acc ? w.zIndex : acc,
    );
    updateWidget(id, (w) => w.copyWith(zIndex: (minZ - 1).clamp(0, 999)));
  }

  Future<void> publishAndPreviewOnTablet() async {
    try {
      await ref.read(agentBridgeProvider).previewScreensaverOnTablet();
    } catch (_) {}
  }

  Future<void> flush() async {
    try {
      await ref.read(agentBridgeProvider).flushScreensaver();
    } catch (_) {}
  }

  ScreensaverWidget _defaultWidgetFor(
    String type, {
    required String id,
    required int zIndex,
  }) {
    switch (type) {
      case 'clock':
        return ScreensaverWidget(
          id: id,
          type: 'clock',
          x: 25,
          y: 12,
          w: 50,
          h: 34,
          zIndex: zIndex,
          cardStyle: 'minimal',
          config: const {
            'clock_style': 'digital',
            'show_seconds': true,
            'show_date': true,
            'format_24h': true,
          },
        );
      case 'weather':
        return ScreensaverWidget(
          id: id,
          type: 'weather',
          x: 56,
          y: 12,
          w: 38,
          h: 36,
          zIndex: zIndex,
          cardStyle: 'glass',
          config: const {
            'show_forecast': true,
            'show_humidity': true,
            'show_feels_like': true,
            'show_wind': false,
          },
        );
      case 'pc_stats':
        return ScreensaverWidget(
          id: id,
          type: 'pc_stats',
          x: 6,
          y: 52,
          w: 44,
          h: 34,
          zIndex: zIndex,
          cardStyle: 'glass',
          config: const {
            'layout': 'rings',
            'show_cpu': true,
            'show_ram': true,
            'show_disk': true,
            'show_temp': true,
          },
        );
      case 'media':
        return ScreensaverWidget(
          id: id,
          type: 'media',
          x: 52,
          y: 54,
          w: 42,
          h: 22,
          zIndex: zIndex,
          cardStyle: 'glass',
          config: const {'show_controls': true, 'show_vinyl': true},
        );
      case 'batteries':
        return ScreensaverWidget(
          id: id,
          type: 'batteries',
          x: 52,
          y: 78,
          w: 42,
          h: 14,
          zIndex: zIndex,
          cardStyle: 'glass',
          config: const {
            'show_tablet': true,
            'show_pc': true,
            'show_bluetooth': true,
          },
        );
      case 'pomodoro':
        return ScreensaverWidget(
          id: id,
          type: 'pomodoro',
          x: 35,
          y: 35,
          w: 30,
          h: 26,
          zIndex: zIndex,
          cardStyle: 'glass',
          config: const {'show_cycle_dots': true},
        );
      case 'todos':
        return ScreensaverWidget(
          id: id,
          type: 'todos',
          x: 6,
          y: 60,
          w: 46,
          h: 30,
          zIndex: zIndex,
          cardStyle: 'glass',
          config: const {'max_items': 4},
        );
      case 'network':
        return ScreensaverWidget(
          id: id,
          type: 'network',
          x: 6,
          y: 44,
          w: 38,
          h: 24,
          zIndex: zIndex,
          cardStyle: 'glass',
          config: const {'show_sparkline': true},
        );
      case 'image':
        return ScreensaverWidget(
          id: id,
          type: 'image',
          x: 10,
          y: 14,
          w: 36,
          h: 58,
          zIndex: zIndex,
          cardStyle: 'glass',
          config: const {
            'fit': 'cover',
            'border_radius': 18,
            'floating_anim': 'float',
          },
        );
      case 'text':
      default:
        return ScreensaverWidget(
          id: id,
          type: 'text',
          x: 20,
          y: 76,
          w: 60,
          h: 14,
          zIndex: zIndex,
          cardStyle: 'minimal',
          config: const {
            'content': 'Hub Agent — Modo Ambiente',
            'font_size': 20,
          },
        );
    }
  }
}

final screensaverControllerProvider =
    NotifierProvider<ScreensaverController, ScreensaverEditorState>(
  ScreensaverController.new,
);
