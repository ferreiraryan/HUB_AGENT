import 'dart:async';
import 'dart:io';

import 'package:agent_core/src/services/stats/stats_service.dart';

import 'stats_provider.dart';

class LinuxStatsProvider implements StatsProvider {
  int? _lastIdle;
  int? _lastTotal;
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
    return StatsSnapshot(
      cpuLoad: await _readCpuLoad(),
      cpuTemp: await _readCpuTemp(),
      cpuFreqMhz: await _readCpuFreq(),
      ramUsedMb: await _readRamUsed(),
      ramTotalMb: await _readRamTotal(),
      ramPercent: await _readRamPercent(),
      diskMount: _diskMount ?? '/',
      diskUsedGb: await _readDiskUsed(),
      diskTotalGb: await _readDiskTotal(),
      diskPercent: await _readDiskPercent(),
    );
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

  Future<int> _readRamTotal() async {
    try {
      final meminfo = await File('/proc/meminfo').readAsString();
      final totalM = RegExp(r'MemTotal:\s+(\d+)').firstMatch(meminfo);
      if (totalM != null) {
        return int.parse(totalM.group(1)!) ~/ 1024;
      }
    } catch (_) {}
    return 0;
  }

  Future<int> _readRamUsed() async {
    try {
      final meminfo = await File('/proc/meminfo').readAsString();
      final totalM = RegExp(r'MemTotal:\s+(\d+)').firstMatch(meminfo);
      final availM = RegExp(r'MemAvailable:\s+(\d+)').firstMatch(meminfo);
      if (totalM != null && availM != null) {
        final totalKb = int.parse(totalM.group(1)!);
        final availKb = int.parse(availM.group(1)!);
        return (totalKb - availKb) ~/ 1024;
      }
    } catch (_) {}
    return 0;
  }

  Future<int> _readRamPercent() async {
    final total = await _readRamTotal();
    if (total == 0) return 0;
    final used = await _readRamUsed();
    return (used * 100 ~/ total).clamp(0, 100);
  }

  Future<int> _readDiskTotal() async {
    try {
      final r = await Process.run('df', ['-B1', '/']);
      if (r.exitCode == 0) {
        final lines = (r.stdout as String).trim().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length > 3) {
            _diskMount = parts[5];
            return int.parse(parts[1]) ~/ (1024 * 1024 * 1024);
          }
        }
      }
    } catch (_) {}
    return 0;
  }

  Future<int> _readDiskUsed() async {
    try {
      final r = await Process.run('df', ['-B1', '/']);
      if (r.exitCode == 0) {
        final lines = (r.stdout as String).trim().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length > 3) {
            return int.parse(parts[2]) ~/ (1024 * 1024 * 1024);
          }
        }
      }
    } catch (_) {}
    return 0;
  }

  Future<int> _readDiskPercent() async {
    try {
      final r = await Process.run('df', ['-B1', '/']);
      if (r.exitCode == 0) {
        final lines = (r.stdout as String).trim().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length > 3) {
            final total = int.parse(parts[1]);
            final used = int.parse(parts[2]);
            if (total == 0) return 0;
            return (used * 100 ~/ total).clamp(0, 100);
          }
        }
      }
    } catch (_) {}
    return 0;
  }
}
