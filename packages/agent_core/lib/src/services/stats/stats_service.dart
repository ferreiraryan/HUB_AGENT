import 'dart:async';
import 'dart:io';

import 'stats_provider.dart';
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

  @override
  bool operator ==(Object o) =>
      o is StatsSnapshot &&
      o.cpuLoad == cpuLoad &&
      o.cpuTemp == cpuTemp &&
      o.cpuFreqMhz == cpuFreqMhz &&
      o.ramUsedMb == ramUsedMb &&
      o.ramTotalMb == ramTotalMb &&
      o.ramPercent == ramPercent &&
      o.diskMount == diskMount &&
      o.diskUsedGb == diskUsedGb &&
      o.diskTotalGb == diskTotalGb &&
      o.diskPercent == diskPercent;

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
      );
}

class StatsService {
  final Duration interval;
  final StatsProvider provider;
  final _controller = StreamController<StatsSnapshot>.broadcast();
  Timer? _timer;
  bool _available = false;
  StatsSnapshot? _last;

  StatsService({
    this.interval = const Duration(seconds: 3),
    StatsProvider? provider,
  }) : provider = provider ?? _defaultProvider();

  static StatsProvider _defaultProvider() =>
      Platform.isLinux ? LinuxStatsProvider() : UnsupportedStatsProvider();

  Stream<StatsSnapshot> get changes => _controller.stream;
  StatsSnapshot? get current => _last;
  bool get isAvailable => _available;

  Future<void> start() async {
    _available = await provider.probe();
    if (!_available) {
      stderr.writeln('stats: provider indisponivel');
      return;
    }
    await _poll();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final next = await provider.read();
      if (next != _last) {
        _last = next;
        if (!_controller.isClosed) _controller.add(next);
      }
    } catch (e) {
      stderr.writeln('stats: leitura falhou: $e');
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}
