import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('DaemonEndpointInfo & AgentConfig', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hub_ipc_cfg_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('salva e lê daemon.ipc.json atomicamente', () async {
      final token = DaemonEndpointInfo.generateToken();
      expect(token.length, 64);

      final info = DaemonEndpointInfo(
        port: 49123,
        token: token,
        pid: pid,
      );
      await info.writeAtomic(tempDir);

      final loaded = await DaemonEndpointInfo.read(tempDir);
      expect(loaded, isNotNull);
      expect(loaded!.port, 49123);
      expect(loaded.token, token);
      expect(loaded.pid, pid);
    });

    test('AgentConfig round-trip preserva campos', () async {
      const cfg = AgentConfig(
        host: '192.168.1.50',
        port: 1884,
        deviceId: 'pc-lab',
        soundOutputDevice: 'VoiceMeeter Input',
        mirrorNotifications: false,
        soundVolume: 65,
        autoStartVoiceMeeter: true,
        osdEnabled: false,
        osdPosition: 'top_center',
        searchHotkey: 'ctrl+shift+k',
      );
      await cfg.save(supportDir: tempDir);

      final loaded = await AgentConfig.load(supportDir: tempDir);
      expect(loaded.host, '192.168.1.50');
      expect(loaded.port, 1884);
      expect(loaded.deviceId, 'pc-lab');
      expect(loaded.soundOutputDevice, 'VoiceMeeter Input');
      expect(loaded.mirrorNotifications, isFalse);
      expect(loaded.soundVolume, 65);
      expect(loaded.autoStartVoiceMeeter, isTrue);
      expect(loaded.osdEnabled, isFalse);
      expect(loaded.osdPosition, 'top_center');
      expect(loaded.searchHotkey, 'ctrl+shift+k');
    });
  });

  group('DaemonIpcServer + DaemonIpcClient', () {
    late Directory tempDir;
    late AgentRuntime runtime;
    late DaemonIpcServer server;
    late DaemonIpcClient client;
    late AgentConfig currentConfig;
    late GlobalHotkeyStatus hotkeyStatus;
    String hotkeyCombo = 'alt+space';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hub_ipc_srv_');
      currentConfig = const AgentConfig(
        host: '127.0.0.1',
        port: 19999,
        deviceId: 'test-pc',
      );
      hotkeyStatus = GlobalHotkeyStatus.ready;

      final repo = LayoutRepository(file: File('${tempDir.path}/layout.json'));
      await repo.load(fallbackDeviceName: 'TestPC');
      final mqtt = MqttService(
        host: currentConfig.host,
        port: currentConfig.port,
        deviceId: currentConfig.deviceId,
      );
      runtime = AgentRuntime(
        repository: repo,
        mqtt: mqtt,
        audio: UnsupportedAudioController(),
        brightness: UnsupportedBrightnessController(),
        osd: NoopOsdService(),
        notifications: UnsupportedNotificationMonitor(),
      );

      server = DaemonIpcServer(
        runtime: runtime,
        supportDir: tempDir,
        getConfig: () => currentConfig,
        onUpdateConfig: (updated, {required reconnect}) async {
          currentConfig = updated;
          await updated.save(supportDir: tempDir);
        },
        getHotkeyCombo: () => hotkeyCombo,
        getHotkeyStatus: () => hotkeyStatus,
        onUpdateHotkey: (combo) async {
          hotkeyCombo = combo;
          return hotkeyStatus;
        },
      );
      await server.start();

      final discovered = await DaemonIpcClient.discoverHealthy(tempDir);
      expect(discovered, isNotNull);
      client = discovered!;
    });

    tearDown(() async {
      await client.dispose();
      await server.dispose();
      await runtime.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejeita requisição sem Bearer token com HTTP 401', () async {
      final http = HttpClient();
      try {
        final req = await http.get('127.0.0.1', server.port!, '/v1/health');
        final res = await req.close();
        expect(res.statusCode, HttpStatus.unauthorized);
      } finally {
        http.close(force: true);
      }
    });

    test('GET /v1/state retorna snapshot completo', () async {
      final snap = await client.get('/v1/state');
      expect(snap, isNotNull);
      expect(snap!['ok'], isTrue);
      expect((snap['config'] as Map)['deviceId'], 'test-pc');
      expect(snap['layout'], isA<Map<dynamic, dynamic>>());
      expect(snap['screensaver'], isA<Map<dynamic, dynamic>>());
      expect(snap['hotkey_combo'], 'alt+space');
      expect(snap['hotkey_status'], 'ready');
    });

    test('PUT /v1/layout persiste e transmite layout_changed via WebSocket',
        () async {
      await client.connectEvents();
      expect(server.hasUiClient, isTrue);

      final received = Completer<Map<String, dynamic>>();
      final sub = client.events.listen((ev) {
        if (ev['event'] == 'layout_changed' && !received.isCompleted) {
          received.complete(ev);
        }
      });

      final updated = runtime.repository.current.copyWith(
        deviceName: 'Meu Novo PC',
      );
      final res = await client.put('/v1/layout', body: {
        'layout': updated.toDiskJson(),
        'force': true,
      });
      expect(res?['ok'], isTrue);
      expect(runtime.repository.current.deviceName, 'Meu Novo PC');

      final ev = await received.future.timeout(const Duration(seconds: 3));
      expect((ev['layout'] as Map)['deviceName'], 'Meu Novo PC');
      await sub.cancel();
    });

    test('PUT /v1/page-rules, POST /v1/todo/add e PUT /v1/hotkey funcionam',
        () async {
      final rulesRes = await client.put('/v1/page-rules', body: {
        'page_id': 'code',
        'processes': ['code', 'cursor'],
      });
      expect(rulesRes?['ok'], isTrue);
      expect(runtime.pageRules.current['code'], ['code', 'cursor']);

      final todoRes = await client.post('/v1/todo/add', body: {
        'text': 'Testar daemon IPC',
      });
      expect(todoRes?['ok'], isTrue);
      expect(
        runtime.todo.current.items.any((i) => i.text == 'Testar daemon IPC'),
        isTrue,
      );

      final hkRes = await client.put('/v1/hotkey', body: {
        'combo': 'ctrl+space',
      });
      expect(hkRes?['ok'], isTrue);
      expect(hotkeyCombo, 'ctrl+space');
    });

    test('POST /v1/ui/focus retorna delivered=true apenas com cliente WS',
        () async {
      final before = await client.post('/v1/ui/focus');
      expect(before?['delivered'], isFalse);

      await client.connectEvents();
      final focused = Completer<void>();
      final sub = client.events.listen((ev) {
        if (ev['event'] == 'focus' && !focused.isCompleted) {
          focused.complete();
        }
      });

      final after = await client.post('/v1/ui/focus');
      expect(after?['delivered'], isTrue);
      await focused.future.timeout(const Duration(seconds: 2));
      await sub.cancel();
    });

    test('POST /v1/actions/test-chain valida comando builtin', () async {
      final res = await client.post('/v1/actions/test-chain', body: {
        'cmds': [
          ['__builtin__', 'play_pause'],
        ],
      });
      expect(res?['ok'], isTrue);
      final results = res!['results'] as List;
      expect(results, hasLength(1));
      expect((results.first as Map)['started'], isTrue);
      expect((results.first as Map)['exit_code'], 0);
    });

    test('rejeita WebSocket com token inválido', () async {
      await expectLater(
        () => WebSocket.connect(
          'ws://127.0.0.1:${server.port}/v1/events',
          headers: {'Authorization': 'Bearer wrong-token'},
        ),
        throwsA(isA<WebSocketException>()),
      );
    });

    test('broadcastJson serializa eventos customizados como open_search',
        () async {
      await client.connectEvents();
      final got = Completer<String>();
      final sub = client.events.listen((ev) {
        if (ev['event'] == 'open_search' && !got.isCompleted) {
          got.complete(jsonEncode(ev));
        }
      });

      server.broadcastEvent('open_search');
      final raw = await got.future.timeout(const Duration(seconds: 2));
      expect(raw, contains('open_search'));
      await sub.cancel();
    });
  });
}
