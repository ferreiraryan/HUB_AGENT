import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('ImageLibraryRepository', () {
    late Directory tempDir;
    late ImageLibraryRepository repository;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('image_lib_test_');
      repository = ImageLibraryRepository(imagesDir: tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('listImages inicial retorna lista vazia e cria pasta se não existir', () async {
      final images = await repository.listImages();
      expect(images, isEmpty);
      expect(tempDir.existsSync(), isTrue);
    });

    test('importImage calcula hash SHA-256 e gera arquivo nomeado com bytecode e bytecode.txt', () async {
      final sampleBytes = Uint8List.fromList(utf8.encode('fake-image-bytes-12345'));

      final item = await repository.importImage(
        name: 'Ícone do Spotify',
        rawBytes: sampleBytes,
        extension: 'png',
      );

      expect(item.name, equals('Ícone do Spotify'));
      expect(item.id, equals('icone_do_spotify'));
      expect(item.format, equals('png'));
      expect(item.isGif, isFalse);
      expect(item.sizeBytes, equals(sampleBytes.length));

      // Hash completo dos bytes
      expect(item.bytecodeHash.length, equals(64));
      // Nome do arquivo deve conter o prefixo do hash do bytecode
      final shortHash = item.bytecodeHash.substring(0, 10);
      expect(item.fileName, contains('_sha256_$shortHash.png'));
      expect(item.bytecodeFileName, contains('_sha256_$shortHash.bytecode.txt'));

      // Verifica arquivos físicos no disco
      final imgFile = File('${tempDir.path}/${item.fileName}');
      final bcFile = File('${tempDir.path}/${item.bytecodeFileName}');

      expect(imgFile.existsSync(), isTrue);
      expect(bcFile.existsSync(), isTrue);
      expect(imgFile.readAsBytesSync(), equals(sampleBytes));
      expect(bcFile.readAsStringSync(), equals(item.dataUri));
      expect(item.dataUri, startsWith('data:image/png;base64,'));

      // Listar deve retornar o item salvo
      final list = await repository.listImages();
      expect(list.length, equals(1));
      expect(list.first.id, equals(item.id));
      expect(list.first.bytecodeHash, equals(item.bytecodeHash));
    });

    test('importImage detecta GIF e preserva staticDataUri', () async {
      // Assinatura GIF: GIF89a
      final gifHeader = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00]);

      final item = await repository.importImage(
        name: 'Gato Dançando',
        rawBytes: gifHeader,
        extension: 'gif',
        staticDataUri: 'data:image/png;base64,fakeStaticFrame',
      );

      expect(item.isGif, isTrue);
      expect(item.format, equals('gif'));
      expect(item.dataUri, startsWith('data:image/gif;base64,'));
      expect(item.staticDataUri, equals('data:image/png;base64,fakeStaticFrame'));
    });

    test('importImage resolve colisão de nomes com sufixo numérico', () async {
      final bytesA = Uint8List.fromList([1, 2, 3]);
      final bytesB = Uint8List.fromList([4, 5, 6]);

      final item1 = await repository.importImage(
        name: 'Discord',
        rawBytes: bytesA,
        extension: 'png',
      );
      final item2 = await repository.importImage(
        name: 'Discord',
        rawBytes: bytesB,
        extension: 'png',
      );

      expect(item1.id, equals('discord'));
      expect(item2.id, equals('discord_2'));
      expect(item1.fileName, isNot(equals(item2.fileName)));
    });

    test('deleteImage exclui arquivo de imagem, arquivo bytecode e remove do índice', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final item = await repository.importImage(
        name: 'Temporário',
        rawBytes: bytes,
        extension: 'png',
      );

      final imgFile = File('${tempDir.path}/${item.fileName}');
      final bcFile = File('${tempDir.path}/${item.bytecodeFileName}');
      expect(imgFile.existsSync(), isTrue);
      expect(bcFile.existsSync(), isTrue);

      final deleted = await repository.deleteImage(item.id);
      expect(deleted, isTrue);
      expect(imgFile.existsSync(), isFalse);
      expect(bcFile.existsSync(), isFalse);

      final remaining = await repository.listImages();
      expect(remaining, isEmpty);
    });

    test('renameImage atualiza nome no índice', () async {
      final bytes = Uint8List.fromList([11, 22, 33]);
      final item = await repository.importImage(
        name: 'Nome Antigo',
        rawBytes: bytes,
        extension: 'png',
      );

      final updated = await repository.renameImage(item.id, 'Nome Novo');
      expect(updated, isNotNull);
      expect(updated!.name, equals('Nome Novo'));

      final list = await repository.listImages();
      expect(list.first.name, equals('Nome Novo'));
    });

    test('isImageInUse identifica se imagem está aplicada em tiles do layout', () async {
      final bytes = Uint8List.fromList([99, 88, 77]);
      final item = await repository.importImage(
        name: 'Meu Ícone',
        rawBytes: bytes,
        extension: 'png',
      );

      final layoutEmpty = Layout(
        deviceName: 'PC',
        theme: HubTheme.fallback,
        pages: const {'home': []},
      );
      expect(repository.isImageInUse(item, layoutEmpty), isFalse);

      final layoutWithIcon = Layout(
        deviceName: 'PC',
        theme: HubTheme.fallback,
        pages: {
          'home': [
            ShortcutTile(
              id: 'btn1',
              icon: item.dataUri,
              label: 'App',
            ),
          ],
        },
      );
      expect(repository.isImageInUse(item, layoutWithIcon), isTrue);
    });
  });
}

