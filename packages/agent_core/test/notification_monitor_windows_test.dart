import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:agent_core/src/services/notifications/windows_notification_monitor.dart';
import 'package:test/test.dart';

class _MockProcess implements Process {
  final StreamController<List<int>> _stdoutController = StreamController<List<int>>();
  final StreamController<List<int>> _stderrController = StreamController<List<int>>();
  final Completer<int> _exitCompleter = Completer<int>();
  bool killed = false;

  void emitLine(String line) {
    _stdoutController.add(utf8.encode('$line\n'));
  }

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  int get pid => 1234;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(0);
    }
    _stdoutController.close();
    _stderrController.close();
    return true;
  }
}

void main() {
  group('WindowsNotificationRaw & WindowsNotificationParser', () {
    test('parses json line with title and body', () {
      final events = <AgentEvent>[];
      final parser = WindowsNotificationParser(
        onNotification: (raw) {
          final ev = raw.toAgentEvent();
          if (ev != null) events.add(ev);
        },
      );

      parser.processLine('{"id":100,"app":"Spotify","title":"Tocando Agora","body":"Artista - Faixa"}');

      expect(events.length, equals(1));
      expect(events.first.kind, equals(AgentEventKind.info));
      expect(events.first.message, equals('[Spotify] Tocando Agora: Artista - Faixa'));
      expect(events.first.durationMs, equals(4000));
    });

    test('ignores ready status message from helper', () {
      final events = <AgentEvent>[];
      final parser = WindowsNotificationParser(
        onNotification: (raw) {
          final ev = raw.toAgentEvent();
          if (ev != null) events.add(ev);
        },
      );

      parser.processLine('{"status":"ready","initial_count":5}');
      expect(events, isEmpty);
    });

    test('handles notification with title only', () {
      final raw = WindowsNotificationRaw(
        id: 1,
        appName: 'Discord',
        title: 'Você foi mencionado',
        body: '',
      );

      final ev = raw.toAgentEvent();
      expect(ev, isNotNull);
      expect(ev!.message, equals('[Discord] Você foi mencionado'));
    });

    test('ignores apps in ignoredApps set', () {
      final raw = WindowsNotificationRaw(
        id: 2,
        appName: 'cms_app',
        title: 'Hub Agent Alerta',
        body: 'Teste',
      );

      final ev = raw.toAgentEvent(ignoredApps: {'cms_app', 'hub_agent'});
      expect(ev, isNull);
    });

    test('ignores malformed or empty lines', () {
      final events = <AgentEvent>[];
      final parser = WindowsNotificationParser(
        onNotification: (raw) {
          final ev = raw.toAgentEvent();
          if (ev != null) events.add(ev);
        },
      );

      parser.processLine('');
      parser.processLine('   ');
      parser.processLine('not a json');
      parser.processLine('{"broken_json":');

      expect(events, isEmpty);
    });
  });

  group('WindowsNotificationMonitor', () {
    test('emits notifications received from helper process stdout', () async {
      final mock = _MockProcess();
      final monitor = WindowsNotificationMonitor(
        starter: (executable, arguments, {runInShell = false}) async => mock,
        helperPathOverride: 'fake/path/hub_audio_helper.exe',
      );

      final received = <AgentEvent>[];
      final sub = monitor.notifications.listen(received.add);

      await monitor.start();
      expect(monitor.isAvailable, isTrue);

      mock.emitLine('{"status":"ready","initial_count":10}');
      mock.emitLine('{"id":200,"app":"Slack","title":"Nova mensagem","body":"Reunião às 14h"}');

      await Future.delayed(const Duration(milliseconds: 50));

      expect(received.length, equals(1));
      expect(received.first.message, equals('[Slack] Nova mensagem: Reunião às 14h'));

      await monitor.dispose();
      expect(mock.killed, isTrue);
      expect(monitor.isAvailable, isFalse);
      await sub.cancel();
    });
  });
}

