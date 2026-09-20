import 'dart:io';

import '../../models/audio_state.dart';

/// Contrato de audio. Abstrato de proposito: o nucleo e Dart puro e cada SO
/// implementa do seu jeito (wpctl/pactl no Linux, COM no Windows).
abstract interface class AudioController {
  /// Volume do sink padrao, 0-100. Emite so em mudanca.
  Stream<MasterVolume> get masterChanges;

  /// Mixer de aplicativos. Emite so em mudanca (lista inteira).
  Stream<List<AppVolume>> get appsChanges;

  MasterVolume get master;
  List<AppVolume> get apps;
  bool get isAvailable;

  Future<void> start();

  /// [value] 0-100.
  Future<void> setMasterVolume(int value);
  Future<void> setMute(bool muted);

  /// [value] 0-100, [id] e o id efemero vindo de [AppVolume.id].
  Future<void> setAppVolume(String id, int value);

  /// Forca releitura e emissao (usado no boot e apos comandos).
  Future<void> refresh();

  Future<void> dispose();
}

/// Stub para plataformas ainda nao implementadas. Mantem o runtime rodando
/// em vez de explodir no boot do Windows.
class UnsupportedAudioController implements AudioController {
  @override
  Stream<MasterVolume> get masterChanges => const Stream.empty();
  @override
  Stream<List<AppVolume>> get appsChanges => const Stream.empty();
  @override
  MasterVolume get master => const MasterVolume(value: 0);
  @override
  List<AppVolume> get apps => const [];
  @override
  bool get isAvailable => false;
  @override
  Future<void> start() async {
    stderr.writeln('audio: nenhuma implementacao para ${Platform.operatingSystem}');
  }

  @override
  Future<void> setMasterVolume(int value) async {}
  @override
  Future<void> setMute(bool muted) async {}
  @override
  Future<void> setAppVolume(String id, int value) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> dispose() async {}
}
