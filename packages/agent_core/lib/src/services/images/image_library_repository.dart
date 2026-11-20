import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../models/layout.dart';
import '../../models/tile.dart';
import 'image_item.dart';

/// Repositório da biblioteca de imagens e ícones local do agente.
///
/// Gerencia a pasta interna de imagens (`imagesDir`), persistindo os arquivos originais
/// nomeados com seus respectivos hashes SHA-256 e salvando seus bytecodes (.bytecode.txt)
/// para rastreamento e exportação.
class ImageLibraryRepository {
  final Directory imagesDir;

  ImageLibraryRepository({required this.imagesDir});

  File get _indexFile => File('${imagesDir.path}/images.json');

  void _ensureDir() {
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
  }

  /// Lê o índice de imagens persistido em images.json e reconcilia com os arquivos em disco.
  Future<List<ImageItem>> listImages() async {
    _ensureDir();
    final itemsMap = <String, ImageItem>{};

    if (await _indexFile.exists()) {
      try {
        final raw = await _indexFile.readAsString();
        if (raw.trim().isNotEmpty) {
          final list = jsonDecode(raw);
          if (list is List) {
            for (final entry in list) {
              if (entry is Map) {
                final item = ImageItem.fromJson(entry.cast<String, dynamic>());
                itemsMap[item.id] = item;
              }
            }
          }
        }
      } catch (e) {
        stderr.writeln('ImageLibrary: erro ao ler images.json: $e');
      }
    }

    // Reconcilia com os arquivos existentes na pasta
    final filesOnDisk = <String, File>{};
    for (final entity in imagesDir.listSync()) {
      if (entity is File) {
        final filename = entity.uri.pathSegments.last;
        if (!filename.endsWith('images.json') && !filename.endsWith('.bytecode.txt')) {
          filesOnDisk[filename] = entity;
        }
      }
    }

    // Remove itens cujo arquivo de imagem física não existe mais no disco
    final beforeCount = itemsMap.length;
    itemsMap.removeWhere((id, item) => !filesOnDisk.containsKey(item.fileName));
    var indexDirty = itemsMap.length != beforeCount || !_indexFile.existsSync();

    // Adiciona arquivos soltos no disco que não estejam indexados no json
    for (final entry in filesOnDisk.entries) {
      final fileName = entry.key;
      final file = entry.value;

      final alreadyIndexed = itemsMap.values.any((i) => i.fileName == fileName);
      if (!alreadyIndexed) {
        indexDirty = true;
        final dot = fileName.lastIndexOf('.');
        final ext = (dot != -1) ? fileName.substring(dot + 1).toLowerCase() : 'png';
        final base = (dot != -1) ? fileName.substring(0, dot) : fileName;
        final size = file.lengthSync();
        final bytes = file.readAsBytesSync();
        final hash = sha256.convert(bytes).toString();
        final isGif = ext == 'gif' || (bytes.length >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46);
        final mimeType = isGif ? 'image/gif' : 'image/$ext';
        final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
        final bytecodeFileName = '$fileName.bytecode.txt';

        final idCandidate = _slugify(base);
        itemsMap[idCandidate] = ImageItem(
          id: idCandidate,
          name: base,
          fileName: fileName,
          bytecodeFileName: bytecodeFileName,
          bytecodeHash: hash,
          format: ext,
          sizeBytes: size,
          isGif: isGif,
          dataUri: dataUri,
          staticDataUri: null,
          addedAt: file.lastModifiedSync(),
        );

        // Se não tiver o arquivo .bytecode.txt correspondente, gera
        final bcFile = File('${imagesDir.path}/$bytecodeFileName');
        if (!bcFile.existsSync()) {
          bcFile.writeAsStringSync(dataUri);
        }
      }
    }

    final result = itemsMap.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (indexDirty) {
      await _saveIndex(result);
    }
    return result;
  }

  /// Importa uma nova imagem / GIF para a biblioteca com nome e identificação de bytecode.
  Future<ImageItem> importImage({
    required String name,
    required Uint8List rawBytes,
    required String extension,
    String? staticDataUri,
    String? customId,
  }) async {
    _ensureDir();

    final cleanExt = extension.replaceAll('.', '').toLowerCase();
    final isGif = cleanExt == 'gif' ||
        (rawBytes.length >= 3 &&
            rawBytes[0] == 0x47 &&
            rawBytes[1] == 0x49 &&
            rawBytes[2] == 0x46);
    final mimeType = isGif ? 'image/gif' : 'image/$cleanExt';
    final dataUri = 'data:$mimeType;base64,${base64Encode(rawBytes)}';

    // Hash criptográfico dos bytes (identificador do bytecode)
    final fullHash = sha256.convert(rawBytes).toString();
    final shortHash = fullHash.substring(0, 10);

    final displayName = name.trim().isNotEmpty ? name.trim() : 'Imagem';
    final baseSlug = customId?.trim().isNotEmpty == true
        ? customId!.trim()
        : _slugify(displayName);

    // Garante ID único
    final existing = await listImages();
    final existingIds = existing.map((i) => i.id).toSet();
    String finalId = baseSlug;
    int counter = 2;
    while (existingIds.contains(finalId)) {
      finalId = '${baseSlug}_$counter';
      counter++;
    }

    // Nome indicando o identificador do bytecode
    final targetFileName = '${finalId}_sha256_$shortHash.$cleanExt';
    final targetBytecodeFileName = '${finalId}_sha256_$shortHash.bytecode.txt';

    final targetFile = File('${imagesDir.path}/$targetFileName');
    final targetBytecodeFile = File('${imagesDir.path}/$targetBytecodeFileName');

    // Grava imagem e bytecode
    await targetFile.writeAsBytes(rawBytes);
    await targetBytecodeFile.writeAsString(dataUri);

    final item = ImageItem(
      id: finalId,
      name: displayName,
      fileName: targetFileName,
      bytecodeFileName: targetBytecodeFileName,
      bytecodeHash: fullHash,
      format: cleanExt,
      sizeBytes: rawBytes.length,
      isGif: isGif,
      dataUri: dataUri,
      staticDataUri: staticDataUri,
      addedAt: DateTime.now(),
    );

    final updated = List<ImageItem>.from(existing)..add(item);
    updated.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _saveIndex(updated);

    return item;
  }

  /// Exclui uma imagem e seu arquivo de bytecode do disco e do índice.
  Future<bool> deleteImage(String id) async {
    _ensureDir();
    final existing = await listImages();
    final index = existing.indexWhere((i) => i.id == id);
    if (index == -1) return false;

    final item = existing[index];
    final file = File('${imagesDir.path}/${item.fileName}');
    final bcFile = File('${imagesDir.path}/${item.bytecodeFileName}');

    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        stderr.writeln('ImageLibrary: erro ao excluir arquivo ${file.path}: $e');
      }
    }

    if (await bcFile.exists()) {
      try {
        await bcFile.delete();
      } catch (_) {}
    }

    final updated = List<ImageItem>.from(existing)..removeAt(index);
    await _saveIndex(updated);
    return true;
  }

  /// Renomeia o nome de exibição de uma imagem salva.
  Future<ImageItem?> renameImage(String id, String newName) async {
    _ensureDir();
    final clean = newName.trim();
    if (clean.isEmpty) return null;

    final existing = await listImages();
    final index = existing.indexWhere((i) => i.id == id);
    if (index == -1) return null;

    final item = existing[index];
    final updatedItem = item.copyWith(name: clean);
    final updatedList = List<ImageItem>.from(existing)..[index] = updatedItem;
    await _saveIndex(updatedList);
    return updatedItem;
  }

  /// Verifica se uma imagem está sendo utilizada em qualquer botão do layout ativo.
  bool isImageInUse(ImageItem item, Layout layout) {
    final needle = item.dataUri;
    final staticNeedle = item.staticDataUri;

    for (final tiles in layout.pages.values) {
      for (final t in tiles) {
        if (t.icon == needle || (staticNeedle != null && t.staticIcon == staticNeedle)) {
          return true;
        }
        if (t is ToggleTile) {
          if (t.stateA.icon == needle || t.stateB.icon == needle) return true;
        }
      }
    }
    return false;
  }

  Future<void> _saveIndex(List<ImageItem> items) async {
    try {
      final jsonStr = const JsonEncoder.withIndent('  ')
          .convert(items.map((i) => i.toJson()).toList());
      await _indexFile.writeAsString(jsonStr);
    } catch (e) {
      stderr.writeln('ImageLibrary: erro ao salvar images.json: $e');
    }
  }

  String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
