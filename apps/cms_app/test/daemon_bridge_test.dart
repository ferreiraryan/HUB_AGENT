import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:cms_app/system/agent_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late AgentRuntime runtime;
  late DaemonIpcServer server;
  late DaemonAgentBridge bridge;
  late AgentConfig config;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cms_bridge_test_');
    config = const AgentConfig(
      host: '127.0.0.1',
      port: 19998,
      deviceId: 'bridge-pc',
    );
    final repo = LayoutRepository(file: File('${tempDir.path}/layout.json'));
    await repo.load(fallbackDeviceName: 'BridgePC');
    final mqtt = MqttService(
      host: config.host,
      port: config.port,
      deviceId: config.deviceId,
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
      getConfig: () => config,
      onUpdateConfig: (updated, {required reconnect}) async {
        config = updated;
        await updated.save(supportDir: tempDir);
      },
      getHotkeyCombo: () => config.searchHotkey,
      getHotkeyStatus: () => GlobalHotkeyStatus.ready,
      onUpdateHotkey: (combo) async {
        config = config.copyWith(searchHotkey: combo);
        return GlobalHotkeyStatus.ready;
      },
    );
    await server.start();

    final client = await DaemonIpcClient.discoverHealthy(tempDir);
    expect(client, isNotNull);
    final connected = await DaemonAgentBridge.connect(client!);
    expect(connected, isNotNull);
    bridge = connected!;
  });

  tearDown(() async {
    await bridge.dispose();
    await server.dispose();
    await runtime.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('DaemonAgentBridge sincroniza layout, pageRules, todo e hotkey',
      () async {
    expect(bridge.isDaemonMode, isTrue);
    expect(bridge.mqttDeviceId, 'bridge-pc');
    expect(bridge.isLayoutLoaded, isTrue);

    final nextLayout = bridge.currentLayout.copyWith(deviceName: 'PC Editado');
    bridge.saveLayout(nextLayout);
    await bridge.flushLayout(forcePublish: true);
    expect(runtime.repository.current.deviceName, 'PC Editado');

    await bridge.setPageTriggers('dev', ['code', 'zed']);
    expect(bridge.pageRules['dev'], ['code', 'zed']);
    expect(runtime.pageRules.current['dev'], ['code', 'zed']);

    await bridge.addTodoItem('Finalizar Fase 4');
    expect(
      runtime.todo.current.items.any((i) => i.text == 'Finalizar Fase 4'),
      isTrue,
    );

    final status = await bridge.updateHotkey('ctrl+alt+space');
    expect(status, GlobalHotkeyStatus.ready);
    expect(bridge.hotkeyCombo, 'ctrl+alt+space');

    final testRes = await bridge.testCommand(['__builtin__', 'play_pause']);
    expect(testRes.ok, isTrue);
  });

  test('DaemonAgentBridge recebe eventos focus e open_search via WebSocket',
      () async {
    final gotFocus = Completer<void>();
    final gotSearch = Completer<void>();
    final s1 = bridge.focusRequests.listen((_) {
      if (!gotFocus.isCompleted) gotFocus.complete();
    });
    final s2 = bridge.remoteSearchPrompts.listen((_) {
      if (!gotSearch.isCompleted) gotSearch.complete();
    });

    server.broadcastEvent('focus');
    server.broadcastEvent('open_search');

    await Future.wait([
      gotFocus.future.timeout(const Duration(seconds: 2)),
      gotSearch.future.timeout(const Duration(seconds: 2)),
    ]);

    await s1.cancel();
    await s2.cancel();
  });
}
