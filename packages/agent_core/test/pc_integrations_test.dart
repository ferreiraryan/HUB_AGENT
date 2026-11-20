import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('OSD Payload & Battery Parsers', () {
    test('WindowsOsdService.encodePayload gera JSON valido e normaliza valor', () {
      final raw = WindowsOsdService.encodePayload(
        kind: 'slider',
        title: 'Spotify',
        icon: 'volume',
        subtitle: '100%',
        value: 150,
        accentHex: '#cba6f7',
        position: 'top_center',
        durationMs: 1800,
      );
      final map = jsonDecode(raw) as Map<String, dynamic>;
      expect(map['kind'], equals('slider'));
      expect(map['title'], equals('Spotify'));
      expect(map['value'], equals(100));
      expect(map['position'], equals('top_center'));
    });

    test('WindowsBatteryProvider.parseHelperJson analisa notebook e BT', () {
      const raw =
          '{"devices":[{"id":"pc_main","name":"PC / Notebook","kind":"laptop","percent":85,"charging":true},{"id":"bt_0","name":"iPhone","kind":"other","percent":44,"charging":false}]}';
      final snap = WindowsBatteryProvider.parseHelperJson(raw);
      expect(snap.devices.length, equals(2));
      expect(snap.devices[0].charging, isTrue);
      expect(snap.devices[0].percent, equals(85));
      expect(snap.devices[1].name, equals('iPhone'));
      expect(snap.devices[1].percent, equals(44));
    });

    test('LinuxBatteryProvider.parseUpowerDump analisa saida do upower', () {
      const sample = '''
Device: /org/freedesktop/UPower/devices/battery_BAT0
  model: ThinkPad BAT0
  state: discharging
  percentage: 62%

Device: /org/freedesktop/UPower/devices/mouse_dev_1
  model: MX Master 3S
  state: charging
  percentage: 90%
''';
      final snap = LinuxBatteryProvider.parseUpowerDump(sample);
      expect(snap.devices.length, equals(2));
      expect(snap.devices[0].percent, equals(62));
      expect(snap.devices[0].charging, isFalse);
      expect(snap.devices[1].kind, equals('mouse'));
      expect(snap.devices[1].charging, isTrue);
    });
  });

  group('PageRulesRepository', () {
    test('persiste atomicamente e faz match de processo', () async {
      final tmpDir = await Directory.systemTemp.createTemp('hub_page_rules_');
      try {
        final file = File('${tmpDir.path}/page_rules.json');
        final repo = PageRulesRepository(file: file);
        await repo.load();
        expect(repo.current, isEmpty);

        await repo.setTriggersForPage('dev', ['Code.exe', 'cursor']);
        expect(repo.matchPageForProcess('code'), equals('dev'));
        expect(repo.matchPageForProcess('CURSOR.EXE'), equals('dev'));
        expect(repo.matchPageForProcess('spotify'), isNull);

        final repo2 = PageRulesRepository(file: file);
        await repo2.load();
        expect(repo2.current['dev'], equals(['code', 'cursor']));
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });
  });

  group('StatsSnapshot netJson', () {
    test('WindowsStatsProvider.parseHelperJson inclui net_rx_kbps e net_tx_kbps', () {
      const raw =
          '{"cpu_load":10,"ram_used_mb":4096,"ram_total_mb":16384,"ram_percent":25,"disk_mount":"C:","disk_used_gb":100,"disk_total_gb":500,"disk_percent":20,"net_rx_kbps":1240,"net_tx_kbps":320}';
      final snap = WindowsStatsProvider.parseHelperJson(raw);
      expect(snap, isNotNull);
      expect(snap!.netRxKbps, equals(1240));
      expect(snap.netTxKbps, equals(320));
      expect(snap.netJson(), equals({'rx_kbps': 1240, 'tx_kbps': 320}));
    });
  });
}
