// apps/cms_app/lib/main.dart

import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'features/editor/editor_page.dart';
import 'features/editor/remote_search_controller.dart';
import 'features/editor/remote_search_spotlight.dart';
import 'features/editor/remote_todo_controller.dart';
import 'features/editor/remote_todo_spotlight.dart';
import 'providers.dart';
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

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicia minimizado na bandeja por padrão (passe --show para abrir visível).
  final isHidden = !args.contains('--show');

  final supportDir = await getApplicationSupportDirectory();
  if (!await _tryObtainSingleInstanceLock(supportDir)) {
    stderr.writeln('Instância já em execução. Saindo.');
    exit(0);
  }

  stdout.writeln('=== CONFIG DIR: ${supportDir.path} ===');

  final config = await AgentConfig.load();
  stdout.writeln('=== CONFIG: host=${config.host} port=${config.port} deviceId=${config.deviceId} ===');

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
        final currentCfg = await AgentConfig.load();
        await currentCfg.copyWith(soundVolume: vol).save();
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

  // Inicializado antes do runApp para garantir que o menu de bandeja e as
  // ações de controle nativo estejam prontas imediatamente, independente da UI Flutter.
  await TrayController.instance.init(
    onShowWindow: WindowController.instance.showAndFocus,
    onHideWindow: WindowController.instance.hide,
    onPublish: () async {
      await repository.flush();
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

  runApp(
    ProviderScope(
      overrides: [
        agentConfigProvider.overrideWithValue(config),
        agentRuntimeProvider.overrideWithValue(runtime),
        soundLibraryRepositoryProvider.overrideWithValue(soundLibrary),
        imageLibraryRepositoryProvider.overrideWithValue(imageLibrary),
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

    if (searchState.isOpen && searchState.wasHidden) {
      return const RemoteSearchCompactView();
    }
    if (todoState.isOpen && todoState.wasHidden) {
      return const RemoteTodoCompactView();
    }

    return Stack(
      children: [
        const EditorPage(),
        if (searchState.isOpen) const RemoteSearchOverlayView(),
        if (todoState.isOpen) const RemoteTodoOverlayView(),
      ],
    );
  }
}
