import 'package:meta/meta.dart';

/// Metadados de uma imagem ou GIF na biblioteca gerenciada do agente.
@immutable
class ImageItem {
  final String id;
  final String name;
  final String fileName;
  final String bytecodeFileName;
  final String bytecodeHash;
  final String format;
  final int sizeBytes;
  final bool isGif;
  final String dataUri;
  final String? staticDataUri;
  final DateTime addedAt;

  const ImageItem({
    required this.id,
    required this.name,
    required this.fileName,
    required this.bytecodeFileName,
    required this.bytecodeHash,
    required this.format,
    required this.sizeBytes,
    required this.isGif,
    required this.dataUri,
    this.staticDataUri,
    required this.addedAt,
  });

  factory ImageItem.fromJson(Map<String, dynamic> json) => ImageItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        fileName: json['file_name'] as String,
        bytecodeFileName: json['bytecode_file_name'] as String? ??
            '${json['file_name']}.bytecode.txt',
        bytecodeHash: json['bytecode_hash'] as String? ?? '',
        format: json['format'] as String? ?? 'png',
        sizeBytes: json['size_bytes'] as int? ?? 0,
        isGif: json['is_gif'] as bool? ?? false,
        dataUri: json['data_uri'] as String? ?? '',
        staticDataUri: json['static_data_uri'] as String?,
        addedAt: json['added_at'] != null
            ? DateTime.tryParse(json['added_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'file_name': fileName,
        'bytecode_file_name': bytecodeFileName,
        'bytecode_hash': bytecodeHash,
        'format': format,
        'size_bytes': sizeBytes,
        'is_gif': isGif,
        'data_uri': dataUri,
        if (staticDataUri != null) 'static_data_uri': staticDataUri,
        'added_at': addedAt.toIso8601String(),
      };

  ImageItem copyWith({
    String? id,
    String? name,
    String? fileName,
    String? bytecodeFileName,
    String? bytecodeHash,
    String? format,
    int? sizeBytes,
    bool? isGif,
    String? dataUri,
    String? staticDataUri,
    DateTime? addedAt,
  }) =>
      ImageItem(
        id: id ?? this.id,
        name: name ?? this.name,
        fileName: fileName ?? this.fileName,
        bytecodeFileName: bytecodeFileName ?? this.bytecodeFileName,
        bytecodeHash: bytecodeHash ?? this.bytecodeHash,
        format: format ?? this.format,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        isGif: isGif ?? this.isGif,
        dataUri: dataUri ?? this.dataUri,
        staticDataUri: staticDataUri ?? this.staticDataUri,
        addedAt: addedAt ?? this.addedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          fileName == other.fileName &&
          bytecodeHash == other.bytecodeHash &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => Object.hash(id, name, fileName, bytecodeHash, sizeBytes);

  @override
  String toString() =>
      'ImageItem(id: $id, name: $name, hash: $bytecodeHash, file: $fileName)';
}
