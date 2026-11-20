import 'dart:async';
import 'dart:io';

import 'package:agent_core/src/services/stats/stats_service.dart';

import 'stats_provider.dart';

class LinuxStatsProvider implements StatsProvider {
  static final _wsRegex = RegExp(r'\s+');
  static final _cpuFreqRegex = RegExp(r'cpu MHz\s*:\s*([\d.]+)');
  static final _memTotalRegex = RegExp(r'MemTotal:\s+(\d+)');
  static final _memAvailRegex = RegExp(r'MemAvailable:\s+(\d+)');

  final Duration diskCacheTtl;

  int? _lastIdle;
  int? _lastTotal;
  int? _lastRxBytes;
  int? _lastTxBytes;
  DateTime? _lastNetAt;
  String? _diskMount;
  (String, int, int)? _cachedDisk;
  DateTime? _lastDiskAt;

  File? _thermalFile;
  bool _thermalProbed = false;
  bool _sysFreqAvailable = true;

  LinuxStatsProvider({
    this.diskCacheTtl = const Duration(seconds: 60),
  });

  @override
  Future<bool> probe() async {
    try {
      await File('/proc/stat').readAsString();
      await _discoverThermalZone();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _discoverThermalZone() async {
    if (_thermalProbed) return;
    _thermalProbed = true;
    for (int i = 0; i < 5; i++) {
      try {
        final f = File('/sys/class/thermal/thermal_zone$i/temp');
        if (await f.exists()) {
          _thermalFile = f;
          return;
        }
      } catch (_) {}
    }
  }

  @override
  Future<StatsSnapshot> read() async {
    final cpuLoadFuture = _readCpuLoad();
    final cpuTempFuture = _readCpuTemp();
    final cpuFreqFuture = _readCpuFreq();
    final ramFuture = _readRam();
    final diskFuture = _readDisk();
    final netFuture = _readNet();

    final cpuLoad = await cpuLoadFuture;
    final cpuTemp = await cpuTempFuture;
    final cpuFreq = await cpuFreqFuture;
    final ram = await ramFuture;
    final disk = await diskFuture;
    final net = await netFuture;

    return StatsSnapshot(
      cpuLoad: cpuLoad,
      cpuTemp: cpuTemp,
      cpuFreqMhz: cpuFreq,
      ramUsedMb: ram.$1,
      ramTotalMb: ram.$2,
      ramPercent: ram.$2 == 0 ? 0 : (ram.$1 * 100 ~/ ram.$2).clamp(0, 100),
      diskMount: disk.$1,
      diskUsedGb: disk.$2,
      diskTotalGb: disk.$3,
      diskPercent: disk.$3 == 0 ? 0 : (disk.$2 * 100 ~/ disk.$3).clamp(0, 100),
      netRxKbps: net.$1,
      netTxKbps: net.$2,
    );
  }

  Future<(int, int)> _readNet() async {
    try {
      final raw = await File('/proc/net/dev').readAsString();
      var rx = 0;
      var tx = 0;
      for (final line in raw.split('\n').skip(2)) {
        final idx = line.indexOf(':');
        if (idx < 0) continue;
        final iface = line.substring(0, idx).trim();
        if (iface == 'lo' || iface.isEmpty) continue;
        final parts = line.substring(idx + 1).trim().split(_wsRegex);
        if (parts.length >= 9) {
          rx += int.tryParse(parts[0]) ?? 0;
          tx += int.tryParse(parts[8]) ?? 0;
        }
      }
      final now = DateTime.now();
      if (_lastRxBytes == null || _lastTxBytes == null || _lastNetAt == null) {
        _lastRxBytes = rx;
        _lastTxBytes = tx;
        _lastNetAt = now;
        return (0, 0);
      }
      final elapsedSec = now.difference(_lastNetAt!).inMilliseconds / 1000.0;
      final rxDiff = rx - _lastRxBytes!;
      final txDiff = tx - _lastTxBytes!;
      _lastRxBytes = rx;
      _lastTxBytes = tx;
      _lastNetAt = now;
      if (elapsedSec <= 0.05) return (0, 0);
      final rxKbps = rxDiff > 0 ? ((rxDiff / 1024.0) / elapsedSec).round() : 0;
      final txKbps = txDiff > 0 ? ((txDiff / 1024.0) / elapsedSec).round() : 0;
      return (rxKbps, txKbps);
    } catch (_) {
      return (0, 0);
    }
  }

  Future<int> _readCpuLoad() async {
    try {
      final stat = await File('/proc/stat').readAsString();
      final lines = stat.split('\n');
      final cpuLine = lines.firstWhere((l) => l.startsWith('cpu '));
      final parts = cpuLine
          .split(' ')
          .where((s) => s.isNotEmpty)
          .skip(1)
          .map(int.parse)
          .toList();

      final user = parts[0];
      final nice = parts[1];
      final system = parts[2];
      final idle = parts[3];
      final iowait = parts[4];
      final irq = parts[5];
      final softirq = parts[6];
      final steal = parts[7];

      final currentIdle = idle + iowait;
      final currentTotal =
          user + nice + system + currentIdle + irq + softirq + steal;

      if (_lastIdle == null || _lastTotal == null) {
        _lastIdle = currentIdle;
        _lastTotal = currentTotal;
        return 0;
      }

      final diffIdle = currentIdle - _lastIdle!;
      final diffTotal = currentTotal - _lastTotal!;

      _lastIdle = currentIdle;
      _lastTotal = currentTotal;

      if (diffTotal == 0) return 0;
      return ((diffTotal - diffIdle) * 100 ~/ diffTotal).clamp(0, 100);
    } catch (_) {
      return 0;
    }
  }

  Future<int?> _readCpuTemp() async {
    if (!_thermalProbed) await _discoverThermalZone();
    final f = _thermalFile;
    if (f == null) return null;
    try {
      final txt = (await f.readAsString()).trim();
      return int.parse(txt) ~/ 1000;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _readCpuFreq() async {
    if (_sysFreqAvailable) {
      try {
        const sysFreqPath =
            '/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq';
        final f = File(sysFreqPath);
        if (await f.exists()) {
          final khz = int.tryParse((await f.readAsString()).trim());
          if (khz != null && khz > 0) return khz ~/ 1000;
        } else {
          _sysFreqAvailable = false;
        }
      } catch (_) {
        _sysFreqAvailable = false;
      }
    }
    try {
      final cpuinfo = await File('/proc/cpuinfo').readAsString();
      final m = _cpuFreqRegex.firstMatch(cpuinfo);
      if (m != null) {
        return double.parse(m.group(1)!).round();
      }
    } catch (_) {}
    return null;
  }

  /// Retorna (usedMb, totalMb) a partir de uma única leitura de /proc/meminfo.
  Future<(int, int)> _readRam() async {
    try {
      final meminfo = await File('/proc/meminfo').readAsString();
      final totalM = _memTotalRegex.firstMatch(meminfo);
      final availM = _memAvailRegex.firstMatch(meminfo);
      if (totalM != null) {
        final totalKb = int.parse(totalM.group(1)!);
        final availKb = availM != null ? int.parse(availM.group(1)!) : 0;
        final usedKb = totalKb - availKb;
        return ((usedKb < 0 ? 0 : usedKb) ~/ 1024, totalKb ~/ 1024);
      }
    } catch (_) {}
    return (0, 0);
  }

  /// Retorna (mount, usedGb, totalGb) com cache de [diskCacheTtl] (evita spawn de `df` a cada 3s).
  Future<(String, int, int)> _readDisk() async {
    final now = DateTime.now();
    if (_cachedDisk != null &&
        _lastDiskAt != null &&
        now.difference(_lastDiskAt!) < diskCacheTtl) {
      return _cachedDisk!;
    }
    try {
      final r = await Process.run('df', ['-B1', '/']);
      if (r.exitCode == 0) {
        final lines = (r.stdout as String).trim().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(_wsRegex);
          if (parts.length > 3) {
            final totalB = int.parse(parts[1]);
            final usedB = int.parse(parts[2]);
            final mount = parts.length > 5 ? parts[5] : '/';
            _diskMount = mount;
            const gb = 1024 * 1024 * 1024;
            final result = (mount, usedB ~/ gb, totalB ~/ gb);
            _cachedDisk = result;
            _lastDiskAt = now;
            return result;
          }
        }
      }
    } catch (_) {}
    return _cachedDisk ?? (_diskMount ?? '/', 0, 0);
  }
}
