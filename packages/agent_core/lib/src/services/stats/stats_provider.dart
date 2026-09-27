import 'dart:async';

import 'stats_service.dart';

abstract interface class StatsProvider {
  Future<bool> probe();
  Future<StatsSnapshot> read();
}

class UnsupportedStatsProvider implements StatsProvider {
  @override
  Future<bool> probe() async => false;

  @override
  Future<StatsSnapshot> read() async =>
      throw UnsupportedError('Stats não suportado');
}
