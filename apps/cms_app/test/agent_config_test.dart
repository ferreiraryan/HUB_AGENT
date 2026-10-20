import 'package:flutter_test/flutter_test.dart';
import 'package:cms_app/system/agent_config.dart';

void main() {
  group('AgentConfig', () {
    test('defaults mirrorNotifications to true', () {
      final config = AgentConfig(
        host: 'localhost',
        port: 1883,
        deviceId: 'pc',
      );
      expect(config.mirrorNotifications, isTrue);

      final fromJson = AgentConfig.fromJson({
        'host': '192.168.1.10',
        'port': 1883,
        'deviceId': 'my-pc',
      });
      expect(fromJson.mirrorNotifications, isTrue);
    });

    test('preserves mirrorNotifications: false in fromJson / toJson', () {
      final config = AgentConfig(
        host: 'localhost',
        port: 1883,
        deviceId: 'pc',
        mirrorNotifications: false,
      );
      final json = config.toJson();
      expect(json['mirrorNotifications'], isFalse);

      final roundTrip = AgentConfig.fromJson(json);
      expect(roundTrip.mirrorNotifications, isFalse);
    });

    test('copyWith updates mirrorNotifications', () {
      final config = AgentConfig(
        host: 'localhost',
        port: 1883,
        deviceId: 'pc',
        mirrorNotifications: true,
      );
      final updated = config.copyWith(mirrorNotifications: false);
      expect(updated.mirrorNotifications, isFalse);
    });
  });
}
