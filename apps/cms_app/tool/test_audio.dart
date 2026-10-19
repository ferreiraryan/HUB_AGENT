// ignore_for_file: avoid_print

import 'dart:io';
import 'package:agent_core/agent_core.dart';

void main() async {
  print('=== Testando WindowsAudioController ===');
  
  final audio = WindowsAudioController();
  print('Tipo: ${audio.runtimeType}');
  
  try {
    print('Chamando start()...');
    await audio.start();
    print('isAvailable: ${audio.isAvailable}');
    print('master: ${audio.master.value}% muted=${audio.master.muted}');
    print('apps (${audio.apps.length}):');
    for (final app in audio.apps) {
      print('  - id="${app.id}" name="${app.name}" vol=${app.volume}%');
    }
    
    print('Tentando setMasterVolume(50)...');
    await audio.setMasterVolume(50);
    await Future.delayed(const Duration(milliseconds: 500));
    print('Depois de set master: ${audio.master.value}%');

    if (audio.apps.isNotEmpty) {
      final firstApp = audio.apps.first;
      print('Tentando setAppVolume("${firstApp.id}", 70)...');
      await audio.setAppVolume(firstApp.id, 70);
      await Future.delayed(const Duration(milliseconds: 500));
      print('Apps após setAppVolume:');
      for (final app in audio.apps) {
        print('  - id="${app.id}" name="${app.name}" vol=${app.volume}%');
      }
    }
    
    print('Dispose...');
    await audio.dispose();
    print('OK');
  } catch (e, st) {
    print('ERRO: $e');
    print(st);
  }
  
  exit(0);
}