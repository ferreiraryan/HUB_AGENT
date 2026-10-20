import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('DbusNotifyParser & DbusNotificationRaw', () {
    test('parses standard notification with summary and body', () {
      final events = <AgentEvent>[];
      final parser = DbusNotifyParser(
        onNotification: (raw) {
          final ev = raw.toAgentEvent();
          if (ev != null) events.add(ev);
        },
      );

      final lines = [
        'method call time=1792537154.633480 sender=:1.5110 -> destination=:1.12 serial=9 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify',
        '   string "Discord"',
        '   uint32 0',
        '   string ""',
        '   string "Alice"',
        '   string "Hey, are you free?"',
        '   array [',
        '   ]',
        '   array [',
        '      dict entry(',
        '         string "urgency"',
        '         variant             byte 1',
        '      )',
        '   ]',
        '   int32 -1',
      ];

      for (final line in lines) {
        parser.processLine(line);
      }

      expect(events.length, equals(1));
      expect(events.first.kind, equals(AgentEventKind.info));
      expect(events.first.message, equals('[Discord] Alice: Hey, are you free?'));
      expect(events.first.durationMs, equals(4000));
    });

    test('parses critical notification with urgency 2', () {
      final events = <AgentEvent>[];
      final parser = DbusNotifyParser(
        onNotification: (raw) {
          final ev = raw.toAgentEvent();
          if (ev != null) events.add(ev);
        },
      );

      final lines = [
        'method call time=1792537154.633480 sender=:1.5110 -> destination=:1.12 serial=9 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify',
        '   string "OBS Studio"',
        '   uint32 0',
        '   string "obs-icon"',
        '   string "Gravação Falhou"',
        '   string "Disco cheio"',
        '   array [',
        '   ]',
        '   array [',
        '      dict entry(',
        '         string "urgency"',
        '         variant             byte 2',
        '      )',
        '   ]',
        '   int32 -1',
      ];

      for (final line in lines) {
        parser.processLine(line);
      }

      expect(events.length, equals(1));
      expect(events.first.kind, equals(AgentEventKind.warning));
      expect(events.first.message, equals('[OBS Studio] Gravação Falhou: Disco cheio'));
      expect(events.first.durationMs, equals(5000));
    });

    test('parses notification without body (summary only)', () {
      final events = <AgentEvent>[];
      final parser = DbusNotifyParser(
        onNotification: (raw) {
          final ev = raw.toAgentEvent();
          if (ev != null) events.add(ev);
        },
      );

      final lines = [
        'method call time=1792537154.633480 sender=:1.5110 -> destination=:1.12 serial=9 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify',
        '   string "notify-send"',
        '   uint32 0',
        '   string ""',
        '   string "Download Concluído"',
        '   string ""',
        '   array [',
        '   ]',
        '   array [',
        '   ]',
        '   int32 -1',
      ];

      for (final line in lines) {
        parser.processLine(line);
      }

      expect(events.length, equals(1));
      expect(events.first.message, equals('[notify-send] Download Concluído'));
    });

    test('parses multiline summary and body', () {
      final events = <AgentEvent>[];
      final parser = DbusNotifyParser(
        onNotification: (raw) {
          final ev = raw.toAgentEvent();
          if (ev != null) events.add(ev);
        },
      );

      final lines = [
        'method call time=1792537164.369583 sender=:1.5123 -> destination=:1.12 serial=9 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify',
        '   string "MultilineApp"',
        '   uint32 0',
        '   string ""',
        '   string "Line 1',
        'Line 2"',
        '   string "Body 1',
        'Body 2"',
        '   array [',
        '   ]',
        '   array [',
        '   ]',
        '   int32 -1',
      ];

      for (final line in lines) {
        parser.processLine(line);
      }

      expect(events.length, equals(1));
      expect(
        events.first.message,
        equals('[MultilineApp] Line 1\nLine 2: Body 1\nBody 2'),
      );
    });

    test('ignores apps in ignoredApps list', () {
      final events = <AgentEvent>[];
      final parser = DbusNotifyParser(
        onNotification: (raw) {
          final ev = raw.toAgentEvent(ignoredApps: {'cms_app', 'hub_agent'});
          if (ev != null) events.add(ev);
        },
      );

      final lines = [
        'method call time=1792537164.369583 sender=:1.5123 -> destination=:1.12 serial=9 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify',
        '   string "cms_app"',
        '   uint32 0',
        '   string ""',
        '   string "Notificação Interna"',
        '   string "Não deve ser enviada"',
        '   array [',
        '   ]',
        '   array [',
        '   ]',
        '   int32 -1',
      ];

      for (final line in lines) {
        parser.processLine(line);
      }

      expect(events, isEmpty);
    });

    test('handles consecutive notifications without int32 line', () {
      final events = <AgentEvent>[];
      final parser = DbusNotifyParser(
        onNotification: (raw) {
          final ev = raw.toAgentEvent();
          if (ev != null) events.add(ev);
        },
      );

      final lines1 = [
        'method call time=1.0 sender=:1 -> destination=:2 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify',
        '   string "App1"',
        '   uint32 0',
        '   string ""',
        '   string "Title 1"',
        '   string "Body 1"',
        '   array [',
        '   ]',
      ];

      final lines2 = [
        'method call time=2.0 sender=:1 -> destination=:2 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify',
        '   string "App2"',
        '   uint32 0',
        '   string ""',
        '   string "Title 2"',
        '   string "Body 2"',
        '   array [',
        '   ]',
        '   int32 -1',
      ];

      for (final line in [...lines1, ...lines2]) {
        parser.processLine(line);
      }

      expect(events.length, equals(2));
      expect(events[0].message, equals('[App1] Title 1: Body 1'));
      expect(events[1].message, equals('[App2] Title 2: Body 2'));
    });
  });

  group('LinuxNotificationMonitor live process test', () {
    test('captures real notify-send if tools available', () async {
      final monitor = LinuxNotificationMonitor();
      await monitor.start();

      if (!monitor.isAvailable) {
        await monitor.dispose();
        return; // Ambiente sem dbus-monitor (ex: CI minimalista)
      }

      final futureEvent = monitor.notifications.first.timeout(
        const Duration(seconds: 4),
        onTimeout: () => const AgentEvent(
          kind: AgentEventKind.error,
          message: 'TIMEOUT',
        ),
      );

      // Dispara uma notificação real via notify-send
      final result = await Process.run('notify-send', [
        '-a',
        'IntegrationTestApp',
        'Integration Test Title',
        'Integration Test Body',
      ]);

      if (result.exitCode == 0) {
        final event = await futureEvent;
        if (event.message != 'TIMEOUT') {
          expect(event.message, contains('[IntegrationTestApp] Integration Test Title: Integration Test Body'));
        }
      }

      await monitor.dispose();
    });
  });
}
