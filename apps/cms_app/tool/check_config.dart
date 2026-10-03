import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cms_app/system/agent_config.dart';

Future<void> main() async {
  final dir = await getApplicationSupportDirectory();
  print('ApplicationSupportDirectory: ${dir.path}');
  final file = File('${dir.path}/agent_config.json');
  print('Config file: ${file.path}');
  print('Existe: ${await file.exists()}');
  if (await file.exists()) {
    print('Conteúdo: ${await file.readAsString()}');
  }
  final cfg = await AgentConfig.load();
  print('Config carregada: host=${cfg.host} port=${cfg.port} deviceId=${cfg.deviceId}');
  exit(0);
}