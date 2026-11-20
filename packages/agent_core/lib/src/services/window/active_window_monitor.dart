import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import '../../util/windows_binaries.dart';

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
  String? _helperPath;
  ActiveWindowInfo _current = ActiveWindowInfo.empty;

  ActiveWindowMonitor({
    this.interval = const Duration(milliseconds: 1200),
  });

  Stream<ActiveWindowInfo> get changes => _ctl.stream;
  ActiveWindowInfo get current => _current;

  Future<void> start() async {
    if (Platform.isWindows) {
      _helperPath = WindowsBinaries.resolveHelperPath();
    }
    await _poll();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  Future<void> _poll() async {
    final next = await readActiveWindow();
    if (next.process != _current.process) {
      _current = next;
      if (!_ctl.isClosed) _ctl.add(next);
    }
  }

  Future<ActiveWindowInfo> readActiveWindow() async {
    if (Platform.isWindows) {
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
    _timer?.cancel();
    await _ctl.close();
  }
}
