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
import 'services/brightness_controller.dart';
import 'services/command_dispatcher.dart';
import 'services/key_sender_stub.dart'
    if (dart.library.io) 'services/key_sender_factory_io.dart';

class AgentRuntime {
  final LayoutRepository repository;
  final MqttService mqtt;
  final AudioController audio;
  final BrightnessController brightness;
  final MediaService media;
  final KeySender keySender;
  final StatsService stats;
  late final CommandDispatcher dispatcher;

  final Duration echoGuard;

  final _subs = <StreamSubscription<dynamic>>[];
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
    Set<String> allowedBinaries = const {},
    this.echoGuard = const Duration(milliseconds: 200),
  })  : audio = audio ?? createDefaultAudioController(),
        brightness = brightness ?? _defaultBrightness(),
        media = media ?? createDefaultMediaService(),
        keySender = keySender ?? createDefaultKeySender(),
        stats = stats ?? StatsService() {
    dispatcher = CommandDispatcher(
      audio: this.audio,
      brightness: this.brightness,
      media: this.media,
      keySender: this.keySender,
      layoutProvider: () => repository.current,
      allowedBinaries: allowedBinaries,
      onLocalVolumeChange: _armEchoGuard,
    );
  }

  static BrightnessController _defaultBrightness() => Platform.isLinux
      ? LinuxBrightnessController()
      : UnsupportedBrightnessController();

  Stream<AgentConnectionState> get connectionState => mqtt.connectionState;
  Stream<Layout> get layoutChanges => repository.changes;
  Stream<MasterVolume> get volumeChanges => audio.masterChanges;
  Stream<List<AppVolume>> get appVolumeChanges => audio.appsChanges;
  Stream<MediaState> get mediaChanges => media.changes;

  Future<void> start({required String fallbackDeviceName}) async {
    if (_started) return;
    _started = true;

    final layout =
        await repository.load(fallbackDeviceName: fallbackDeviceName);

    _subs
      ..add(repository.changes.listen((l) {
        mqtt.publishLayout(l);
        _publishBrightness();
      }))
      ..add(mqtt.commands.listen(_onCommand))
      ..add(audio.masterChanges.listen(_onLocalVolume))
      ..add(audio.appsChanges.listen(mqtt.publishApps))
      ..add(brightness.changes.listen((_) => _publishBrightness()))
      ..add(media.changes.listen(mqtt.publishMedia));

    _subs.add(mqtt.connectionState.listen((s) {
      if (s == AgentConnectionState.connected) _publishSnapshot();
    }));

    await mqtt.connect();
    await audio.start();
    await brightness.start();
    await media.start();
    await stats.start();

    _subs.add(stats.changes.listen((s) {
      mqtt.publishStatsCpu(s);
      mqtt.publishStatsRam(s);
      mqtt.publishStatsDisk(s);
    }));

    _brightnessPublishTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _publishBrightness());

    _publishSnapshot();
    await _publishBrightness();
    if (mqtt.isConnected) mqtt.publishLayout(layout);
  }

  void _publishSnapshot() {
    if (!mqtt.isConnected) return;
    mqtt.publishStatus(online: true);
    if (repository.isLoaded) mqtt.publishLayout(repository.current);
    if (audio.isAvailable) {
      mqtt.publishVolume(audio.master);
      mqtt.publishApps(audio.apps);
    }
    _publishBrightness();
    mqtt.publishMedia(media.current);
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
    } catch (e) {
      stderr.writeln('erro ao processar $cmd:$e');
    }
  }

  void _armEchoGuard() => _suppressUntil = DateTime.now().add(echoGuard);

  void _onLocalVolume(MasterVolume v) {
    if (DateTime.now().isBefore(_suppressUntil)) return;
    mqtt.publishVolume(v);
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _brightnessPublishTimer?.cancel();
    await keySender.dispose();
    await stats.dispose();
    await media.dispose();
    await brightness.dispose();
    await audio.dispose();
    await mqtt.dispose();
    await repository.dispose();
  }
}
