import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/screensaver_config.dart';

/// Repositório isolado para a configuração da Tela de Suspensão (`screensaver.json`),
/// mantendo o contrato Golden de `layout.json` intacto.
class ScreensaverRepository {
  final File file;
  final Duration debounce;

  final _ctl = StreamController<ScreensaverConfig>.broadcast();
  ScreensaverConfig _current = ScreensaverPresets.auroraDesk();
  Timer? _saveTimer;

  ScreensaverRepository({
    required this.file,
    this.debounce = const Duration(milliseconds: 350),
  });

  Stream<ScreensaverConfig> get changes => _ctl.stream;
  ScreensaverConfig get current => _current;

  Future<void> load() async {
    try {
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            _current = ScreensaverConfig.fromJson(
              decoded.cast<String, dynamic>(),
            );
            return;
          }
        }
      }
    } catch (e) {
      stderr.writeln('ScreensaverRepository: erro ao ler ${file.path}: $e');
    }
    _current = ScreensaverPresets.auroraDesk();
  }

  /// Atualiza em memória imediatamente e agrupa gravação em disco + emissão MQTT
  /// via debounce (evita rajadas de ~60 pacotes/s com Base64 ao arrastar widgets).
  void update(ScreensaverConfig config) {
    _current = config;
    _saveTimer?.cancel();
    _saveTimer = Timer(debounce, () async {
      await _writeAtomic(_current);
      if (!_ctl.isClosed) _ctl.add(_current);
    });
  }

  /// Grava imediatamente no disco e re-emite no stream.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _writeAtomic(_current);
    if (!_ctl.isClosed) _ctl.add(_current);
  }

  Future<void> _writeAtomic(ScreensaverConfig cfg) async {
    try {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      const encoder = JsonEncoder.withIndent('  ');
      await tmp.writeAsString(encoder.convert(cfg.toJson()), flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      stderr.writeln('ScreensaverRepository: erro ao gravar ${file.path}: $e');
    }
  }

  Future<void> dispose() async {
    _saveTimer?.cancel();
    await _ctl.close();
  }
}
