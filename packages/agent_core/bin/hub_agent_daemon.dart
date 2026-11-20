import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';

ServerSocket? _linuxInstanceLock;
RandomAccessFile? _windowsInstanceLock;

/// Daemon AOT puro em Dart (`dart compile exe`) do Hub Agent.
///
/// Executa todo o [AgentRuntime] (MQTT, áudio, mídia, brilho, stats, baterias,
/// pomodoro, tarefas, clima, soundpad, notificações, OSD, clipboard, janela ativa)
/// em ~12–20 MB de RAM sem carregar Flutter, GTK, Skia ou drivers de GPU.
///
/// Expõe um servidor IPC loopback autenticado ([DaemonIpcServer]) para que o
/// `cms_app` abra sob demanda (editor ou Spotlights) e encerre ao fechar.
Future<void> main(List<String> args) async {
  String? dataDirOverride;
  var disableTray = false;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--data-dir' && i + 1 < args.length) {
      dataDirOverride = args[++i];
    } else if (args[i].startsWith('--data-dir=')) {
      dataDirOverride = args[i].substring('--data-dir='.length);
    } else if (args[i] == '--no-tray') {
      disableTray = true;
    }
  }

  final supportDir = SupportPaths.resolveSupportDir(overridePath: dataDirOverride);
  await supportDir.create(recursive: true);

  if (!await _tryObtainSingleInstanceLock(supportDir)) {
    stderr.writeln('hub_agent_daemon: instância já em execução. Saindo.');
    exit(0);
  }

  stdout.writeln('=== HUB AGENT DAEMON — DATA DIR: ${supportDir.path} ===');

  var config = await AgentConfig.load(supportDir: supportDir);
  stdout.writeln(
    '=== CONFIG: host=${config.host} port=${config.port} deviceId=${config.deviceId} ===',
  );

  final repository = LayoutRepository(
    file: File('${supportDir.path}${Platform.pathSeparator}layout.json'),
  );
  final mqtt = MqttService(
    host: config.host,
    port: config.port,
    deviceId: config.deviceId,
  );
  final soundsDir = Directory('${supportDir.path}${Platform.pathSeparator}sounds');
  final soundController = SystemSoundController(
    soundsDir: soundsDir,
    defaultTargetDeviceProvider: () => config.soundOutputDevice,
    initialVolume: config.soundVolume,
    onVolumeChanged: (vol) async {
      try {
        config = config.copyWith(soundVolume: vol);
        await config.save(supportDir: supportDir);
      } catch (_) {}
    },
  );

  final notifications = config.mirrorNotifications
      ? createDefaultNotificationMonitor()
      : UnsupportedNotificationMonitor();

  late final DaemonIpcServer ipc;
  Process? linuxTrayProc;
  var shuttingDown = false;

  Future<void> launchCms(List<String> cmsArgs) async {
    final cmsBin = SupportPaths.resolveSiblingBinary('cms_app');
    if (cmsBin == null) {
      stderr.writeln('hub_agent_daemon: binário cms_app não encontrado.');
      return;
    }
    try {
      await Process.start(
        cmsBin,
        cmsArgs,
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
    } catch (e) {
      stderr.writeln('hub_agent_daemon: falha ao abrir cms_app ($cmsArgs): $e');
    }
  }

  Future<void> openCmsUi() async {
    if (ipc.hasUiClient) {
      ipc.broadcastEvent('focus');
      return;
    }
    await launchCms(const ['--show']);
  }

  Future<void> openSpotlight(String kind) async {
    if (ipc.hasUiClient) {
      ipc.broadcastEvent(kind == 'todo' ? 'open_todo' : 'open_search');
      return;
    }
    await launchCms(['--spotlight=$kind']);
  }

  final runtime = AgentRuntime(
    repository: repository,
    mqtt: mqtt,
    sound: soundController,
    notifications: notifications,
    onOpenCms: () => unawaited(openCmsUi()),
  );
  runtime.osd.setConfig(
    enabled: config.osdEnabled,
    position: config.osdPosition,
  );

  await runtime.start(fallbackDeviceName: Platform.localHostname);

  // Hotkey global no Windows via WindowsHelperBridge (mesmo processo daemon).
  var currentHotkeyCombo = config.searchHotkey.trim().toLowerCase();
  var currentHotkeyStatus = Platform.isWindows
      ? GlobalHotkeyStatus.disabled
      : GlobalHotkeyStatus.unsupported;
  Completer<GlobalHotkeyStatus>? hotkeyWaiter;
  StreamSubscription<Map<String, dynamic>>? winHotkeySub;
  StreamSubscription<Map<String, dynamic>>? winTraySub;

  Future<GlobalHotkeyStatus> updateWindowsHotkey(String combo) async {
    final trimmed = combo.trim().toLowerCase();
    currentHotkeyCombo = trimmed;
    if (!Platform.isWindows) {
      currentHotkeyStatus = GlobalHotkeyStatus.unsupported;
      return currentHotkeyStatus;
    }
    if (trimmed.isEmpty) {
      currentHotkeyStatus = GlobalHotkeyStatus.disabled;
      if (WindowsHelperBridge.instance.isRunning) {
        await WindowsHelperBridge.instance.setHotkey('');
      }
      return currentHotkeyStatus;
    }
    if (!await WindowsHelperBridge.instance.ensureStarted()) {
      currentHotkeyStatus = GlobalHotkeyStatus.unsupported;
      return currentHotkeyStatus;
    }
    final completer = Completer<GlobalHotkeyStatus>();
    hotkeyWaiter = completer;
    await WindowsHelperBridge.instance.setHotkey(trimmed);
    return completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => currentHotkeyStatus,
    );
  }

  if (Platform.isWindows) {
    winHotkeySub = WindowsHelperBridge.instance.hotkeyEvents.listen((ev) {
      final st = ev['status']?.toString();
      if (st == 'ready') {
        currentHotkeyStatus = GlobalHotkeyStatus.ready;
        if (hotkeyWaiter != null && !hotkeyWaiter!.isCompleted) {
          hotkeyWaiter!.complete(currentHotkeyStatus);
        }
      } else if (st == 'triggered') {
        unawaited(openSpotlight('search'));
      } else if (st == 'error') {
        final msg = ev['message']?.toString() ?? '';
        currentHotkeyStatus = msg == 'hotkey_in_use'
            ? GlobalHotkeyStatus.inUse
            : GlobalHotkeyStatus.invalid;
        if (hotkeyWaiter != null && !hotkeyWaiter!.isCompleted) {
          hotkeyWaiter!.complete(currentHotkeyStatus);
        }
      }
    });
    unawaited(updateWindowsHotkey(config.searchHotkey));

    if (config.autoStartVoiceMeeter) {
      unawaited(VoiceMeeterService.launchIfEnabled(config));
    }
  }

  Future<void> shutdown() async {
    if (shuttingDown) return;
    shuttingDown = true;
    stdout.writeln('hub_agent_daemon: encerrando...');
    await winHotkeySub?.cancel();
    await winTraySub?.cancel();
    if (linuxTrayProc != null) {
      try {
        linuxTrayProc!.stdin.writeln('{"cmd":"quit"}');
        await linuxTrayProc!.stdin.flush();
      } catch (_) {}
      try {
        linuxTrayProc!.kill();
      } catch (_) {}
      linuxTrayProc = null;
    }
    await ipc.dispose();
    await runtime.dispose();
    try {
      await _linuxInstanceLock?.close();
    } catch (_) {}
    try {
      _windowsInstanceLock?.closeSync();
    } catch (_) {}
    exit(0);
  }

  ipc = DaemonIpcServer(
    runtime: runtime,
    supportDir: supportDir,
    getConfig: () => config,
    onUpdateConfig: (updated, {required bool reconnect}) async {
      final brokerChanged = updated.host != runtime.mqtt.host ||
          updated.port != runtime.mqtt.port ||
          updated.deviceId != runtime.mqtt.deviceId;
      config = updated;
      await config.save(supportDir: supportDir);
      runtime.sound?.targetDevice = config.soundOutputDevice;
      runtime.osd.setConfig(
        enabled: config.osdEnabled,
        position: config.osdPosition,
      );
      await updateWindowsHotkey(config.searchHotkey);
      if (reconnect || brokerChanged) {
        await runtime.reconfigureMqtt(
          host: config.host,
          port: config.port,
          deviceId: config.deviceId,
        );
      }
    },
    onUpdateHotkey: updateWindowsHotkey,
    getHotkeyCombo: () => currentHotkeyCombo,
    getHotkeyStatus: () => currentHotkeyStatus,
    onShutdownRequested: shutdown,
  );

  final endpoint = await ipc.start();
  stdout.writeln(
    '=== DAEMON IPC PRONTO em 127.0.0.1:${endpoint.port} (pid=${endpoint.pid}) ===',
  );

  // Roteia prompts vindos do tablet (busca rápida e nova tarefa)
  runtime.remoteSearchPrompts.listen((_) => unawaited(openSpotlight('search')));
  runtime.remoteTodoPrompts.listen((_) => unawaited(openSpotlight('todo')));

  void handleTrayAction(String action) {
    switch (action) {
      case 'open_cms':
        unawaited(openCmsUi());
      case 'open_search':
        unawaited(openSpotlight('search'));
      case 'publish':
        unawaited(() async {
          await repository.flush();
          if (repository.isLoaded) {
            runtime.mqtt.publishLayout(repository.current, force: true);
          }
        }());
      case 'reconnect':
        unawaited(runtime.reconnectMqtt());
      case 'toggle_pomodoro':
        unawaited(runtime.pomodoro.toggle());
      case 'quit':
        unawaited(shutdown());
    }
  }

  // Inicializa a bandeja nativa leve (sem Flutter/GPU)
  if (!disableTray) {
    final iconPath = SupportPaths.resolveTrayIconPath();
    if (Platform.isWindows) {
      if (await WindowsHelperBridge.instance.ensureStarted()) {
        winTraySub = WindowsHelperBridge.instance.trayEvents.listen((ev) {
          final action = ev['action']?.toString() ?? '';
          if (action.isNotEmpty) handleTrayAction(action);
        });
        await WindowsHelperBridge.instance.configureTray(
          enabled: true,
          status: runtime.mqtt.stateNotifier.value.name,
          iconPath: iconPath,
        );
        runtime.connectionState.listen((s) {
          unawaited(WindowsHelperBridge.instance.configureTray(
            enabled: true,
            status: s.name,
          ));
        });
      }
    } else if (Platform.isLinux) {
      final trayBin = SupportPaths.resolveSiblingBinary('hub_tray_linux');
      if (trayBin != null) {
        try {
          final proc = await Process.start(
            trayBin,
            iconPath != null ? ['--icon', iconPath] : const [],
            runInShell: false,
          );
          linuxTrayProc = proc;
          proc.stderr.drain<void>();
          proc.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen((line) {
            try {
              final decoded = jsonDecode(line);
              if (decoded is Map && decoded['event'] == 'tray') {
                final action = decoded['action']?.toString() ?? '';
                if (action.isNotEmpty) handleTrayAction(action);
              }
            } catch (_) {}
          });
          runtime.connectionState.listen((s) {
            try {
              linuxTrayProc?.stdin
                  .writeln(jsonEncode({'cmd': 'status', 'state': s.name}));
            } catch (_) {}
          });
        } catch (e) {
          stderr.writeln('hub_agent_daemon: falha ao iniciar hub_tray_linux: $e');
        }
      }
    }
  }

  // Tratamento limpo de sinais do sistema
  ProcessSignal.sigint.watch().listen((_) => unawaited(shutdown()));
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => unawaited(shutdown()));
  }
}

Future<bool> _tryObtainSingleInstanceLock(Directory supportDir) async {
  if (Platform.isLinux) {
    try {
      _linuxInstanceLock =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 45871);
      return true;
    } catch (_) {
      return false;
    }
  } else if (Platform.isWindows) {
    try {
      final lock =
          File('${supportDir.path}${Platform.pathSeparator}hub_agent_daemon.lock');
      final raf = lock.openSync(mode: FileMode.writeOnlyAppend);
      raf.lockSync(FileLock.exclusive);
      _windowsInstanceLock = raf;
      return true;
    } catch (_) {
      return false;
    }
  }
  return true;
}
