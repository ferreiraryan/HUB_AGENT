import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/agent_event.dart';
import '../../models/battery_state.dart';
import '../../util/windows_binaries.dart';

abstract interface class BatteryProvider {
  Future<BatterySnapshot> read();
}

class UnsupportedBatteryProvider implements BatteryProvider {
  @override
  Future<BatterySnapshot> read() async => const BatterySnapshot();
}

class WindowsBatteryProvider implements BatteryProvider {
  String? _helperPath;

  static BatterySnapshot parseHelperJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['devices'] is List) {
        final list = <BatteryDevice>[];
        for (final item in decoded['devices'] as List) {
          if (item is Map) {
            list.add(BatteryDevice.fromJson(item.cast<String, dynamic>()));
          }
        }
        return BatterySnapshot(devices: list);
      }
    } catch (_) {}
    return const BatterySnapshot();
  }

  @override
  Future<BatterySnapshot> read() async {
    _helperPath ??= WindowsBinaries.resolveHelperPath();
    if (_helperPath == null) return const BatterySnapshot();
    try {
      final r = await Process.run(
        _helperPath!,
        ['batteries'],
        runInShell: false,
      ).timeout(const Duration(seconds: 4));
      if (r.exitCode == 0) {
        return parseHelperJson((r.stdout as String).trim());
      }
    } catch (_) {}
    return const BatterySnapshot();
  }
}

class LinuxBatteryProvider implements BatteryProvider {
  static String classifyKind(String nameLower) {
    if (nameLower.contains('mouse') || nameLower.contains('g pro') || nameLower.contains('mx master')) {
      return 'mouse';
    }
    if (nameLower.contains('keyboard') || nameLower.contains('teclado')) {
      return 'keyboard';
    }
    if (nameLower.contains('head') || nameLower.contains('audio') || nameLower.contains('buds') || nameLower.contains('fone')) {
      return 'headphones';
    }
    if (nameLower.contains('controller') || nameLower.contains('sony') || nameLower.contains('xbox') || nameLower.contains('gamepad')) {
      return 'gamepad';
    }
    if (nameLower.startsWith('bat')) return 'laptop';
    return 'other';
  }

  static BatterySnapshot parseUpowerDump(String stdout) {
    final devices = <BatteryDevice>[];
    final blocks = stdout.split(RegExp(r'(?:^|\n)Device:\s+'));
    var idx = 0;
    for (final block in blocks) {
      if (block.trim().isEmpty) continue;
      final pctM = RegExp(r'percentage:\s*(\d+)%').firstMatch(block);
      if (pctM == null) continue;
      final pct = int.tryParse(pctM.group(1)!) ?? 0;
      final modelM = RegExp(r'model:\s*(.+)').firstMatch(block);
      final stateM = RegExp(r'state:\s*(.+)').firstMatch(block);
      final name = (modelM?.group(1)?.trim().isNotEmpty == true)
          ? modelM!.group(1)!.trim()
          : 'Bateria ${idx + 1}';
      final stateStr = (stateM?.group(1) ?? '').toLowerCase();
      final charging = stateStr.contains('charging') && !stateStr.contains('discharging');
      devices.add(BatteryDevice(
        id: 'upower_$idx',
        name: name,
        kind: classifyKind(name.toLowerCase()),
        percent: pct.clamp(0, 100),
        charging: charging,
      ));
      idx++;
    }
    return BatterySnapshot(devices: devices);
  }

  @override
  Future<BatterySnapshot> read() async {
    final devices = <BatteryDevice>[];
    final seenNames = <String>{};

    // 1. /sys/class/power_supply/* (laptop + periféricos HID do kernel)
    try {
      final dir = Directory('/sys/class/power_supply');
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is! Directory) continue;
          final capFile = File('${entity.path}/capacity');
          if (!await capFile.exists()) continue;
          final rawCap = (await capFile.readAsString()).trim();
          final pct = int.tryParse(rawCap);
          if (pct == null) continue;

          final baseName = entity.path.split('/').last;
          String displayName = baseName;
          final modelFile = File('${entity.path}/model_name');
          if (await modelFile.exists()) {
            final m = (await modelFile.readAsString()).trim();
            if (m.isNotEmpty) displayName = m;
          } else if (baseName.toUpperCase().startsWith('BAT')) {
            displayName = 'PC / Notebook';
          }

          bool charging = false;
          final statusFile = File('${entity.path}/status');
          if (await statusFile.exists()) {
            final st = (await statusFile.readAsString()).trim().toLowerCase();
            charging = st == 'charging' || st == 'full';
          }

          seenNames.add(displayName.toLowerCase());
          devices.add(BatteryDevice(
            id: 'sys_$baseName',
            name: displayName,
            kind: classifyKind('${baseName.toLowerCase()} ${displayName.toLowerCase()}'),
            percent: pct.clamp(0, 100),
            charging: charging,
          ));
        }
      }
    } catch (_) {}

    // 2. Complemento upower (Bluetooth headsets / mouses / etc.)
    try {
      final r = await Process.run('upower', ['-d'], runInShell: false)
          .timeout(const Duration(seconds: 3));
      if (r.exitCode == 0) {
        final up = parseUpowerDump(r.stdout as String);
        for (final d in up.devices) {
          if (seenNames.add(d.name.toLowerCase())) {
            devices.add(d);
          }
        }
      }
    } catch (_) {}

    return BatterySnapshot(devices: devices);
  }
}

class BatteryService {
  final BatteryProvider provider;
  final Duration interval;
  final void Function(AgentEvent event)? onLowBatteryEvent;

  final _ctl = StreamController<BatterySnapshot>.broadcast();
  final _warnedLow = <String>{};
  Timer? _timer;
  BatterySnapshot _current = const BatterySnapshot();

  BatteryService({
    BatteryProvider? provider,
    this.interval = const Duration(seconds: 30),
    this.onLowBatteryEvent,
  }) : provider = provider ?? _defaultProvider();

  static BatteryProvider _defaultProvider() {
    if (Platform.isWindows) return WindowsBatteryProvider();
    if (Platform.isLinux) return LinuxBatteryProvider();
    return UnsupportedBatteryProvider();
  }

  Stream<BatterySnapshot> get changes => _ctl.stream;
  BatterySnapshot get current => _current;

  Future<void> start() async {
    await refresh();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  Future<void> refresh() async {
    final next = await provider.read();
    for (final dev in next.devices) {
      if (!dev.charging && dev.percent <= 15) {
        if (_warnedLow.add(dev.id)) {
          onLowBatteryEvent?.call(AgentEvent.warning(
            'Bateria baixa: ${dev.name} (${dev.percent}%)',
          ));
        }
      } else if (dev.percent >= 25 || dev.charging) {
        _warnedLow.remove(dev.id);
      }
    }
    if (next != _current) {
      _current = next;
      if (!_ctl.isClosed) _ctl.add(next);
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _ctl.close();
  }
}
