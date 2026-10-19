import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('Sound Pad (Etapa 3: Biblioteca de Sons Gerenciada)', () {
    late Directory tempSoundsDir;
    late SoundLibraryRepository repo;

    setUp(() {
      tempSoundsDir = Directory.systemTemp.createTempSync('sound_lib_test_');
      repo = SoundLibraryRepository(soundsDir: tempSoundsDir);
    });

    tearDown(() {
      if (tempSoundsDir.existsSync()) {
        tempSoundsDir.deleteSync(recursive: true);
      }
    });

    test('SoundItem serializa e desserializa corretamente', () {
      final now = DateTime(2026, 10, 19, 12, 0);
      final item = SoundItem(
        id: 'applause',
        name: 'Aplausos da Galera',
        fileName: 'applause.mp3',
        sizeBytes: 10240,
        addedAt: now,
        durationSeconds: 3.5,
      );

      final json = item.toJson();
      expect(json, equals({
        'id': 'applause',
        'name': 'Aplausos da Galera',
        'file_name': 'applause.mp3',
        'size_bytes': 10240,
        'added_at': now.toIso8601String(),
        'duration_seconds': 3.5,
      }));

      final parsed = SoundItem.fromJson(json);
      expect(parsed.id, equals('applause'));
      expect(parsed.name, equals('Aplausos da Galera'));
      expect(parsed.fileName, equals('applause.mp3'));
      expect(parsed.sizeBytes, equals(10240));
      expect(parsed.durationSeconds, equals(3.5));
    });

    test('listSounds em pasta vazia retorna lista vazia', () async {
      final list = await repo.listSounds();
      expect(list, isEmpty);
    });

    test('importSound copia o arquivo para a biblioteca gerenciada e persiste no indice', () async {
      // Cria um arquivo temporário de origem fora da biblioteca (ex: Downloads)
      final sourceDir = Directory.systemTemp.createTempSync('source_download_');
      try {
        final sourceFile = File('${sourceDir.path}/meu_efeito.wav');
        await sourceFile.writeAsString('fake audio content 123456');

        final imported = await repo.importSound(
          sourceFile: sourceFile,
          customName: 'Efeito Especial',
        );

        expect(imported.id, equals('efeito_especial'));
        expect(imported.name, equals('Efeito Especial'));
        expect(imported.fileName, equals('efeito_especial.wav'));
        expect(imported.sizeBytes, greaterThan(0));

        // Verifica se o arquivo foi realmente copiado para dentro da pasta gerenciada
        final managedFile = repo.getSoundFile('efeito_especial');
        expect(managedFile, isNotNull);
        expect(managedFile!.existsSync(), isTrue);

        // Apaga o arquivo original (Downloads) e garante que a biblioteca continua com o som
        await sourceFile.delete();
        expect(managedFile.existsSync(), isTrue);

        // listSounds agora deve conter o item
        final list = await repo.listSounds();
        expect(list.length, equals(1));
        expect(list.first.id, equals('efeito_especial'));
      } finally {
        sourceDir.deleteSync(recursive: true);
      }
    });

    test('isSoundInUse detecta se um layout referencia o som', () {
      final layout = Layout(
        deviceName: 'PC',
        theme: HubTheme.fallback,
        pages: const {
          'home': [
            SoundTile(
              id: 'tile_buzzer',
              icon: '🚨',
              label: 'Buzzer',
              soundId: 'buzzer_fx',
            ),
          ],
        },
      );

      expect(repo.isSoundInUse('buzzer_fx', layout), isTrue);
      expect(repo.isSoundInUse('outro_som', layout), isFalse);
    });

    test('deleteSound remove o arquivo do disco e do indice', () async {
      final sourceDir = Directory.systemTemp.createTempSync('source_');
      try {
        final sourceFile = File('${sourceDir.path}/risada.mp3');
        await sourceFile.writeAsString('audio bytes');

        await repo.importSound(sourceFile: sourceFile, customId: 'risada');
        expect(repo.getSoundFile('risada')?.existsSync(), isTrue);

        final deleted = await repo.deleteSound('risada');
        expect(deleted, isTrue);

        expect(repo.getSoundFile('risada'), isNull);
        final list = await repo.listSounds();
        expect(list, isEmpty);
      } finally {
        sourceDir.deleteSync(recursive: true);
      }
    });
  });
}

