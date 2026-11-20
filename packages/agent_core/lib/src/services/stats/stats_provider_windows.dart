import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../util/windows_binaries.dart';
import '../../util/windows_helper_bridge.dart';
import 'stats_provider.dart';
import 'stats_service.dart';

/// Provider de stats do Windows.
///
/// Usa `hub_audio_helper.exe daemon` (via [WindowsHelperBridge], stateful e sem
/// `Sleep(120)` ou spawn por tick) como fonte primária, com fallback automático
/// para CLI `hub_audio_helper.exe stats` e PowerShell CIM.
class WindowsStatsProvider implements StatsProvider {
  String? _helperPath;

  static StatsSnapshot? parseHelperMap(Map<String, dynamic> data) {
    final cpuLoad = ((data['cpu_load'] as num?)?.round() ?? 0).clamp(0, 100);
    final ramUsedMb = (data['ram_used_mb'] as num?)?.round() ?? 0;
    final ramTotalMb = (data['ram_total_mb'] as num?)?.round() ?? 0;
    final ramPercent = ((data['ram_percent'] as num?)?.round() ??
            (ramTotalMb == 0 ? 0 : (ramUsedMb * 100 ~/ ramTotalMb)))
        .clamp(0, 100);
    final diskMount = (data['disk_mount'] as String?) ?? 'C:';
    final diskUsedGb = (data['disk_used_gb'] as num?)?.round() ?? 0;
    final diskTotalGb = (data['disk_total_gb'] as num?)?.round() ?? 0;
    final diskPercent = ((data['disk_percent'] as num?)?.round() ??
            (diskTotalGb == 0 ? 0 : (diskUsedGb * 100 ~/ diskTotalGb)))
        .clamp(0, 100);
    final netRxKbps = (data['net_rx_kbps'] as num?)?.round();
    final netTxKbps = (data['net_tx_kbps'] as num?)?.round();

    return StatsSnapshot(
      cpuLoad: cpuLoad,
      cpuTemp: null,
      cpuFreqMhz: null,
      ramUsedMb: ramUsedMb,
      ramTotalMb: ramTotalMb,
      ramPercent: ramPercent,
      diskMount: diskMount,
      diskUsedGb: diskUsedGb,
      diskTotalGb: diskTotalGb,
      diskPercent: diskPercent,
      netRxKbps: netRxKbps,
      netTxKbps: netTxKbps,
    );
  }

  static StatsSnapshot? parseHelperJson(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      return parseHelperMap(data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> probe() async {
    if (await WindowsHelperBridge.instance.ensureStarted()) {
      final res = await WindowsHelperBridge.instance.request('stats');
      final data = res?['data'];
      if (data is Map && parseHelperMap(data.cast<String, dynamic>()) != null) {
        return true;
      }
    }

    _helperPath = WindowsBinaries.resolveHelperPath();
    if (_helperPath != null) {
      try {
        final r = await Process.run(
          _helperPath!,
          ['stats'],
          runInShell: false,
        ).timeout(const Duration(seconds: 3));
        if (r.exitCode == 0 && parseHelperJson((r.stdout as String).trim()) != null) {
          return true;
        }
      } catch (_) {}
    }

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
    if (WindowsHelperBridge.instance.isRunning) {
      final res = await WindowsHelperBridge.instance.request('stats');
      final data = res?['data'];
      if (data is Map) {
        final parsed = parseHelperMap(data.cast<String, dynamic>());
        if (parsed != null) return parsed;
      }
    }

    _helperPath ??= WindowsBinaries.resolveHelperPath();
    if (_helperPath != null) {
      try {
        final r = await Process.run(
          _helperPath!,
          ['stats'],
          runInShell: false,
        ).timeout(const Duration(seconds: 3));
        if (r.exitCode == 0) {
          final parsed = parseHelperJson((r.stdout as String).trim());
          if (parsed != null) return parsed;
        }
      } catch (_) {}
    }

    final drive = Platform.environment['SystemDrive'] ?? 'C:';
    final script =
        r'$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average; '
        r'$os = Get-CimInstance Win32_OperatingSystem; '
        // ignore: prefer_adjacent_string_concatenation, prefer_interpolation_to_compose_strings
        r'$d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID=' + "'" + drive + "'" + r'"; '
        r'Write-Output "$cpu|$($os.FreePhysicalMemory),$($os.TotalVisibleMemorySize)|$($d.Size),$($d.FreeSpace)"';

    try {
      final r = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', script],
        runInShell: false,
      ).timeout(const Duration(seconds: 4));

      if (r.exitCode == 0) {
        final out = (r.stdout as String).trim().replaceAll('\r', '');
        final sections = out.split('|');
        if (sections.length >= 3) {
          // 1. CPU
          final cpuVal = double.tryParse(sections[0].trim());
          final cpuLoad = cpuVal != null ? cpuVal.round().clamp(0, 100) : 0;

          // 2. RAM
          var ramUsedMb = 0;
          var ramTotalMb = 0;
          final ramParts = sections[1].split(',');
          if (ramParts.length >= 2) {
            final freeKb = int.tryParse(ramParts[0].trim()) ?? 0;
            final totalKb = int.tryParse(ramParts[1].trim()) ?? 0;
            final usedKb = totalKb - freeKb;
            ramTotalMb = totalKb ~/ 1024;
            ramUsedMb = (usedKb < 0 ? 0 : usedKb) ~/ 1024;
          }

          // 3. Disk
          var diskUsedGb = 0;
          var diskTotalGb = 0;
          final diskParts = sections[2].split(',');
          if (diskParts.length >= 2) {
            final sizeB = int.tryParse(diskParts[0].trim()) ?? 0;
            final freeB = int.tryParse(diskParts[1].trim()) ?? 0;
            final usedB = sizeB - freeB;
            const gb = 1024 * 1024 * 1024;
            diskTotalGb = sizeB ~/ gb;
            diskUsedGb = (usedB < 0 ? 0 : usedB) ~/ gb;
          }

          return StatsSnapshot(
            cpuLoad: cpuLoad,
            cpuTemp: null,
            cpuFreqMhz: null,
            ramUsedMb: ramUsedMb,
            ramTotalMb: ramTotalMb,
            ramPercent: ramTotalMb == 0 ? 0 : (ramUsedMb * 100 ~/ ramTotalMb),
            diskMount: drive,
            diskUsedGb: diskUsedGb,
            diskTotalGb: diskTotalGb,
            diskPercent: diskTotalGb == 0 ? 0 : (diskUsedGb * 100 ~/ diskTotalGb),
          );
        }
      }
    } catch (_) {}

    return StatsSnapshot(
      cpuLoad: 0,
      cpuTemp: null,
      cpuFreqMhz: null,
      ramUsedMb: 0,
      ramTotalMb: 0,
      ramPercent: 0,
      diskMount: drive,
      diskUsedGb: 0,
      diskTotalGb: 0,
      diskPercent: 0,
    );
  }
}