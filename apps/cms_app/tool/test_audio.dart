import 'dart:io';
import 'package:agent_core/agent_core.dart';

void main() async {
  print('=== Testando WindowsAudioController ===');
  
  final audio = createDefaultAudioController();
  print('Tipo: ${audio.runtimeType}');
  
  try {
    print('Chamando start()...');
    await audio.start();
    print('isAvailable: ${audio.isAvailable}');
    print('master: ${audio.master.value}% muted=${audio.master.muted}');
    
    print('Tentando setMasterVolume(50)...');
    await audio.setMasterVolume(50);
    await Future.delayed(const Duration(milliseconds: 500));
    print('Depois de set: ${audio.master.value}%');
    
    print('Dispose...');
    await audio.dispose();
    print('OK');
  } catch (e, st) {
    print('ERRO: $e');
    print(st);
  }
  
  exit(0);
}