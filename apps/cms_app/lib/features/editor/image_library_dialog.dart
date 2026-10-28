import 'package:agent_core/agent_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'editor_controller.dart';
import 'helpers/image_icon_helper.dart';
import 'widgets/tile_icon_view.dart';

/// Abre o diálogo modal da Biblioteca de Imagens e Ícones.
///
/// Se [selectMode] for verdadeiro, clicar em uma imagem ou em "Selecionar"
/// fechará o diálogo retornando o [ImageItem] escolhido.
Future<ImageItem?> showImageLibraryDialog({
  required BuildContext context,
  required WidgetRef ref,
  bool selectMode = false,
}) {
  return showDialog<ImageItem>(
    context: context,
    builder: (ctx) => _ImageLibraryDialog(selectMode: selectMode),
  );
}

class _ImageLibraryDialog extends ConsumerStatefulWidget {
  final bool selectMode;

  const _ImageLibraryDialog({required this.selectMode});

  @override
  ConsumerState<_ImageLibraryDialog> createState() =>
      _ImageLibraryDialogState();
}

class _ImageLibraryDialogState extends ConsumerState<_ImageLibraryDialog> {
  List<ImageItem> _images = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);
    final repo = ref.read(imageLibraryRepositoryProvider);
    final list = await repo.listImages();
    if (mounted) {
      setState(() {
        _images = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleImport() async {
    try {
      final xFile = await openFile(
        acceptedTypeGroups: [ImageIconHelper.acceptedImageGroup],
      );
      if (xFile == null) return;

      final originalBytes = await xFile.readAsBytes();
      final originalName = xFile.name;
      final dot = originalName.lastIndexOf('.');
      final baseName = (dot != -1) ? originalName.substring(0, dot) : originalName;
      final ext = (dot != -1) ? originalName.substring(dot + 1).toLowerCase() : 'png';

      if (!mounted) return;

      // Diálogo para confirmar / editar o nome da imagem antes de salvar
      final nameController = TextEditingController(text: baseName);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Adicionar Imagem à Biblioteca'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Digite um nome de identificação para esta imagem na biblioteca:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome do Ícone',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Arquivo: $originalName (${(originalBytes.length / 1024).toStringAsFixed(1)} KB)',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final chosenName = nameController.text.trim();
      final isGif = ImageIconHelper.isGifBytes(originalBytes) || ext == 'gif';

      String? staticDataUri;
      if (isGif) {
        try {
          staticDataUri = await ImageIconHelper.processImageBytes(
            originalBytes,
            targetSize: 96,
          );
        } catch (_) {}
      }

      final repo = ref.read(imageLibraryRepositoryProvider);
      final item = await repo.importImage(
        name: chosenName,
        rawBytes: originalBytes,
        extension: ext,
        staticDataUri: staticDataUri,
      );

      await _loadImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imagem "${item.name}" adicionada com sucesso!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar imagem: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleRename(ImageItem item) async {
    final controller = TextEditingController(text: item.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear Imagem'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Novo Nome',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      final repo = ref.read(imageLibraryRepositoryProvider);
      await repo.renameImage(item.id, controller.text.trim());
      await _loadImages();
    }
  }

  Future<void> _handleDelete(ImageItem item) async {
    final repo = ref.read(imageLibraryRepositoryProvider);
    final layout = ref.read(editorControllerProvider).layout;
    final inUse = repo.isImageInUse(item, layout);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Imagem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tem certeza que deseja excluir "${item.name}" da biblioteca?'),
            if (inUse) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amberAccent),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amberAccent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta imagem está em uso no layout atual! Os botões existentes manterão o ícone salvo, mas a imagem será removida da biblioteca.',
                        style: TextStyle(fontSize: 11, color: Colors.amberAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await repo.deleteImage(item.id);
      await _loadImages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imagem "${item.name}" excluída.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _copyBytecode(ImageItem item) {
    Clipboard.setData(ClipboardData(text: item.dataUri));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bytecode Base64 de "${item.name}" copiado para a área de transferência!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _images
        : _images.where((i) {
            return i.name.toLowerCase().contains(query) ||
                i.format.toLowerCase().contains(query) ||
                i.bytecodeHash.toLowerCase().contains(query);
          }).toList();

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho
            Row(
              children: [
                const Icon(Icons.photo_library, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectMode
                            ? 'Selecionar Imagem da Biblioteca'
                            : 'Biblioteca de Imagens e Ícones',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_images.length} imagem(ns) gerenciada(s) com identificação por bytecode',
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _handleImport,
                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                  label: const Text('Adicionar Imagem'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barra de busca
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome, formato (PNG, GIF) ou hash de bytecode...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 16),

            // Conteúdo principal
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmptyState(query.isNotEmpty)
                      : _buildImageGrid(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool hasSearch) {
    if (hasSearch) {
      return const Center(
        child: Text(
          'Nenhuma imagem encontrada para esta busca.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma imagem na biblioteca ainda',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 360,
            child: Text(
              'Importe imagens e GIFs do seu computador para utilizá-los como ícones reutilizáveis em qualquer botão do seu Hub.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _handleImport,
            icon: const Icon(Icons.add_photo_alternate, size: 18),
            label: const Text('Adicionar Primeira Imagem'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<ImageItem> items) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final shortHash = item.bytecodeHash.length >= 10
            ? item.bytecodeHash.substring(0, 10)
            : item.bytecodeHash;
        final sizeKb = (item.sizeBytes / 1024).toStringAsFixed(1);

        return Card(
          elevation: 0,
          color: const Color(0xFF28283E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.selectMode ? () => Navigator.of(context).pop(item) : null,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Miniatura
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: TileIconView(
                      icon: item.dataUri,
                      staticIcon: item.staticDataUri,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Informações
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.isGif
                                    ? Colors.purple.withValues(alpha: 0.3)
                                    : Colors.blue.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.isGif ? 'GIF' : item.format.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.isGif
                                      ? Colors.purpleAccent
                                      : Colors.blueAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$sizeKb KB',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Tooltip(
                          message: 'Hash SHA-256 do bytecode: ${item.bytecodeHash}',
                          child: Text(
                            'SHA: $shortHash...',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Botões de ação
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.selectMode)
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () => Navigator.of(context).pop(item),
                          child: const Text('Usar', style: TextStyle(fontSize: 12)),
                        )
                      else ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: 'Copiar Bytecode Base64',
                              onPressed: () => _copyBytecode(item),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              tooltip: 'Renomear',
                              onPressed: () => _handleRename(item),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16),
                              color: Colors.redAccent,
                              tooltip: 'Excluir',
                              onPressed: () => _handleDelete(item),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
