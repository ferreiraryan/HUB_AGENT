import 'dart:async';
import 'dart:io';

class DisplayInfo {
  final int number;
  final String bus;
  final String connector;
  final String serial;
  final String model;

  const DisplayInfo({
    required this.number,
    required this.bus,
    required this.connector,
    required this.serial,
    required this.model,
  });
}

abstract interface class BrightnessController {
  Stream<void> get changes;
  bool get isAvailable;
  List<DisplayInfo> get displays;

  Future<void> start();
  Future<void> set(int value);
  Future<void> setForDisplay(String match, int value);
  Future<int?> readForDisplay(String match);
  Future<void> dispose();
}

class UnsupportedBrightnessController implements BrightnessController {
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  bool get isAvailable => false;
  @override
  List<DisplayInfo> get displays => const [];
  @override
  Future<void> start() async {}
  @override
  Future<void> set(int value) async {}
  @override
  Future<void> setForDisplay(String match, int value) async {}
  @override
  Future<int?> readForDisplay(String match) async => null;
  @override
  Future<void> dispose() async {}
}

class LinuxBrightnessController implements BrightnessController {
  final _changes = StreamController<void>.broadcast();
  final List<DisplayInfo> _displays = [];
  bool _available = false;
  Timer? _pollTimer;
  DateTime _suppressUntil = DateTime.fromMillisecondsSinceEpoch(0);
  int? _lastHash;

  @override
  Stream<void> get changes => _changes.stream;
  @override
  bool get isAvailable => _available;
  @override
  List<DisplayInfo> get displays => List.unmodifiable(_displays);

  @override
  Future<void> start() async {
    try {
      final which = await Process.run('which', ['ddcutil']);
      if (which.exitCode != 0) {
        stderr.writeln('brightness: ddcutil não encontrado no PATH.');
        return;
      }

      final detect = await Process.run('ddcutil', ['detect']);
      if (detect.exitCode == 0) {
        final lines = (detect.stdout as String).split('\n');
        int? currentNum;
        String? currentBus, currentConn, currentSerial, currentModel;

        void flush() {
          if (currentNum != null) {
            _displays.add(DisplayInfo(
              number: currentNum!,
              bus: currentBus ?? '',
              connector: currentConn ?? '',
              serial: currentSerial ?? '',
              model: currentModel ?? '',
            ));
          }
        }

        for (final line in lines) {
          if (line.startsWith('Display ')) {
            flush();
            currentNum = null;
            currentBus = null;
            currentConn = null;
            currentSerial = null;
            currentModel = null;
            final match = RegExp(r'Display\s+(\d+)').firstMatch(line);
            if (match != null) currentNum = int.tryParse(match.group(1)!);
          } else {
            if (line.contains('I2C bus:')) {
              currentBus = line.split(':')[1].trim();
            } else if (line.contains('DRM connector:')) {
              currentConn = line.split(':')[1].trim();
            } else if (line.contains('Serial number:')) {
              currentSerial = line.split(':')[1].trim();
            } else if (line.contains('Model:')) {
              currentModel = line.split(':')[1].trim();
            }
          }
        }
        flush();
      }

      if (_displays.isEmpty) {
        stderr.writeln('brightness: Nenhum display detectado pelo ddcutil.');
        return;
      }

      _available = true;
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    } catch (e) {
      stderr.writeln('brightness: Erro ao inicializar - $e');
    }
  }

  Future<void> _poll() async {
    if (!_available || DateTime.now().isBefore(_suppressUntil)) return;

    final buf = StringBuffer();
    for (final d in _displays) {
      final v = await readForDisplay(d.connector);
      buf.write('${d.number}:$v|');
    }

    final hash = buf.toString().hashCode;
    if (_lastHash != null && _lastHash != hash) {
      if (!_changes.isClosed) _changes.add(null);
    }
    _lastHash = hash;
  }

  List<DisplayInfo> _findTargets(String match) {
    if (match.trim().isEmpty) return _displays;
    final l = match.trim().toLowerCase();
    return _displays
        .where((d) =>
            d.connector.toLowerCase().contains(l) ||
            d.serial.toLowerCase().contains(l) ||
            d.connector.toLowerCase() == l ||
            d.serial.toLowerCase() == l)
        .toList();
  }

  @override
  Future<int?> readForDisplay(String match) async {
    if (!_available) return null;
    final targets = _findTargets(match);
    if (targets.isEmpty) return null;

    try {
      final r = await Process.run('ddcutil',
          ['--display', targets.first.number.toString(), 'getvcp', '10']);
      if (r.exitCode != 0) return null;

      final regex = RegExp(r'current value\s*=\s*(\d+)');
      final m = regex.firstMatch(r.stdout as String);
      if (m != null) {
        return int.tryParse(m.group(1)!);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> set(int value) async {
    if (!_available || _displays.isEmpty) return;
    final v = value.clamp(0, 100);

    _suppressUntil = DateTime.now().add(const Duration(milliseconds: 500));
    await Process.run('ddcutil', ['setvcp', '10', v.toString()]);

    Timer(const Duration(milliseconds: 300), _poll);
  }

  @override
  Future<void> setForDisplay(String match, int value) async {
    final m = match.trim();
    if (!_available || _displays.isEmpty) return;
    if (m.isEmpty) {
      await set(value);
      return;
    }

    final v = value.clamp(0, 100);
    final targets = _findTargets(m);

    if (targets.isEmpty) {
      stderr.writeln('brightness: Nenhum display encontrado para o match "$m"');
      return;
    }

    _suppressUntil = DateTime.now().add(const Duration(milliseconds: 500));

    for (final d in targets) {
      await Process.run('ddcutil',
          ['--display', d.number.toString(), 'setvcp', '10', v.toString()]);
    }

    Timer(const Duration(milliseconds: 300), _poll);
  }

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _changes.close();
  }
}
