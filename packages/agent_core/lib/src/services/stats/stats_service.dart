import 'dart:async';
import 'dart:io';

import 'stats_provider.dart';
import 'stats_provider_windows.dart';
import 'stats_provider_linux.dart';

class StatsSnapshot {
  final int cpuLoad;
  final int? cpuTemp;
  final int? cpuFreqMhz;
  final int ramUsedMb;
  final int ramTotalMb;
  final int ramPercent;
  final String diskMount;
  final int diskUsedGb;
  final int diskTotalGb;
  final int diskPercent;
  final int? netRxKbps;
  final int? netTxKbps;
  final int? gpuLoad;
  final int? gpuTemp;

  const StatsSnapshot({
    required this.cpuLoad,
    this.cpuTemp,
    this.cpuFreqMhz,
    required this.ramUsedMb,
    required this.ramTotalMb,
    required this.ramPercent,
    required this.diskMount,
    required this.diskUsedGb,
    required this.diskTotalGb,
    required this.diskPercent,
    this.netRxKbps,
    this.netTxKbps,
    this.gpuLoad,
    this.gpuTemp,
  });

  Map<String, dynamic> cpuJson() => {
        'load': cpuLoad,
        if (cpuTemp != null) 'temp': cpuTemp,
        if (cpuFreqMhz != null) 'freq_mhz': cpuFreqMhz,
      };

  Map<String, dynamic> ramJson() => {
        'used_mb': ramUsedMb,
        'total_mb': ramTotalMb,
        'percent': ramPercent,
      };

  Map<String, dynamic> diskJson() => {
        'mount': diskMount,
        'used_gb': diskUsedGb,
        'total_gb': diskTotalGb,
        'percent': diskPercent,
      };

  Map<String, dynamic> netJson() => {
        'rx_kbps': netRxKbps ?? 0,
        'tx_kbps': netTxKbps ?? 0,
      };

  Map<String, dynamic> gpuJson() => {
        if (gpuLoad != null) 'load': gpuLoad,
        if (gpuTemp != null) 'temp': gpuTemp,
      };

  @override
  bool operator ==(Object other) =>
      other is StatsSnapshot &&
      other.cpuLoad == cpuLoad &&
      other.cpuTemp == cpuTemp &&
      other.cpuFreqMhz == cpuFreqMhz &&
      other.ramUsedMb == ramUsedMb &&
      other.ramTotalMb == ramTotalMb &&
      other.ramPercent == ramPercent &&
      other.diskMount == diskMount &&
      other.diskUsedGb == diskUsedGb &&
      other.diskTotalGb == diskTotalGb &&
      other.diskPercent == diskPercent &&
      other.netRxKbps == netRxKbps &&
      other.netTxKbps == netTxKbps &&
      other.gpuLoad == gpuLoad &&
      other.gpuTemp == gpuTemp;

  @override
  int get hashCode => Object.hash(
        cpuLoad,
        cpuTemp,
        cpuFreqMhz,
        ramUsedMb,
        ramTotalMb,
        ramPercent,
        diskMount,
        diskUsedGb,
        diskTotalGb,
        diskPercent,
        netRxKbps,
        netTxKbps,
        gpuLoad,
        gpuTemp,
      );
}

class StatsService {
  Duration _interval;
  final StatsProvider provider;
  final _controller = StreamController<StatsSnapshot>.broadcast();
  Timer? _timer;
  bool _available = false;
  bool _inFlight = false;
  bool _started = false;
  StatsSnapshot? _last;

  StatsService({
    Duration interval = const Duration(seconds: 3),
    StatsProvider? provider,
  })  : _interval = interval,
        provider = provider ?? _defaultProvider();

  Duration get interval => _interval;

  static StatsProvider _defaultProvider() {
    if (Platform.isLinux) return LinuxStatsProvider();
    if (Platform.isWindows) return WindowsStatsProvider();
    return UnsupportedStatsProvider();
  }

  Stream<StatsSnapshot> get changes => _controller.stream;
  StatsSnapshot? get current => _last;
  bool get isAvailable => _available;

  /// Ajusta dinamicamente o intervalo de coleta (ex: 3s ativo vs 15s ocioso).
  void setInterval(Duration nextInterval) {
    if (_interval == nextInterval) return;
    _interval = nextInterval;
    if (_started && _available) {
      _timer?.cancel();
      _timer = Timer.periodic(_interval, (_) => _poll());
    }
  }

  Future<void> start() async {
    _started = true;
    _available = await provider.probe();
    if (!_available) {
      stderr.writeln('stats: provider indisponivel');
      return;
    }
    await _poll();
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final next = await provider.read();
      if (next != _last) {
        _last = next;
        if (!_controller.isClosed) _controller.add(next);
      }
    } catch (e) {
      stderr.writeln('stats: leitura falhou: $e');
    } finally {
      _inFlight = false;
    }
  }

  Future<void> dispose() async {
    _started = false;
    _timer?.cancel();
    await _controller.close();
  }
}
