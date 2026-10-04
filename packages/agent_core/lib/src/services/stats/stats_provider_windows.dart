import 'dart:async';
import 'dart:io';

import 'stats_provider.dart';
import 'stats_service.dart';

/// Provider de stats do Windows via PowerShell.
///
/// wmic foi removido do Windows 11 e não é confiável. PowerShell está
/// sempre presente. Cada consulta roda um powershell.exe separado; com
/// polling de 3s, o custo é aceitável.
class WindowsStatsProvider implements StatsProvider {

  @override
  Future<bool> probe() async {
    try {
      final r = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', 'Write-Output 1'],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<StatsSnapshot> read() async {
    final results = await Future.wait([
      _readCpuLoad(),
      _readRam(),
      _readDisk(),
    ]);

    final cpuLoad = results[0] as int;
    final ram = results[1] as (int, int);
    final disk = results[2] as (String, int, int);

    return StatsSnapshot(
      cpuLoad: cpuLoad,
      cpuTemp: null,
      cpuFreqMhz: null,
      ramUsedMb: ram.$1,
      ramTotalMb: ram.$2,
      ramPercent: ram.$2 == 0 ? 0 : (ram.$1 * 100 ~/ ram.$2),
      diskMount: disk.$1,
      diskUsedGb: disk.$2,
      diskTotalGb: disk.$3,
      diskPercent: disk.$3 == 0 ? 0 : (disk.$2 * 100 ~/ disk.$3),
    );
  }

  Future<int> _readCpuLoad() async {
    try {
      final r = await Process.run(
        'powershell',
        ['-NoProfile', '-Command',
         r'(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average'],
        runInShell: false,
      ).timeout(const Duration(seconds: 4));

      if (r.exitCode == 0) {
        final raw = (r.stdout as String).trim().replaceAll('\r', '');
        final v = double.tryParse(raw);
        if (v != null) return v.round().clamp(0, 100);
      }
    } catch (_) {}
    return 0;
  }

  /// Retorna (usedMb, totalMb).
  Future<(int, int)> _readRam() async {
    try {
      final r = await Process.run(
        'powershell',
        ['-NoProfile', '-Command',
         r'$os = Get-CimInstance Win32_OperatingSystem; '
         r'Write-Output "$($os.FreePhysicalMemory),$($os.TotalVisibleMemorySize)"'],
        runInShell: false,
      ).timeout(const Duration(seconds: 4));

      if (r.exitCode == 0) {
        final out = (r.stdout as String).trim().replaceAll('\r', '');
        final parts = out.split(',');
        if (parts.length >= 2) {
          final freeKb = int.tryParse(parts[0].trim()) ?? 0;
          final totalKb = int.tryParse(parts[1].trim()) ?? 0;
          final usedKb = totalKb - freeKb;
          if (usedKb < 0) return (0, totalKb ~/ 1024);
          return (usedKb ~/ 1024, totalKb ~/ 1024);
        }
      }
    } catch (_) {}
    return (0, 0);
  }

  /// Retorna (mount, usedGb, totalGb).
  Future<(String, int, int)> _readDisk() async {
    final drive = Platform.environment['SystemDrive'] ?? 'C:';
    try {
      final psCommand =
          r'$d = Get-CimInstance Win32_LogicalDisk -Filter '
          r'"DeviceID=' + "'" + drive + "'" + r'"; '
          r'Write-Output "$($d.Size),$($d.FreeSpace)"';

      final r = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', psCommand],
        runInShell: false,
      ).timeout(const Duration(seconds: 4));

      if (r.exitCode == 0) {
        final out = (r.stdout as String).trim().replaceAll('\r', '');
        final parts = out.split(',');
        if (parts.length >= 2) {
          final sizeB = int.tryParse(parts[0].trim()) ?? 0;
          final freeB = int.tryParse(parts[1].trim()) ?? 0;
          final usedB = sizeB - freeB;
          const gb = 1024 * 1024 * 1024;
          return (drive, usedB ~/ gb, sizeB ~/ gb);
        }
      }
    } catch (_) {}
    return (drive, 0, 0);
  }
}