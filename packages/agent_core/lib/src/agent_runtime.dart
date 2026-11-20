import 'dart:async';
import 'dart:io';

import 'models/audio_state.dart';
import 'models/layout.dart';
import 'models/media_state.dart';
import 'models/tile.dart';
import 'services/layout_repository.dart';
import 'services/media_factory.dart';
import 'services/media_service.dart';
import 'services/mqtt_service.dart';
import 'services/key_sender.dart';
import 'services/stats/stats_service.dart';
import 'services/audio/audio_controller.dart';
import 'services/audio/audio_factory_stub.dart'
    if (dart.library.io) 'services/audio/audio_factory_io.dart';
import 'services/battery/battery_service.dart';
import 'services/brightness_controller.dart';
import 'services/brightness_windows.dart';
import 'services/clipboard/clipboard_service.dart';
import 'services/command_dispatcher.dart';
import 'services/key_sender_stub.dart'
    if (dart.library.io) 'services/key_sender_factory_io.dart';
import 'services/notifications/notification_monitor.dart';
import 'services/osd/osd_service.dart';
import 'services/pomodoro/pomodoro_service.dart';
import 'services/screensaver/screensaver_repository.dart';
import 'services/sound/sound_controller.dart';
import 'services/todo/todo_repository.dart';
import 'services/todo/todo_service.dart';
import 'services/weather/weather_service.dart';
import 'services/window/active_window_monitor.dart';
import 'services/window/page_rules_repository.dart';

class AgentRuntime {
  final LayoutRepository repository;
  final MqttService mqtt;
  final AudioController audio;
  final BrightnessController brightness;
  final MediaService media;
  final KeySender keySender;
  final StatsService stats;
  final SoundController? sound;
  final NotificationMonitor? notifications;
  final PomodoroService pomodoro;
  final TodoService todo;
  final OsdService osd;
  final BatteryService battery;
  final ActiveWindowMonitor activeWindow;
  final PageRulesRepository pageRules;
  final ClipboardService clipboard;
  final ScreensaverRepository screensaver;
  final WeatherService weather;
  late final CommandDispatcher dispatcher;

  final Duration echoGuard;

  final _remoteSearchPromptCtl = StreamController<void>.broadcast();
  Stream<void> get remoteSearchPrompts => _remoteSearchPromptCtl.stream;

  final _remoteTodoPromptCtl = StreamController<void>.broadcast();
  Stream<void> get remoteTodoPrompts => _remoteTodoPromptCtl.stream;

  final void Function()? onOpenCms;

  final _subs = <StreamSubscription<dynamic>>[];
  final _toggleStates = <String, String>{};
  final _lastPublishedAppVolumes = <String, int>{};
  Timer? _brightnessPublishTimer;
  DateTime _suppressUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _started = false;

  AgentRuntime({
    required this.repository,
    required this.mqtt,
    AudioController? audio,
    BrightnessController? brightness,
    MediaService? media,
    KeySender? keySender,
    StatsService? stats,
    SoundController? sound,
    PomodoroService? pomodoro,
    TodoService? todo,
    OsdService? osd,
    BatteryService? battery,
    ActiveWindowMonitor? activeWindow,
    PageRulesRepository? pageRules,
    ClipboardService? clipboard,
    ScreensaverRepository? screensaver,
    WeatherService? weather,
    this.notifications,
    this.onOpenCms,
    Set<String> allowedBinaries = const {},
    this.echoGuard = const Duration(milliseconds: 200),
  })  : audio = audio ?? createDefaultAudioController(),
        brightness = brightness ?? _defaultBrightness(),
        media = media ?? createDefaultMediaService(),
        keySender = keySender ?? createDefaultKeySender(),
        stats = stats ?? StatsService(),
        sound = sound ??
            SystemSoundController(
              soundsDir: Directory('${repository.file.parent.path}/sounds'),
            ),
        pomodoro = pomodoro ??
            PomodoroService(
              sound: sound,
              onNotification: mqtt.publishEvent,
            ),
        todo = todo ??
            TodoService(
              repository: TodoRepository(
                file: File('${repository.file.parent.path}/todos.json'),
              ),
            ),
        osd = osd ?? createDefaultOsdService(),
        battery = battery ??
            BatteryService(
              onLowBatteryEvent: mqtt.publishEvent,
            ),
        activeWindow = activeWindow ?? ActiveWindowMonitor(),
        pageRules = pageRules ??
            PageRulesRepository(
              file: File('${repository.file.parent.path}/page_rules.json'),
            ),
        clipboard = clipboard ?? ClipboardService(),
        screensaver = screensaver ??
            ScreensaverRepository(
              file: File('${repository.file.parent.path}/screensaver.json'),
            ),
        weather = weather ?? WeatherService() {
    dispatcher = CommandDispatcher(
      audio: this.audio,
      brightness: this.brightness,
      media: this.media,
      keySender: this.keySender,
      sound: this.sound,
      pomodoro: this.pomodoro,
      todo: this.todo,
      osd: this.osd,
      activeWindow: this.activeWindow,
      clipboard: this.clipboard,
      layoutProvider: () => repository.current,
      allowedBinaries: allowedBinaries,
      onLocalVolumeChange: _armEchoGuard,
      onEvent: mqtt.publishEvent,
      onPublishClipboard: mqtt.publishClipboard,
      onAudioOutputsRefresh: _publishAudioOutputs,
      onToggle: (id, newState) {
        _toggleStates[id] = newState;
        mqtt.publishToggleState(id, newState);
      },
      getToggleState: (id) => _toggleStates[id] ?? 'a',
      onRemoteSearchPrompt: () {
        if (!_remoteSearchPromptCtl.isClosed) {
          _remoteSearchPromptCtl.add(null);
        }
      },
      onRemoteTodoPrompt: () {
        if (!_remoteTodoPromptCtl.isClosed) {
          _remoteTodoPromptCtl.add(null);
        }
      },
      onOpenCms: onOpenCms,
    );
  }

  static BrightnessController _defaultBrightness() {
    if (Platform.isLinux) return LinuxBrightnessController();
    if (Platform.isWindows) return WindowsBrightnessController();
    return UnsupportedBrightnessController();
  }

  Stream<AgentConnectionState> get connectionState => mqtt.connectionState;
  Stream<Layout> get layoutChanges => repository.changes;
  Stream<MasterVolume> get volumeChanges => audio.masterChanges;
  Stream<List<AppVolume>> get appVolumeChanges => audio.appsChanges;
  Stream<MediaState> get mediaChanges => media.changes;

  Future<void> start({required String fallbackDeviceName}) async {
    if (_started) return;
    _started = true;

    await repository.load(fallbackDeviceName: fallbackDeviceName);
    await todo.init();
    await pageRules.load();
    await screensaver.load();

    _subs
      ..add(screensaver.changes.listen((cfg) {
        mqtt.publishScreensaverConfig(cfg);
        unawaited(weather.configure(
          city: cfg.weatherCity,
          unit: cfg.weatherUnit,
        ));
      }))
      ..add(weather.updates.listen(mqtt.publishWeather))
      ..add(repository.changes.listen((l) {
        _lastPublishedAppVolumes.clear();
        for (final page in l.pages.values) {
          for (final tile in page) {
            if (tile is PomodoroTile) {
              pomodoro.configureFromTile(tile);
              break;
            }
          }
        }
        mqtt.publishLayout(l);
        _publishBrightness();
        _publishSoundVolume();
        _publishAppSliderStates(audio.apps);
        _publishToggleStates();
      }))
      ..add(pomodoro.changes.listen(mqtt.publishPomodoroState))
      ..add(todo.changes.listen(mqtt.publishTodoState))
      ..add(battery.changes.listen(mqtt.publishBatteries))
      ..add(activeWindow.changes.listen(mqtt.publishActiveApp))
      ..add(pageRules.changes.listen(mqtt.publishPageRules))
      ..add(mqtt.commands.listen(_onCommand))
      ..add(audio.masterChanges.listen(_onLocalVolume))
      ..add(audio.appsChanges.listen((apps) {
        mqtt.publishApps(apps);
        _publishAppSliderStates(apps);
      }))
      ..add(brightness.changes.listen((_) => _publishBrightness()))
      ..add(media.changes.listen(mqtt.publishMedia));

    if (sound != null) {
      _subs.add(sound!.stateChanges.listen((state) {
        mqtt.publishSoundState(state);
      }));
    }

    if (notifications != null) {
      _subs.add(notifications!.notifications.listen((event) {
        mqtt.publishEvent(event);
      }));
    }

    _subs.add(mqtt.connectionState.listen((s) {
      if (s == AgentConnectionState.connected) _publishSnapshot();
    }));

    if (audio case final ExtendedAudioController ext) {
      _subs.add(ext.micChanges.listen(mqtt.publishMicState));
    }

    await mqtt.connect();
    await audio.start();
    await brightness.start();
    await media.start();
    await stats.start();
    await battery.start();
    await activeWindow.start();
    await notifications?.start();
    weather.start(
      city: screensaver.current.weatherCity,
      unit: screensaver.current.weatherUnit,
    );

    _subs.add(stats.changes.listen((s) {
      mqtt.publishStatsCpu(s);
      mqtt.publishStatsRam(s);
      mqtt.publishStatsDisk(s);
      mqtt.publishStatsNet(s);
      mqtt.publishStatsGpu(s);
    }));

    _brightnessPublishTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _publishBrightness());

    _publishSnapshot();
  }

  Future<void> _publishAudioOutputs() async {
    if (!mqtt.isConnected || sound == null) return;
    try {
      final list = await sound!.listDevices();
      if (list.isNotEmpty) {
        mqtt.publishAudioOutputs(list);
      }
    } catch (_) {}
  }

  void _publishSnapshot() {
    if (!mqtt.isConnected) return;
    mqtt.publishStatus(online: true);
    if (repository.isLoaded) mqtt.publishLayout(repository.current);
    if (audio.isAvailable) {
      mqtt.publishVolume(audio.master);
      mqtt.publishApps(audio.apps);
      if (audio case final ExtendedAudioController ext) {
        mqtt.publishMicState(ext.mic);
      }
    }
    unawaited(_publishAudioOutputs());
    _publishBrightness();
    _publishSoundVolume();
    _publishAppSliderStates(audio.apps);
    _publishToggleStates();
    mqtt.publishMedia(media.current);
    if (sound != null) {
      mqtt.publishSoundState(sound!.current);
    }
    mqtt.publishPomodoroState(pomodoro.current);
    mqtt.publishTodoState(todo.current);
    mqtt.publishBatteries(battery.current);
    mqtt.publishActiveApp(activeWindow.current);
    mqtt.publishPageRules(pageRules.current);
    mqtt.publishScreensaverConfig(screensaver.current);
    final w = weather.current;
    if (w != null) mqtt.publishWeather(w);
  }

  void _publishSoundVolume() {
    if (!mqtt.isConnected || sound == null) return;
    final layout = repository.isLoaded ? repository.current : null;
    if (layout == null) return;

    for (final page in layout.pages.values) {
      for (final tile in page) {
        if (tile is SliderTile &&
            tile.source.kind == SliderSource.kindSoundVolume) {
          mqtt.publishSliderState(tile.id, sound!.volume);
        }
      }
    }
  }

  void _publishAppSliderStates(List<AppVolume> apps) {
    if (!mqtt.isConnected) return;
    final layout = repository.isLoaded ? repository.current : null;
    if (layout == null) return;

    for (final page in layout.pages.values) {
      for (final tile in page) {
        if (tile is SliderTile &&
            tile.source.kind == SliderSource.kindAppVolume &&
            tile.source.match != null &&
            tile.source.match!.isNotEmpty) {
          final target = tile.source.match!;
          for (final app in apps) {
            if (app.matchesTarget(target)) {
              if (_lastPublishedAppVolumes[tile.id] != app.volume) {
                _lastPublishedAppVolumes[tile.id] = app.volume;
                mqtt.publishSliderState(tile.id, app.volume);
              }
              break;
            }
          }
        }
      }
    }
  }

  void _publishToggleStates() {
    if (!mqtt.isConnected) return;
    final layout = repository.isLoaded ? repository.current : null;
    if (layout == null) return;

    for (final page in layout.pages.values) {
      for (final tile in page) {
        if (tile is ToggleTile) {
          final state = _toggleStates.putIfAbsent(tile.id, () => tile.initialState);
          mqtt.publishToggleState(tile.id, state);
        }
      }
    }
  }

  Future<void> _publishBrightness() async {
    if (!mqtt.isConnected) return;
    final layout = repository.isLoaded ? repository.current : null;
    if (layout == null) return;

    for (final page in layout.pages.values) {
      for (final tile in page) {
        if (tile is SliderTile &&
            tile.source.kind == SliderSource.kindBrightness) {
          final v = await brightness.readForDisplay(tile.source.match ?? '');
          if (v != null) {
            mqtt.publishSliderState(tile.id, v);
          }
        }
      }
    }
  }

  Future<void> _onCommand(AgentCommand cmd) async {
    try {
      await dispatcher.dispatch(cmd);
      if (cmd.action == 'set_slider' && cmd.sliderId != null) {
        final tile = dispatcher.findSliderTile(cmd.sliderId!);
        if (tile != null) {
          if (tile.source.kind == SliderSource.kindBrightness) {
            final v = await brightness.readForDisplay(tile.source.match ?? '');
            if (v != null) mqtt.publishSliderState(tile.id, v);
          } else if (tile.source.kind == SliderSource.kindSoundVolume && sound != null) {
            mqtt.publishSliderState(tile.id, sound!.volume);
          } else if (tile.source.kind == SliderSource.kindAppVolume && cmd.value != null) {
            mqtt.publishSliderState(tile.id, cmd.value!);
          }
        }
      }
    } catch (e) {
      stderr.writeln('erro ao processar $cmd:$e');
    }
  }

  void _armEchoGuard() => _suppressUntil = DateTime.now().add(echoGuard);

  void _onLocalVolume(MasterVolume v) {
    if (DateTime.now().isBefore(_suppressUntil)) return;
    mqtt.publishVolume(v);
  }

  void publishSearchQuery(
    String query, {
    bool active = true,
    String filter = 'all',
    String scope = 'all',
  }) {
    mqtt.publishSearchQuery(
      query,
      active: active,
      filter: filter,
      scope: scope,
    );
  }

  /// Dispara uma ação de tile/comando localmente a partir da UI do PC (ex: Spotlight).
  Future<void> triggerAction(String action) =>
      _onCommand(AgentCommand(action, {'action': action}));

  /// Força reconexão imediata do broker MQTT.
  Future<void> reconnectMqtt() => mqtt.reconnect();

  /// Reconfigura host/porta/deviceId do broker em tempo real sem reiniciar o app.
  Future<void> reconfigureMqtt({
    required String host,
    required int port,
    required String deviceId,
  }) =>
      mqtt.reconfigure(host: host, port: port, deviceId: deviceId);

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _brightnessPublishTimer?.cancel();
    await _remoteSearchPromptCtl.close();
    await _remoteTodoPromptCtl.close();
    await notifications?.dispose();
    await sound?.dispose();
    await pomodoro.dispose();
    await todo.dispose();
    await osd.dispose();
    await battery.dispose();
    await activeWindow.dispose();
    await pageRules.dispose();
    await screensaver.dispose();
    await weather.dispose();
    await keySender.dispose();
    await stats.dispose();
    await media.dispose();
    await brightness.dispose();
    await audio.dispose();
    await mqtt.dispose();
    await repository.dispose();
  }
}
