import 'dart:io';
import 'package:agent_core/agent_core.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

class AutostartController {
  static void _setup() {
    // Registra preferencialmente o daemon AOT puro (hub_agent_daemon) no boot,
    // evitando carregar Flutter/GPU enquanto o usuário não abrir o CMS.
    final daemonBin = SupportPaths.resolveSiblingBinary('hub_agent_daemon');
    if (daemonBin != null) {
      launchAtStartup.setup(
        appName: 'Hub Agent',
        appPath: daemonBin,
        args: const [],
      );
      return;
    }

    // Fallback para modo standalone / desenvolvimento sem binário daemon irmão.
    launchAtStartup.setup(
      appName: 'Hub Agent CMS',
      appPath: Platform.resolvedExecutable,
      args: const ['--hidden'],
    );
  }

  static Future<void> enable() async {
    _setup();
    await launchAtStartup.enable();
  }

  static Future<void> disable() async {
    _setup();
    await launchAtStartup.disable();
  }

  static Future<bool> isEnabled() async {
    _setup();
    return await launchAtStartup.isEnabled();
  }
}
