import 'dart:async';
import 'dart:io';

import 'package:agent_core/src/services/stats/stats_service.dart';

import 'stats_provider.dart';

class LinuxStatsProvider implements StatsProvider {
  int? _lastIdle;
  int? _lastTotal;
  int? _lastRxBytes;
  int? _lastTxBytes;
  DateTime? _lastNetAt;
  String? _diskMount;

  @override
  Future<bool> probe() async {
    try {
      await File('/proc/stat').readAsString();
      return true;
    } catch (_) {
      return false;
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
        final parts = line.substring(idx + 1).trim().split(RegExp(r'\s+'));
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
    for (int i = 0; i < 5; i++) {
      try {
        final f = File('/sys/class/thermal/thermal_zone$i/temp');
        if (await f.exists()) {
          final txt = (await f.readAsString()).trim();
          return int.parse(txt) ~/ 1000;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<int?> _readCpuFreq() async {
    try {
      final cpuinfo = await File('/proc/cpuinfo').readAsString();
      final m = RegExp(r'cpu MHz\s*:\s*([\d.]+)').firstMatch(cpuinfo);
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
      final totalM = RegExp(r'MemTotal:\s+(\d+)').firstMatch(meminfo);
      final availM = RegExp(r'MemAvailable:\s+(\d+)').firstMatch(meminfo);
      if (totalM != null) {
        final totalKb = int.parse(totalM.group(1)!);
        final availKb = availM != null ? int.parse(availM.group(1)!) : 0;
        final usedKb = totalKb - availKb;
        return ((usedKb < 0 ? 0 : usedKb) ~/ 1024, totalKb ~/ 1024);
      }
    } catch (_) {}
    return (0, 0);
  }

  /// Retorna (mount, usedGb, totalGb) a partir de uma única execução de `df -B1 /`.
  Future<(String, int, int)> _readDisk() async {
    try {
      final r = await Process.run('df', ['-B1', '/']);
      if (r.exitCode == 0) {
        final lines = (r.stdout as String).trim().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length > 3) {
            final totalB = int.parse(parts[1]);
            final usedB = int.parse(parts[2]);
            final mount = parts.length > 5 ? parts[5] : '/';
            _diskMount = mount;
            const gb = 1024 * 1024 * 1024;
            return (mount, usedB ~/ gb, totalB ~/ gb);
          }
        }
      }
    } catch (_) {}
    return (_diskMount ?? '/', 0, 0);
  }
}
