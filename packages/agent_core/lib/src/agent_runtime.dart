import 'dart:async';
import 'dart:io';

import 'models/audio_state.dart';
import 'models/layout.dart';
import 'models/media_state.dart';
import 'services/audio/audio_controller.dart';
import 'services/audio/linux_audio_controller.dart';
import 'services/command_dispatcher.dart';
import 'services/layout_repository.dart';
import 'services/media_service.dart';
import 'services/mqtt_service.dart';

/// Orquestrador do node. Dart puro: o app Flutter e o daemon headless
/// hospedam exatamente este objeto.
class AgentRuntime {
  final LayoutRepository repository;
  final MqttService mqtt;
  final AudioController audio;
  final MediaService media;
  late final CommandDispatcher dispatcher;

  /// Janela da guarda de eco. Ao receber set_volume do tablet, o evento local
  /// que o proprio comando provoca e descartado — senao o slider do tablet
  /// treme (tablet manda 40 -> PC aplica -> PC publica 40 -> tablet redesenha
  /// no meio do arrasto).
  final Duration echoGuard;

  final _subs = <StreamSubscription<dynamic>>[];
  DateTime _suppressUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _started = false;

  AgentRuntime({
    required this.repository,
    required this.mqtt,
    AudioController? audio,
    MediaService? media,
    Set<String> allowedBinaries = const {},
    this.echoGuard = const Duration(milliseconds: 200),
  })  : audio = audio ?? _defaultAudio(),
        media = media ?? MediaService() {
    dispatcher = CommandDispatcher(
      audio: this.audio,
      media: this.media,
      layoutProvider: () => repository.current,
      allowedBinaries: allowedBinaries,
      onLocalVolumeChange: _armEchoGuard,
    );
  }

  static AudioController _defaultAudio() =>
      Platform.isLinux ? LinuxAudioController() : UnsupportedAudioController();

  Stream<AgentConnectionState> get connectionState => mqtt.connectionState;
  Stream<Layout> get layoutChanges => repository.changes;
  Stream<MasterVolume> get volumeChanges => audio.masterChanges;
  Stream<List<AppVolume>> get appVolumeChanges => audio.appsChanges;
  Stream<MediaState> get mediaChanges => media.changes;

  /// Boot: carrega disco, conecta, publica status + layout + snapshots.
  ///
  /// Fluxo unidirecional preservado: a UI so chama repository.save(); o stream
  /// do repositorio e quem alimenta o MQTT.
  Future<void> start({required String fallbackDeviceName}) async {
    if (_started) return;
    _started = true;

    final layout =
        await repository.load(fallbackDeviceName: fallbackDeviceName);

    _subs
      ..add(repository.changes.listen(mqtt.publishLayout))
      ..add(mqtt.commands.listen(_onCommand))
      ..add(audio.masterChanges.listen(_onLocalVolume))
      ..add(audio.appsChanges.listen(mqtt.publishApps))
      ..add(media.changes.listen(mqtt.publishMedia));

    // Republica o snapshot completo a cada (re)conexao: o retained do broker
    // pode estar velho se o agente rodou offline.
    _subs.add(mqtt.connectionState.listen((s) {
      if (s == AgentConnectionState.connected) _publishSnapshot();
    }));

    await mqtt.connect();
    await audio.start();
    await media.start();

    _publishSnapshot();
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
    mqtt.publishMedia(media.current);
  }

  Future<void> _onCommand(AgentCommand cmd) async {
    try {
      await dispatcher.dispatch(cmd);
    } catch (e) {
      stderr.writeln('erro ao processar $cmd: $e');
    }
  }

  void _armEchoGuard() =>
      _suppressUntil = DateTime.now().add(echoGuard);

  void _onLocalVolume(MasterVolume v) {
    if (DateTime.now().isBefore(_suppressUntil)) return; // eco do tablet
    mqtt.publishVolume(v);
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await media.dispose();
    await audio.dispose();
    await mqtt.dispose();
    await repository.dispose();
  }
}
