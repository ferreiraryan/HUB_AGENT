import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'editor_controller.dart';

Future<SoundItem?> showSoundLibraryDialog({
  required BuildContext context,
  required WidgetRef ref,
  bool selectMode = false,
}) {
  return showDialog<SoundItem>(
    context: context,
    builder: (ctx) => _SoundLibraryDialog(selectMode: selectMode),
  );
}

class _SoundLibraryDialog extends ConsumerStatefulWidget {
  final bool selectMode;

  const _SoundLibraryDialog({required this.selectMode});

  @override
  ConsumerState<_SoundLibraryDialog> createState() =>
      _SoundLibraryDialogState();
}

class _SoundLibraryDialogState extends ConsumerState<_SoundLibraryDialog> {
  List<SoundItem> _sounds = [];
  bool _isLoading = true;
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    setState(() => _isLoading = true);
    final repo = ref.read(soundLibraryRepositoryProvider);
    final list = await repo.listSounds();
    if (mounted) {
      setState(() {
        _sounds = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleImport() async {
    const typeGroup = XTypeGroup(
      label: 'Áudio',
      extensions: ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac', 'wma'],
    );

    try {
      final xFile = await openFile(acceptedTypeGroups: [typeGroup]);
      if (xFile == null) return;

      final repo = ref.read(soundLibraryRepositoryProvider);
      final imported = await repo.importSound(sourceFile: File(xFile.path));

      await _loadSounds();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Som "${imported.name}" importado com sucesso!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar arquivo de áudio: $e')),
        );
      }
    }
  }

  Future<void> _handleDelete(SoundItem sound) async {
    final repo = ref.read(soundLibraryRepositoryProvider);
    final layout = ref.read(editorControllerProvider).layout;
    final inUse = repo.isSoundInUse(sound.id, layout);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Som'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tem certeza que deseja excluir "${sound.name}"?'),
            const SizedBox(height: 8),
            Text(
              'O arquivo correspondente será apagado da biblioteca.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            if (inUse) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Atenção: Este som está sendo usado por um ou mais tiles no seu layout!',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final runtime = ref.read(agentRuntimeProvider);
      if (_currentlyPlayingId == sound.id) {
        await runtime.sound?.stop();
        setState(() => _currentlyPlayingId = null);
      }
      await repo.deleteSound(sound.id);
      await _loadSounds();
    }
  }

  Future<void> _togglePreview(SoundItem sound) async {
    final runtime = ref.read(agentRuntimeProvider);
    if (_currentlyPlayingId == sound.id) {
      await runtime.sound?.stop();
      setState(() => _currentlyPlayingId = null);
    } else {
      setState(() => _currentlyPlayingId = sound.id);
      await runtime.sound?.play(sound.id);
      // Fica escutando até o fim da reprodução
      runtime.sound?.stateChanges.firstWhere((s) => !s.isPlaying).then((_) {
        if (mounted && _currentlyPlayingId == sound.id) {
          setState(() => _currentlyPlayingId = null);
        }
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final soundsDir = ref.read(soundLibraryRepositoryProvider).soundsDir.path;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.library_music, color: Colors.deepPurpleAccent),
          const SizedBox(width: 8),
          Text(widget.selectMode ? 'Selecionar Som da Biblioteca' : 'Biblioteca de Sons'),
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Importar Som'),
            onPressed: _handleImport,
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pasta gerenciada: $soundsDir',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _sounds.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_off, size: 48, color: Colors.white24),
                              const SizedBox(height: 12),
                              const Text(
                                'Nenhum som importado ainda.',
                                style: TextStyle(color: Colors.white54),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                icon: const Icon(Icons.file_upload, size: 16),
                                label: const Text('Importar do Computador'),
                                onPressed: _handleImport,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _sounds.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) {
                            final sound = _sounds[index];
                            final isPlaying = _currentlyPlayingId == sound.id;

                            return ListTile(
                              leading: IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                                  color: isPlaying ? Colors.amberAccent : Colors.deepPurpleAccent,
                                  size: 32,
                                ),
                                tooltip: isPlaying ? 'Parar prévia' : 'Ouvir prévia no PC',
                                onPressed: () => _togglePreview(sound),
                              ),
                              title: Text(sound.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                'ID: ${sound.id} • ${_formatSize(sound.sizeBytes)} • ${sound.fileName}',
                                style: const TextStyle(fontSize: 12, color: Colors.white54),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.selectMode)
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, sound),
                                      child: const Text('Selecionar'),
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      tooltip: 'Excluir som',
                                      onPressed: () => _handleDelete(sound),
                                    ),
                                ],
                              ),
                              onTap: widget.selectMode ? () => Navigator.pop(context, sound) : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(agentRuntimeProvider).sound?.stop();
            Navigator.pop(context);
          },
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

