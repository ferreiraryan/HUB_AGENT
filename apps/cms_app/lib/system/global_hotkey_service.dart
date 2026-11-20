import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';

enum GlobalHotkeyStatus {
  disabled,
  ready,
  inUse,
  invalid,
  unsupported,
}

/// Escuta um atalho global de teclado do sistema operacional para abrir o
/// Spotlight de busca do Hub Agent de qualquer lugar (mesmo minimizado).
class GlobalHotkeyService {
  static final instance = GlobalHotkeyService._();
  GlobalHotkeyService._();

  final _triggerCtl = StreamController<void>.broadcast();
  Stream<void> get onTriggered => _triggerCtl.stream;

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  String _currentCombo = '';
  GlobalHotkeyStatus _status = GlobalHotkeyStatus.disabled;

  String get currentCombo => _currentCombo;
  GlobalHotkeyStatus get status => _status;

  /// Inicia ou atualiza o atalho global. String vazia desativa.
  /// Retorna o status do registro (ready, inUse, invalid, disabled, unsupported).
  Future<GlobalHotkeyStatus> updateHotkey(String combo) async {
    await stop();
    final trimmed = combo.trim().toLowerCase();
    _currentCombo = trimmed;

    if (trimmed.isEmpty) {
      _status = GlobalHotkeyStatus.disabled;
      return _status;
    }

    if (!Platform.isWindows) {
      _status = GlobalHotkeyStatus.unsupported;
      return _status;
    }

    final helperPath = WindowsBinaries.resolveHelperPath();
    if (helperPath == null) {
      _status = GlobalHotkeyStatus.unsupported;
      return _status;
    }

    final completer = Completer<GlobalHotkeyStatus>();

    try {
      final proc = await Process.start(
        helperPath,
        ['watch-hotkey', trimmed],
        mode: ProcessStartMode.normal,
      );
      _process = proc;

      _stdoutSub = proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final t = line.trim();
        if (t.isEmpty) return;
        try {
          final data = jsonDecode(t);
          if (data is Map<String, dynamic>) {
            final ev = data['event'] as String?;
            if (ev == 'ready') {
              _status = GlobalHotkeyStatus.ready;
              if (!completer.isCompleted) completer.complete(_status);
            } else if (ev == 'triggered') {
              if (!_triggerCtl.isClosed) _triggerCtl.add(null);
            } else if (ev == 'error') {
              final msg = data['message'] as String? ?? '';
              _status = msg == 'hotkey_in_use'
                  ? GlobalHotkeyStatus.inUse
                  : GlobalHotkeyStatus.invalid;
              if (!completer.isCompleted) completer.complete(_status);
            }
          }
        } catch (_) {}
      });

      proc.exitCode.then((_) {
        if (!completer.isCompleted) {
          _status = GlobalHotkeyStatus.invalid;
          completer.complete(_status);
        }
      });

      return await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => _status,
      );
    } catch (e) {
      stderr.writeln('GlobalHotkeyService erro ao iniciar: $e');
      _status = GlobalHotkeyStatus.invalid;
      return _status;
    }
  }

  Future<void> stop() async {
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    try {
      _process?.kill();
    } catch (_) {}
    _process = null;
  }

  Future<void> dispose() async {
    await stop();
    await _triggerCtl.close();
  }
}
