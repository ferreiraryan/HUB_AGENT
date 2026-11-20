import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'windows_binaries.dart';

/// Bridge persistente NDJSON para o processo único `hub_audio_helper.exe daemon`.
///
/// Mantém todas as chamadas Win32/COM/WASAPI/WinRT/GDI+ isoladas em um único
/// processo externo (sem FFI no Dart) e elimina ~200 spawns/min de processos
/// efêmeros no Windows.
///
/// Se o executável instalado ainda não suportar o subcomando `daemon`, marca
/// [isDaemonSupported] como `false` para que os controladores façam fallback
/// automático e transparente para os comandos CLI legados.
class WindowsHelperBridge {
  static final WindowsHelperBridge instance = WindowsHelperBridge();

  final String? _helperPathOverride;
  final Future<Process> Function(
    String executable,
    List<String> arguments, {
    bool runInShell,
  }) _processStarter;

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  Completer<bool>? _readyCompleter;
  Timer? _restartTimer;

  bool _started = false;
  bool _disposed = false;
  bool _daemonSupported = true;
  bool _isReady = false;
  int _nextId = 1;
  int _restartAttempt = 0;

  // Estado persistente reaplicado automaticamente em caso de restart do daemon.
  String? _activeHotkeyCombo;
  bool _notificationsEnabled = false;
  bool _activeWindowEnabled = false;
  bool _trayEnabled = false;
  String _trayStatus = 'disconnected';
  String? _trayIconPath;

  final Map<int, Completer<Map<String, dynamic>?>> _pending = {};

  final _activeWindowCtl = StreamController<Map<String, dynamic>>.broadcast();
  final _audioCtl = StreamController<Map<String, dynamic>>.broadcast();
  final _mediaCtl = StreamController<Map<String, dynamic>>.broadcast();
  final _hotkeyCtl = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationCtl = StreamController<Map<String, dynamic>>.broadcast();
  final _trayCtl = StreamController<Map<String, dynamic>>.broadcast();

  WindowsHelperBridge({
    String? helperPathOverride,
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      bool runInShell,
    })? processStarter,
  })  : _helperPathOverride = helperPathOverride,
        _processStarter = processStarter ?? Process.start;

  bool get isRunning => _process != null && _isReady && !_disposed;
  bool get isDaemonSupported => _daemonSupported;

  Stream<Map<String, dynamic>> get activeWindowEvents => _activeWindowCtl.stream;
  Stream<Map<String, dynamic>> get audioEvents => _audioCtl.stream;
  Stream<Map<String, dynamic>> get mediaEvents => _mediaCtl.stream;
  Stream<Map<String, dynamic>> get hotkeyEvents => _hotkeyCtl.stream;
  Stream<Map<String, dynamic>> get notificationEvents => _notificationCtl.stream;
  Stream<Map<String, dynamic>> get trayEvents => _trayCtl.stream;

  /// Inicia o daemon persistente caso ainda não esteja em execução.
  /// Retorna `true` se o daemon ficou pronto; `false` se deve usar fallback CLI.
  Future<bool> ensureStarted() async {
    if (_disposed || !_daemonSupported) return false;
    if (_isReady && _process != null) return true;
    if (_readyCompleter != null) return _readyCompleter!.future;

    final path = _helperPathOverride ?? WindowsBinaries.resolveHelperPath();
    if (path == null) {
      _daemonSupported = false;
      return false;
    }

    _started = true;
    final completer = Completer<bool>();
    _readyCompleter = completer;

    try {
      final proc = await _processStarter(
        path,
        const ['daemon'],
        runInShell: false,
      );
      _process = proc;

      _stdoutSub = proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleLine,
            onError: (Object e) {
              stderr.writeln('WindowsHelperBridge stdout error: $e');
            },
          );

      _stderrSub = proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.contains('Unknown command')) {
              _daemonSupported = false;
            }
          });

      proc.exitCode.then((code) {
        if (_process == proc) {
          _onProcessExited(code);
        }
      });

      final ready = await completer.future.timeout(
        const Duration(milliseconds: 2000),
        onTimeout: () => false,
      );

      if (!ready) {
        if (!_isReady) {
          _daemonSupported = false;
          await _stopProcessOnly();
        }
        return false;
      }

      _restartAttempt = 0;
      await _reapplySubscriptions();
      return true;
    } catch (e) {
      stderr.writeln('WindowsHelperBridge: falha ao iniciar daemon: $e');
      if (!completer.isCompleted) completer.complete(false);
      _readyCompleter = null;
      return false;
    }
  }

  /// Envia uma requisição com resposta correlacionada por `id`.
  /// Retorna `null` se o daemon não estiver pronto ou em caso de erro/timeout.
  Future<Map<String, dynamic>?> request(
    String cmd, {
    Map<String, dynamic>? args,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!isRunning) {
      final ok = await ensureStarted();
      if (!ok) return null;
    }

    final id = _nextId++;
    final payload = <String, dynamic>{
      'id': id,
      'cmd': cmd,
      if (args != null) ...args,
    };

    final completer = Completer<Map<String, dynamic>?>();
    _pending[id] = completer;

    try {
      _process!.stdin.writeln(jsonEncode(payload));
      await _process!.stdin.flush();
    } catch (_) {
      _pending.remove(id);
      return null;
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        return null;
      },
    );
  }

  /// Envia um comando unidirecional (fire-and-forget) ao daemon.
  Future<bool> sendCommand(String cmd, [Map<String, dynamic>? args]) async {
    if (!isRunning) {
      final ok = await ensureStarted();
      if (!ok) return false;
    }
    try {
      final payload = <String, dynamic>{
        'cmd': cmd,
        if (args != null) ...args,
      };
      _process!.stdin.writeln(jsonEncode(payload));
      await _process!.stdin.flush();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setHotkey(String combo) async {
    _activeHotkeyCombo = combo;
    if (!isRunning && !(await ensureStarted())) return false;
    return sendCommand('hotkey', {'combo': combo});
  }

  Future<bool> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    if (!isRunning && !(await ensureStarted())) return false;
    return sendCommand('notifications', {'enabled': enabled});
  }

  Future<bool> setActiveWindowEnabled(bool enabled) async {
    _activeWindowEnabled = enabled;
    if (!isRunning && !(await ensureStarted())) return false;
    return sendCommand('active_window_watch', {'enabled': enabled});
  }

  Future<bool> configureTray({
    required bool enabled,
    String? status,
    String? iconPath,
  }) async {
    _trayEnabled = enabled;
    if (status != null) _trayStatus = status;
    if (iconPath != null) _trayIconPath = iconPath;
    if (!isRunning && !(await ensureStarted())) return false;
    return sendCommand('tray', {
      'enabled': _trayEnabled,
      'status': _trayStatus,
      if (_trayIconPath != null) 'icon': _trayIconPath,
    });
  }

  Future<void> _reapplySubscriptions() async {
    if (!isRunning) return;
    if (_activeHotkeyCombo != null && _activeHotkeyCombo!.isNotEmpty) {
      await sendCommand('hotkey', {'combo': _activeHotkeyCombo!});
    }
    if (_notificationsEnabled) {
      await sendCommand('notifications', {'enabled': true});
    }
    if (_activeWindowEnabled) {
      await sendCommand('active_window_watch', {'enabled': true});
    }
    if (_trayEnabled) {
      await sendCommand('tray', {
        'enabled': true,
        'status': _trayStatus,
        if (_trayIconPath != null) 'icon': _trayIconPath,
      });
    }
  }

  /// Processa uma linha NDJSON recebida do daemon (exposto para testes).
  void handleRawLine(String line) => _handleLine(line);

  void _handleLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return;

    Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return;
      msg = decoded.cast<String, dynamic>();
    } catch (_) {
      return;
    }

    final ev = msg['event']?.toString();
    final idVal = msg['id'];
    if (ev == null && idVal is num) {
      final id = idVal.toInt();
      final completer = _pending.remove(id);
      if (completer != null && !completer.isCompleted) {
        completer.complete(msg);
      }
      return;
    }

    switch (ev) {
      case 'ready':
        _isReady = true;
        if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
          _readyCompleter!.complete(true);
        }
        _readyCompleter = null;
      case 'active_window':
        if (!_activeWindowCtl.isClosed) _activeWindowCtl.add(msg);
      case 'audio':
        if (!_audioCtl.isClosed) _audioCtl.add(msg);
      case 'media':
        if (!_mediaCtl.isClosed) _mediaCtl.add(msg);
      case 'hotkey':
        if (!_hotkeyCtl.isClosed) _hotkeyCtl.add(msg);
      case 'notification':
        if (!_notificationCtl.isClosed) _notificationCtl.add(msg);
      case 'tray':
        if (!_trayCtl.isClosed) _trayCtl.add(msg);
    }
  }

  void _onProcessExited(int code) {
    final wasReady = _isReady;
    _isReady = false;
    _process = null;

    if (_readyCompleter != null && !_readyCompleter!.isCompleted) {
      if (!wasReady && code != 0) {
        _daemonSupported = false;
      }
      _readyCompleter!.complete(false);
    }
    _readyCompleter = null;

    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _pending.clear();

    if (!_disposed && _started && _daemonSupported && wasReady) {
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    const delays = [1, 2, 5, 15];
    final sec = delays[_restartAttempt.clamp(0, delays.length - 1)];
    _restartAttempt++;
    _restartTimer = Timer(Duration(seconds: sec), () {
      if (!_disposed && _started && _daemonSupported) {
        unawaited(ensureStarted());
      }
    });
  }

  Future<void> _stopProcessOnly() async {
    _isReady = false;
    final proc = _process;
    _process = null;
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    await _stderrSub?.cancel();
    _stderrSub = null;
    if (proc != null) {
      try {
        proc.stdin.writeln('{"cmd":"quit"}');
        await proc.stdin.flush();
      } catch (_) {}
      try {
        proc.kill();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _started = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _pending.clear();
    await _stopProcessOnly();
    await _activeWindowCtl.close();
    await _audioCtl.close();
    await _mediaCtl.close();
    await _hotkeyCtl.close();
    await _notificationCtl.close();
    await _trayCtl.close();
  }
}
