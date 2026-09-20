import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/audio_state.dart';
import 'audio_controller.dart';

/// Implementacao Linux (PipeWire via pipewire-pulse, ou PulseAudio puro).
///
/// Estrategia:
///  - master: `wpctl get-volume @DEFAULT_AUDIO_SINK@` (float -> int 0-100)
///  - apps:   `pactl -f json list sink-inputs` (JSON nativo, sem parse de
///            texto localizado — pactl >= 16)
///  - eventos: `pactl subscribe` em stdout, sem polling
class LinuxAudioController implements AudioController {
  final _masterCtl = StreamController<MasterVolume>.broadcast();
  final _appsCtl = StreamController<List<AppVolume>>.broadcast();

  Process? _subscription;
  Timer? _debounce;
  bool _available = false;
  bool _reading = false;

  MasterVolume _master = const MasterVolume(value: 0);
  List<AppVolume> _apps = const [];

  @override
  Stream<MasterVolume> get masterChanges => _masterCtl.stream;
  @override
  Stream<List<AppVolume>> get appsChanges => _appsCtl.stream;
  @override
  MasterVolume get master => _master;
  @override
  List<AppVolume> get apps => List.unmodifiable(_apps);
  @override
  bool get isAvailable => _available;

  @override
  Future<void> start() async {
    _available = await _which('wpctl') && await _which('pactl');
    if (!_available) {
      stderr.writeln('audio: wpctl/pactl ausentes; modulo desativado');
      return;
    }

    _subscription = await Process.start('pactl', ['subscribe']);
    _subscription!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((l) => l.contains('sink') || l.contains('server'))
        .listen((_) {
      // Debounce: mexer no slider gera rajada de eventos.
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 60), refresh);
    });

    await refresh();
  }

  @override
  Future<void> refresh() async {
    if (!_available || _reading) return;
    _reading = true;
    try {
      final next = await _readMaster();
      if (next != null && next != _master) {
        _master = next;
        if (!_masterCtl.isClosed) _masterCtl.add(next);
      }

      final nextApps = await _readApps();
      if (!_listEq(nextApps, _apps)) {
        _apps = nextApps;
        if (!_appsCtl.isClosed) _appsCtl.add(List.unmodifiable(nextApps));
      }
    } finally {
      _reading = false;
    }
  }

  /// `Volume: 0.45` ou `Volume: 0.45 [MUTED]`
  Future<MasterVolume?> _readMaster() async {
    try {
      final r = await Process.run('wpctl', ['get-volume', '@DEFAULT_AUDIO_SINK@'])
          .timeout(const Duration(seconds: 3));
      if (r.exitCode != 0) return null;
      final out = (r.stdout as String).trim();
      final m = RegExp(r'([\d.]+)').firstMatch(out);
      if (m == null) return null;
      final pct = (double.parse(m.group(1)!) * 100).round().clamp(0, 100);
      return MasterVolume(value: pct, muted: out.contains('MUTED'));
    } catch (_) {
      return null;
    }
  }

  Future<List<AppVolume>> _readApps() async {
    try {
      final r = await Process.run('pactl', ['-f', 'json', 'list', 'sink-inputs'])
          .timeout(const Duration(seconds: 3));
      if (r.exitCode != 0) return const [];
      final raw = jsonDecode(r.stdout as String);
      if (raw is! List) return const [];

      final result = <AppVolume>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final index = item['index'];
        if (index == null) continue;

        final props = (item['properties'] as Map?) ?? const {};
        final name = (props['application.name'] ??
                props['media.name'] ??
                'app $index')
            .toString();

        result.add(AppVolume(
          id: index.toString(),
          name: name,
          volume: _avgVolume(item['volume']),
        ));
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  /// pactl devolve por canal: { "front-left": { "value_percent": "45%" } }.
  /// Media dos canais, porque o tablet so tem um slider.
  int _avgVolume(Object? volume) {
    if (volume is! Map) return 0;
    final values = <int>[];
    for (final ch in volume.values) {
      if (ch is! Map) continue;
      final pct = ch['value_percent']?.toString();
      if (pct == null) continue;
      final n = int.tryParse(pct.replaceAll('%', '').trim());
      if (n != null) values.add(n);
    }
    if (values.isEmpty) return 0;
    return (values.reduce((a, b) => a + b) / values.length).round().clamp(0, 100);
  }

  @override
  Future<void> setMasterVolume(int value) async {
    if (!_available) return;
    final v = value.clamp(0, 100);
    await _run('wpctl', ['set-volume', '@DEFAULT_AUDIO_SINK@', '$v%']);
  }

  @override
  Future<void> setMute(bool muted) async {
    if (!_available) return;
    await _run('wpctl', ['set-mute', '@DEFAULT_AUDIO_SINK@', muted ? '1' : '0']);
  }

  @override
  Future<void> setAppVolume(String id, int value) async {
    if (!_available) return;
    final v = value.clamp(0, 100);
    // id e o index do sink-input. Se o app morreu, pactl falha e ignoramos:
    // o proximo refresh ja remove o item da lista.
    await _run('pactl', ['set-sink-input-volume', id, '$v%']);
  }

  Future<void> _run(String exe, List<String> args) async {
    try {
      await Process.run(exe, args).timeout(const Duration(seconds: 3));
    } catch (e) {
      stderr.writeln('audio: $exe ${args.join(' ')} falhou: $e');
    }
  }

  static Future<bool> _which(String bin) async {
    try {
      final r = await Process.run('which', [bin]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static bool _listEq(List<AppVolume> a, List<AppVolume> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<void> dispose() async {
    _debounce?.cancel();
    _subscription?.kill();
    await _masterCtl.close();
    await _appsCtl.close();
  }
}
