import 'dart:io';
import 'package:launch_at_startup/launch_at_startup.dart';

class AutostartController {
  static void _setup() {
    // Platform.resolvedExecutable aponta para o binário final compilado do app,
    // garantindo que o autostart chame o programa certo.
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
