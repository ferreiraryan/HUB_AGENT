import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import '../../models/layout.dart';
import '../../models/tile.dart';

/// Metadados de um som na biblioteca gerenciada do agente.
@immutable
class SoundItem {
  final String id;
  final String name;
  final String fileName;
  final int sizeBytes;
  final DateTime addedAt;
  final double? durationSeconds;

  const SoundItem({
    required this.id,
    required this.name,
    required this.fileName,
    required this.sizeBytes,
    required this.addedAt,
    this.durationSeconds,
  });

  factory SoundItem.fromJson(Map<String, dynamic> json) => SoundItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        fileName: json['file_name'] as String,
        sizeBytes: json['size_bytes'] as int? ?? 0,
        addedAt: json['added_at'] != null
            ? DateTime.tryParse(json['added_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'file_name': fileName,
        'size_bytes': sizeBytes,
        'added_at': addedAt.toIso8601String(),
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
      };

  SoundItem copyWith({
    String? id,
    String? name,
    String? fileName,
    int? sizeBytes,
    DateTime? addedAt,
    double? durationSeconds,
  }) =>
      SoundItem(
        id: id ?? this.id,
        name: name ?? this.name,
        fileName: fileName ?? this.fileName,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        addedAt: addedAt ?? this.addedAt,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoundItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          fileName == other.fileName &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => Object.hash(id, name, fileName, sizeBytes);

  @override
  String toString() => 'SoundItem(id: $id, name: $name, file: $fileName)';
}

/// Repositório da biblioteca de sons local.
///
/// Gerencia a pasta interna de sons (`soundsDir`), copiando arquivos para ela
/// para que tiles continuem funcionando mesmo se o arquivo original for movido ou apagado.
class SoundLibraryRepository {
  final Directory soundsDir;

  SoundLibraryRepository({required this.soundsDir});

  File get _indexFile => File('${soundsDir.path}/sounds.json');

  void _ensureDir() {
    if (!soundsDir.existsSync()) {
      soundsDir.createSync(recursive: true);
    }
  }

  /// Lê o índice de sons persistido em sounds.json e reconcilia com os arquivos em disco.
  Future<List<SoundItem>> listSounds() async {
    _ensureDir();
    final itemsMap = <String, SoundItem>{};

    if (await _indexFile.exists()) {
      try {
        final raw = await _indexFile.readAsString();
        if (raw.trim().isNotEmpty) {
          final list = jsonDecode(raw);
          if (list is List) {
            for (final entry in list) {
              if (entry is Map) {
                final item = SoundItem.fromJson(entry.cast<String, dynamic>());
                itemsMap[item.id] = item;
              }
            }
          }
        }
      } catch (e) {
        stderr.writeln('SoundLibrary: erro ao ler sounds.json: $e');
      }
    }

    // Reconcilia com os arquivos existentes na pasta
    final filesOnDisk = <String, File>{};
    for (final entity in soundsDir.listSync()) {
      if (entity is File && !entity.path.endsWith('sounds.json')) {
        final name = entity.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        final id = (dot != -1) ? name.substring(0, dot) : name;
        filesOnDisk[id] = entity;
      }
    }

    // Remove itens cujo arquivo foi deletado do disco
    itemsMap.removeWhere((id, _) => !filesOnDisk.containsKey(id));

    // Adiciona arquivos soltos que estão no disco mas não no índice
    for (final entry in filesOnDisk.entries) {
      if (!itemsMap.containsKey(entry.key)) {
        final file = entry.value;
        final name = file.uri.pathSegments.last;
        final size = file.lengthSync();
        itemsMap[entry.key] = SoundItem(
          id: entry.key,
          name: entry.key,
          fileName: name,
          sizeBytes: size,
          addedAt: file.lastModifiedSync(),
        );
      }
    }

    final result = itemsMap.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Atualiza o sounds.json reconciliado
    await _saveIndex(result);
    return result;
  }

  /// Importa um arquivo de áudio para a pasta interna gerenciada.
  Future<SoundItem> importSound({
    required File sourceFile,
    String? customName,
    String? customId,
    double? durationSeconds,
  }) async {
    _ensureDir();
    if (!await sourceFile.exists()) {
      throw FileSystemException('Arquivo fonte de som não existe', sourceFile.path);
    }

    final originalName = sourceFile.uri.pathSegments.last;
    final dot = originalName.lastIndexOf('.');
    final ext = (dot != -1) ? originalName.substring(dot) : '.mp3';
    final baseName = (dot != -1) ? originalName.substring(0, dot) : originalName;

    final displayName = customName?.trim().isNotEmpty == true ? customName!.trim() : baseName;
    final idCandidate = customId?.trim().isNotEmpty == true ? customId!.trim() : _slugify(displayName);

    // Garante ID único
    final existing = await listSounds();
    final existingIds = existing.map((s) => s.id).toSet();
    String finalId = idCandidate;
    int counter = 2;
    while (existingIds.contains(finalId)) {
      finalId = '${idCandidate}_$counter';
      counter++;
    }

    final targetFileName = '$finalId$ext';
    final targetFile = File('${soundsDir.path}/$targetFileName');

    // Copia o arquivo para a biblioteca gerenciada
    await sourceFile.copy(targetFile.path);
    final size = await targetFile.length();

    final item = SoundItem(
      id: finalId,
      name: displayName,
      fileName: targetFileName,
      sizeBytes: size,
      addedAt: DateTime.now(),
      durationSeconds: durationSeconds,
    );

    final updated = List<SoundItem>.from(existing)..add(item);
    updated.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _saveIndex(updated);

    return item;
  }

  /// Remove um som da biblioteca e apaga o arquivo do disco.
  Future<bool> deleteSound(String soundId) async {
    _ensureDir();
    final existing = await listSounds();
    final itemIndex = existing.indexWhere((s) => s.id == soundId);
    if (itemIndex == -1) return false;

    final item = existing[itemIndex];
    final file = File('${soundsDir.path}/${item.fileName}');
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        stderr.writeln('SoundLibrary: erro ao deletar arquivo ${file.path}: $e');
      }
    }

    existing.removeAt(itemIndex);
    await _saveIndex(existing);
    return true;
  }

  /// Verifica se algum tile no layout atual faz referência a este som.
  bool isSoundInUse(String soundId, Layout layout) {
    for (final page in layout.pages.values) {
      for (final tile in page) {
        if (tile is SoundTile && tile.soundId == soundId) {
          return true;
        }
      }
    }
    return false;
  }

  /// Retorna o arquivo físico de um som caso exista.
  File? getSoundFile(String soundId) {
    _ensureDir();
    for (final entity in soundsDir.listSync()) {
      if (entity is File && !entity.path.endsWith('sounds.json')) {
        final name = entity.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        final id = (dot != -1) ? name.substring(0, dot) : name;
        if (id == soundId) return entity;
      }
    }
    return null;
  }

  Future<void> _saveIndex(List<SoundItem> items) async {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      final raw = encoder.convert(items.map((i) => i.toJson()).toList());
      await _indexFile.writeAsString(raw, flush: true);
    } catch (e) {
      stderr.writeln('SoundLibrary: falha ao gravar sounds.json: $e');
    }
  }

  String _slugify(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'sound' : cleaned;
  }
}

