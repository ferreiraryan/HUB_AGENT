// apps/cms_app/lib/main.dart

import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'features/editor/editor_controller.dart';
import 'features/editor/editor_page.dart';
import 'features/editor/remote_search_controller.dart';
import 'features/editor/remote_search_spotlight.dart';
import 'features/editor/remote_todo_controller.dart';
import 'features/editor/remote_todo_spotlight.dart';
import 'features/screensaver/screensaver_controller.dart';
import 'providers.dart';
import 'system/agent_bridge.dart';
import 'system/agent_config.dart';
import 'system/global_hotkey_service.dart';
import 'system/tray_controller.dart';
import 'system/voicemeeter_service.dart';
import 'system/window_controller.dart';
import 'theme/cms_theme.dart';

// ignore: unused_element
ServerSocket? _instanceLock;
// ignore: unused_element
RandomAccessFile? _windowsInstanceLock;

/// Hook preenchido pelo [_AppRoot] para descarregar alterações pendentes antes
/// de encerrar o processo Flutter em modo cliente do daemon.
Future<void> Function()? _beforeExitFlush;

String? _parseSpotlightArg(List<String> args) {
  for (final arg in args) {
    if (arg == '--spotlight=search') return 'search';
    if (arg == '--spotlight=todo') return 'todo';
  }
  return null;
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final standalone = args.contains('--standalone');
  final spotlightArg = _parseSpotlightArg(args);
  final isHidden = args.contains('--hidden');

  final supportDir = await getApplicationSupportDirectory();
  stdout.writeln('=== CONFIG DIR: ${supportDir.path} ===');

  if (!standalone) {
    final handled = await _tryRunDaemonClientMode(
      supportDir: supportDir,
      isHidden: isHidden,
      spotlightArg: spotlightArg,
    );
    if (handled) return;
    stdout.writeln(
      '=== hub_agent_daemon indisponível — iniciando em modo standalone ===',
    );
  }

  await _runStandaloneMode(
    supportDir: supportDir,
    isHidden: isHidden || (!args.contains('--show') && spotlightArg == null),
    spotlightArg: spotlightArg,
  );
}

/// Modo Fase 4 (padrão em produção): conecta ao `hub_agent_daemon` via IPC
/// loopback autenticado. Ao fechar a janela (ou o spotlight), o processo
/// Flutter encerra com `exit(0)`, liberando 100% da RAM gráfica/GPU.
Future<bool> _tryRunDaemonClientMode({
  required Directory supportDir,
  required bool isHidden,
  required String? spotlightArg,
}) async {
  final client = await DaemonIpcClient.ensureConnected(supportDir);
  if (client == null) return false;

  // --hidden: apenas garante que o daemon esteja rodando em segundo plano.
  if (isHidden && spotlightArg == null) {
    stdout.writeln('=== hub_agent_daemon ativo em segundo plano. Saindo. ===');
    await client.dispose();
    exit(0);
  }

  // Se já existe uma janela do CMS aberta, apenas traz para frente e encerra.
  if (spotlightArg == null) {
    final focusRes = await client.post('/v1/ui/focus');
    if (focusRes?['delivered'] == true) {
      stdout.writeln('=== Janela existente do CMS focada. Saindo. ===');
      await client.dispose();
      exit(0);
    }
  }

  final bridge = await DaemonAgentBridge.connect(client);
  if (bridge == null) {
    await client.dispose();
    return false;
  }

  final soundsDir = Directory('${supportDir.path}/sounds');
  final soundLibrary = SoundLibraryRepository(soundsDir: soundsDir);
  final imagesDir = Directory('${supportDir.path}/images');
  final imageLibrary = ImageLibraryRepository(imagesDir: imagesDir);

  WindowController.instance.exitOnClose = true;
  WindowController.instance.spotlightExitOnClose = spotlightArg != null;
  WindowController.instance.onRequestExit = () async {
    try {
      await _beforeExitFlush?.call();
    } catch (_) {}
    try {
      await bridge.dispose();
    } catch (_) {}
    exit(0);
  };

  if (spotlightArg == null) {
    bridge.focusRequests.listen((_) {
      unawaited(WindowController.instance.showAndFocus());
    });
    await WindowController.instance.init(hidden: false);
  } else if (spotlightArg == 'search') {
    await WindowController.instance.initForSpotlight(
      title: 'Busca Rápida — Hub Agent',
      size: WindowController.searchSpotlightSize,
    );
  } else {
    await WindowController.instance.initForSpotlight(
      title: 'Nova Tarefa — Hub Agent',
      size: WindowController.spotlightSize,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        agentConfigProvider.overrideWithValue(bridge.currentConfig),
        agentBridgeProvider.overrideWithValue(bridge),
        soundLibraryRepositoryProvider.overrideWithValue(soundLibrary),
        imageLibraryRepositoryProvider.overrideWithValue(imageLibrary),
        if (spotlightArg != null)
          initialSpotlightProvider.overrideWithValue(spotlightArg),
      ],
      child: const CmsApp(),
    ),
  );
  return true;
}

/// Modo legado embarcado (`--standalone` ou desenvolvimento `flutter run` sem
/// binário compilado do `hub_agent_daemon`).
Future<void> _runStandaloneMode({
  required Directory supportDir,
  required bool isHidden,
  required String? spotlightArg,
}) async {
  if (!await _tryObtainSingleInstanceLock(supportDir)) {
    stderr.writeln('Instância já em execução. Saindo.');
    exit(0);
  }

  final config = await AgentConfig.load(supportDir: supportDir);
  stdout.writeln(
    '=== CONFIG: host=${config.host} port=${config.port} deviceId=${config.deviceId} ===',
  );

  final repository = LayoutRepository(
    file: File('${supportDir.path}/layout.json'),
  );

  final mqtt = MqttService(
    host: config.host,
    port: config.port,
    deviceId: config.deviceId,
  );
  final soundsDir = Directory('${supportDir.path}/sounds');
  final soundLibrary = SoundLibraryRepository(soundsDir: soundsDir);

  final imagesDir = Directory('${supportDir.path}/images');
  final imageLibrary = ImageLibraryRepository(imagesDir: imagesDir);

  final soundController = SystemSoundController(
    soundsDir: soundsDir,
    defaultTargetDeviceProvider: () => config.soundOutputDevice,
    initialVolume: config.soundVolume,
    onVolumeChanged: (vol) async {
      try {
        final currentCfg = await AgentConfig.load(supportDir: supportDir);
        await currentCfg.copyWith(soundVolume: vol).save(supportDir: supportDir);
      } catch (_) {}
    },
  );

  final notifications = config.mirrorNotifications
      ? createDefaultNotificationMonitor()
      : UnsupportedNotificationMonitor();

  final runtime = AgentRuntime(
    repository: repository,
    mqtt: mqtt,
    sound: soundController,
    notifications: notifications,
    onOpenCms: WindowController.instance.showAndFocus,
  );
  runtime.osd.setConfig(
    enabled: config.osdEnabled,
    position: config.osdPosition,
  );

  await runtime.start(fallbackDeviceName: Platform.localHostname);
  unawaited(GlobalHotkeyService.instance.updateHotkey(config.searchHotkey));

  if (Platform.isWindows && config.autoStartVoiceMeeter) {
    unawaited(VoiceMeeterService.launchIfEnabled(config));
  }

  await WindowController.instance.init(hidden: isHidden);

  await TrayController.instance.init(
    onShowWindow: WindowController.instance.showAndFocus,
    onHideWindow: WindowController.instance.hide,
    onPublish: () async {
      await repository.flush();
      if (repository.isLoaded) {
        runtime.mqtt.publishLayout(repository.current, force: true);
      }
    },
    onReconnect: () async {
      await runtime.reconnectMqtt();
    },
    onTogglePomodoro: () async {
      await runtime.pomodoro.toggle();
    },
    onQuit: () async {
      await GlobalHotkeyService.instance.dispose();
      await runtime.dispose();
      exit(0);
    },
  );
  runtime.connectionState.listen((s) {
    unawaited(TrayController.instance.updateConnectionState(s));
  });

  final bridge = InProcessAgentBridge(
    runtime: runtime,
    config: config,
    supportDir: supportDir,
  );

  runApp(
    ProviderScope(
      overrides: [
        agentConfigProvider.overrideWithValue(config),
        agentRuntimeProvider.overrideWithValue(runtime),
        agentBridgeProvider.overrideWithValue(bridge),
        soundLibraryRepositoryProvider.overrideWithValue(soundLibrary),
        imageLibraryRepositoryProvider.overrideWithValue(imageLibrary),
        if (spotlightArg != null)
          initialSpotlightProvider.overrideWithValue(spotlightArg),
      ],
      child: const CmsApp(),
    ),
  );
}

Future<bool> _tryObtainSingleInstanceLock(Directory supportDir) async {
  if (Platform.isLinux) {
    try {
      _instanceLock =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 45871);
      return true;
    } catch (_) {
      return false;
    }
  } else if (Platform.isWindows) {
    try {
      final lock = File('${supportDir.path}/cms_app.lock');
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

class CmsApp extends StatelessWidget {
  const CmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hub Agent CMS',
      debugShowCheckedModeBanner: false,
      theme: CmsTheme.dark(),
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(remoteSearchControllerProvider);
    final todoState = ref.watch(remoteTodoControllerProvider);
    final initialSpotlight = ref.watch(initialSpotlightProvider);

    WindowController.instance.onHidden ??= () {
      ref.read(editorControllerProvider.notifier).trimHistory();
      ref.invalidate(screensaverControllerProvider);
    };

    if (initialSpotlight == null) {
      _beforeExitFlush = () async {
        final editorState = ref.read(editorControllerProvider);
        if (editorState.dirty) {
          await ref.read(editorControllerProvider.notifier).flush();
        }
        await ref.read(screensaverControllerProvider.notifier).flush();
      };
    }

    if (searchState.isOpen && searchState.wasHidden) {
      return const RemoteSearchCompactView();
    }
    if (todoState.isOpen && todoState.wasHidden) {
      return const RemoteTodoCompactView();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: WindowController.instance.isWindowVisible,
      builder: (context, isVisible, _) {
        // Quando oculto na bandeja, desmonta toda a árvore do EditorPage
        // (evita AnimationControllers, decodificação de GIFs e texturas em idle).
        if (!isVisible && !searchState.isOpen && !todoState.isOpen) {
          return const SizedBox.shrink();
        }
        return Stack(
          children: [
            const EditorPage(),
            if (searchState.isOpen) const RemoteSearchOverlayView(),
            if (todoState.isOpen) const RemoteTodoOverlayView(),
          ],
        );
      },
    );
  }
}
