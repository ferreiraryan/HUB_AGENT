import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'features/editor/editor_page.dart';
import 'providers.dart';
import 'system/agent_config.dart';
import 'system/tray_controller.dart';
import 'system/window_controller.dart';

// ignore: unused_element
ServerSocket? _instanceLock;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final isHidden = args.contains('--hidden');

  final supportDir = await getApplicationSupportDirectory();
  if (!await _tryObtainSingleInstanceLock(supportDir)) {
    stderr.writeln('Instância já em execução. Saindo.');
    exit(0);
  }

  final config = await AgentConfig.load();

  final repository = LayoutRepository(
    file: File('${supportDir.path}/layout.json'),
  );

  final mqtt = MqttService(
    host: config.host,
    port: config.port,
    deviceId: config.deviceId,
  );

  final runtime = AgentRuntime(
    repository: repository,
    mqtt: mqtt,
  );

  await runtime.start(fallbackDeviceName: Platform.localHostname);

  await WindowController.instance.init(hidden: isHidden);

  // Inicializado antes do runApp para garantir que o menu de bandeja e as
  // ações de controle nativo estejam prontas imediatamente, independente da UI Flutter.
  await TrayController.instance.init(
    onShowWindow: WindowController.instance.showAndFocus,
    onHideWindow: WindowController.instance.hide,
    onPublish: () async {
      await repository.flush();
    },
    onQuit: () async {
      await runtime.dispose();
      exit(0);
    },
  );

  runApp(
    ProviderScope(
      overrides: [
        agentConfigProvider.overrideWithValue(config),
        agentRuntimeProvider.overrideWithValue(runtime),
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
      lock
          .openSync(mode: FileMode.writeOnlyAppend)
          .lockSync(FileLock.exclusive);
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const EditorPage(),
    );
  }
}
