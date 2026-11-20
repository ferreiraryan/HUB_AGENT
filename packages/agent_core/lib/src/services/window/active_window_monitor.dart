import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import '../../util/windows_binaries.dart';
import '../../util/windows_helper_bridge.dart';

@immutable
class ActiveWindowInfo {
  final String process;
  final String title;

  const ActiveWindowInfo({
    required this.process,
    required this.title,
  });

  static const empty = ActiveWindowInfo(process: '', title: '');

  Map<String, dynamic> toJson() => {
        'process': process,
        'title': title,
      };

  @override
  bool operator ==(Object other) =>
      other is ActiveWindowInfo &&
      other.process == process &&
      other.title == title;

  @override
  int get hashCode => Object.hash(process, title);
}

class ActiveWindowMonitor {
  final Duration interval;
  final _ctl = StreamController<ActiveWindowInfo>.broadcast();
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _bridgeSub;
  Socket? _hyprSocket;
  StreamSubscription<String>? _hyprSub;
  Process? _xpropProc;
  StreamSubscription<String>? _xpropSub;
  String? _helperPath;
  ActiveWindowInfo _current = ActiveWindowInfo.empty;
  bool _started = false;
  bool _enabled = true;
  bool _disposed = false;

  ActiveWindowMonitor({
    this.interval = const Duration(milliseconds: 2000),
  });

  Stream<ActiveWindowInfo> get changes => _ctl.stream;
  ActiveWindowInfo get current => _current;
  bool get isEnabled => _enabled;

  Future<void> start({bool enabled = true}) async {
    _started = true;
    _enabled = enabled;
    if (Platform.isWindows) {
      _helperPath = WindowsBinaries.resolveHelperPath();
    }
    if (_enabled) {
      await _startMonitoring();
    }
  }

  /// Liga/desliga o monitoramento dinamicamente (ex: só monitora quando há `page_rules`).
  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (!_started) return;
    if (_enabled) {
      await _startMonitoring();
    } else {
      await _stopMonitoring();
    }
  }

  void _emitIfChanged(ActiveWindowInfo next) {
    if (next.process != _current.process) {
      _current = next;
      if (!_ctl.isClosed) _ctl.add(next);
    }
  }

  Future<void> _startMonitoring() async {
    if (_disposed) return;

    if (Platform.isWindows) {
      if (await WindowsHelperBridge.instance.ensureStarted()) {
        await WindowsHelperBridge.instance.setActiveWindowEnabled(true);
        _bridgeSub ??= WindowsHelperBridge.instance.activeWindowEvents.listen((map) {
          final info = ActiveWindowInfo(
            process: (map['process']?.toString() ?? '').toLowerCase().trim(),
            title: map['title']?.toString() ?? '',
          );
          _emitIfChanged(info);
        });
        await _poll();
        return;
      }
    } else if (Platform.isLinux) {
      if (await _tryStartHyprlandSocket()) {
        await _poll();
        return;
      }
      if (await _tryStartXpropWatch()) {
        await _poll();
        return;
      }
    }

    // Fallback seguro para polling
    await _poll();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  Future<void> _stopMonitoring() async {
    _timer?.cancel();
    _timer = null;
    await _bridgeSub?.cancel();
    _bridgeSub = null;
    if (Platform.isWindows && WindowsHelperBridge.instance.isRunning) {
      unawaited(WindowsHelperBridge.instance.setActiveWindowEnabled(false));
    }
    await _hyprSub?.cancel();
    _hyprSub = null;
    _hyprSocket?.destroy();
    _hyprSocket = null;
    await _xpropSub?.cancel();
    _xpropSub = null;
    try {
      _xpropProc?.kill();
    } catch (_) {}
    _xpropProc = null;
  }

  /// Conecta diretamente ao socket de eventos do Hyprland (`activewindow>>class,title`).
  Future<bool> _tryStartHyprlandSocket() async {
    final sig = Platform.environment['HYPRLAND_INSTANCE_SIGNATURE'];
    final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];
    if (sig == null || sig.isEmpty || runtimeDir == null || runtimeDir.isEmpty) {
      return false;
    }
    final candidates = [
      '$runtimeDir/hypr/$sig/.socket2.sock',
      '/tmp/hypr/$sig/.socket2.sock',
    ];
    for (final sockPath in candidates) {
      if (!File(sockPath).existsSync() &&
          FileSystemEntity.typeSync(sockPath) == FileSystemEntityType.notFound) {
        continue;
      }
      try {
        final socket = await Socket.connect(
          InternetAddress(sockPath, type: InternetAddressType.unix),
          0,
        );
        _hyprSocket = socket;
        _hyprSub = utf8.decoder
            .bind(socket)
            .transform(const LineSplitter())
            .listen(
          (line) {
            if (!line.startsWith('activewindow>>')) return;
            final payload = line.substring('activewindow>>'.length);
            final comma = payload.indexOf(',');
            final cls = (comma >= 0 ? payload.substring(0, comma) : payload)
                .trim()
                .toLowerCase();
            final title = comma >= 0 ? payload.substring(comma + 1) : '';
            _emitIfChanged(ActiveWindowInfo(process: cls, title: title));
          },
          onDone: () {
            _hyprSocket = null;
            if (!_disposed && _enabled && _timer == null) {
              _timer = Timer.periodic(interval, (_) => _poll());
            }
          },
          onError: (_) {},
        );
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// No X11, usa `xprop -spy -root _NET_ACTIVE_WINDOW` orientado a eventos (0 polling).
  Future<bool> _tryStartXpropWatch() async {
    final display = Platform.environment['DISPLAY'];
    if (display == null || display.isEmpty) return false;
    try {
      final which = await Process.run('which', ['xprop']);
      if (which.exitCode != 0) return false;
      final proc = await Process.start(
        'xprop',
        ['-spy', '-root', '_NET_ACTIVE_WINDOW'],
        runInShell: false,
      );
      _xpropProc = proc;
      proc.stderr.drain<void>();
      _xpropSub = proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((_) {
        if (_enabled && !_disposed) unawaited(_poll());
      });
      proc.exitCode.then((_) {
        if (_xpropProc == proc) {
          _xpropProc = null;
          if (!_disposed && _enabled && _timer == null) {
            _timer = Timer.periodic(interval, (_) => _poll());
          }
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _poll() async {
    final next = await readActiveWindow();
    _emitIfChanged(next);
  }

  Future<ActiveWindowInfo> readActiveWindow() async {
    if (Platform.isWindows) {
      if (WindowsHelperBridge.instance.isRunning) {
        final res = await WindowsHelperBridge.instance.request('active_window');
        final map = res?['data'];
        if (map is Map) {
          return ActiveWindowInfo(
            process: (map['process']?.toString() ?? '').toLowerCase().trim(),
            title: map['title']?.toString() ?? '',
          );
        }
      }

      _helperPath ??= WindowsBinaries.resolveHelperPath();
      if (_helperPath == null) return ActiveWindowInfo.empty;
      try {
        final r = await Process.run(
          _helperPath!,
          ['active-window'],
          runInShell: false,
        ).timeout(const Duration(seconds: 2));
        if (r.exitCode == 0) {
          final map = jsonDecode((r.stdout as String).trim());
          if (map is Map) {
            return ActiveWindowInfo(
              process: (map['process']?.toString() ?? '').toLowerCase().trim(),
              title: map['title']?.toString() ?? '',
            );
          }
        }
      } catch (_) {}
      return ActiveWindowInfo.empty;
    }

    if (Platform.isLinux) {
      // Hyprland (Wayland)
      if ((Platform.environment['HYPRLAND_INSTANCE_SIGNATURE'] ?? '').isNotEmpty) {
        try {
          final r = await Process.run('hyprctl', ['activewindow', '-j'],
                  runInShell: false)
              .timeout(const Duration(seconds: 2));
          if (r.exitCode == 0) {
            final map = jsonDecode((r.stdout as String).trim());
            if (map is Map) {
              final cls = (map['class']?.toString() ?? '').toLowerCase().trim();
              final title = map['title']?.toString() ?? '';
              return ActiveWindowInfo(process: cls, title: title);
            }
          }
        } catch (_) {}
      }

      // Fallback X11 via xdotool
      try {
        final pidR = await Process.run(
          'xdotool',
          ['getactivewindow', 'getwindowpid'],
          runInShell: false,
        ).timeout(const Duration(seconds: 2));
        if (pidR.exitCode == 0) {
          final pid = (pidR.stdout as String).trim();
          final commFile = File('/proc/$pid/comm');
          if (await commFile.exists()) {
            final comm = (await commFile.readAsString()).trim().toLowerCase();
            return ActiveWindowInfo(process: comm, title: comm);
          }
        }
      } catch (_) {}
    }

    return ActiveWindowInfo.empty;
  }

  /// Alterna o estado "Sempre no Topo" (Always on Top) da janela atualmente em foco.
  /// Retorna `(pinned, title)` ou `null` se não suportado.
  Future<(bool pinned, String title)?> toggleTopmost() async {
    if (Platform.isWindows) {
      if (WindowsHelperBridge.instance.isRunning) {
        final res = await WindowsHelperBridge.instance.request('toggle_topmost');
        final map = res?['data'];
        if (map is Map) {
          return (
            map['pinned'] == true,
            map['title']?.toString() ?? 'Janela atual',
          );
        }
      }

      _helperPath ??= WindowsBinaries.resolveHelperPath();
      if (_helperPath == null) return null;
      try {
        final r = await Process.run(
          _helperPath!,
          ['toggle-topmost'],
          runInShell: false,
        ).timeout(const Duration(seconds: 2));
        if (r.exitCode == 0) {
          final map = jsonDecode((r.stdout as String).trim());
          if (map is Map) {
            return (
              map['pinned'] == true,
              map['title']?.toString() ?? 'Janela atual',
            );
          }
        }
      } catch (_) {}
      return null;
    }

    if (Platform.isLinux) {
      try {
        final r = await Process.run(
            'hyprctl', ['dispatch', 'pin'], runInShell: false);
        if (r.exitCode == 0) {
          return (true, _current.title.isEmpty ? 'Janela atual' : _current.title);
        }
      } catch (_) {}
      try {
        final r = await Process.run(
          'wmctrl',
          ['-r', ':ACTIVE:', '-b', 'toggle,above'],
          runInShell: false,
        );
        if (r.exitCode == 0) {
          return (true, _current.title.isEmpty ? 'Janela atual' : _current.title);
        }
      } catch (_) {}
    }

    return null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _stopMonitoring();
    await _ctl.close();
  }
}
