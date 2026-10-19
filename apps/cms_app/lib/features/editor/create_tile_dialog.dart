import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'editor_controller.dart';
import 'sound_library_dialog.dart';

Future<Tile?> showCreateTileDialog({
  required BuildContext context,
  required String type,
  required EditorState state,
}) {
  return showDialog<Tile>(
    context: context,
    builder: (ctx) => _CreateTileDialog(
      type: type,
      state: state,
    ),
  );
}

class _CreateTileDialog extends ConsumerStatefulWidget {
  final String type;
  final EditorState state;

  const _CreateTileDialog({
    required this.type,
    required this.state,
  });

  @override
  ConsumerState<_CreateTileDialog> createState() => _CreateTileDialogState();
}

class _CreateTileDialogState extends ConsumerState<_CreateTileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idCtrl;
  late final TextEditingController _labelCtrl;
  String? _targetPage;
  late final Set<String> _existingIds;
  late final List<String> _availableFolderPages;

  List<SoundItem> _availableSounds = [];
  String? _selectedSoundId;

  @override
  void initState() {
    super.initState();
    _existingIds = widget.state.layout.pages.values
        .expand((list) => list)
        .map((t) => t.id)
        .toSet();

    _availableFolderPages = widget.state.layout.pages.keys
        .where((k) => k != widget.state.currentPage)
        .toList();
    if (_availableFolderPages.isNotEmpty) {
      _targetPage = _availableFolderPages.first;
    }

    final initialId = _computeSuggestedId();
    final initialLabel = _computeSuggestedLabel();

    _idCtrl = TextEditingController(text: initialId);
    _labelCtrl = TextEditingController(text: initialLabel);

    if (widget.type == 'sound') {
      _loadSounds();
    }
  }

  Future<void> _loadSounds() async {
    final repo = ref.read(soundLibraryRepositoryProvider);
    final sounds = await repo.listSounds();
    if (mounted) {
      setState(() {
        _availableSounds = sounds;
        if (sounds.isNotEmpty && _selectedSoundId == null) {
          _selectedSoundId = sounds.first.id;
          if (_labelCtrl.text == 'Novo Som') {
            _labelCtrl.text = sounds.first.name;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  String _computeSuggestedId() {
    switch (widget.type) {
      case 'shortcut':
        return widget.state.layout.nextTileId('shortcut');
      case 'slider':
        if (!_existingIds.contains('master_volume')) {
          return 'master_volume';
        }
        return widget.state.layout.nextTileId('slider');
      case 'stat':
        return widget.state.layout.nextTileId('stat');
      case 'sound':
        return widget.state.layout.nextTileId('sound');
      case 'folder':
        return widget.state.layout.nextTileId('folder');
      case 'back':
        return widget.state.layout.nextTileId('back');
      default:
        return widget.state.layout.nextTileId('tile');
    }
  }

  String _computeSuggestedLabel() {
    switch (widget.type) {
      case 'shortcut':
        return 'Novo atalho';
      case 'slider':
        if (!_existingIds.contains('master_volume')) {
          return 'Volume Principal';
        }
        return 'Novo Slider';
      case 'stat':
        return 'CPU';
      case 'sound':
        return 'Novo Som';
      case 'folder':
        return 'Nova pasta';
      case 'back':
        return 'Voltar';
      default:
        return 'Novo item';
    }
  }

  String _typeTitle() {
    switch (widget.type) {
      case 'shortcut':
        return 'Criar Atalho';
      case 'slider':
        return 'Criar Slider';
      case 'stat':
        return 'Criar Stat (Hardware)';
      case 'sound':
        return 'Criar Tile de Som (Sound Pad)';
      case 'folder':
        return 'Criar Pasta';
      case 'back':
        return 'Criar Botão Voltar';
      default:
        return 'Criar Tile';
    }
  }

  String? _validateId(String? val) {
    final text = (val ?? '').trim();
    if (text.isEmpty) {
      return 'O ID é obrigatório';
    }
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(text)) {
      return 'Apenas letras minúsculas, números, _ e -';
    }
    if (_existingIds.contains(text)) {
      return 'Este ID já está em uso em outro tile';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final id = _idCtrl.text.trim();
    final label = _labelCtrl.text.trim();

    Tile tile;
    switch (widget.type) {
      case 'shortcut':
        tile = ShortcutTile(
          id: id,
          icon: '⚡',
          label: label.isEmpty ? 'Novo atalho' : label,
        );
        break;
      case 'slider':
        final isMaster = id == 'master_volume';
        tile = SliderTile(
          id: id,
          icon: isMaster ? '🔊' : '🎚️',
          label: label.isEmpty ? (isMaster ? 'Volume Principal' : 'Novo Slider') : label,
          source: const SliderSource(kind: SliderSource.kindMasterVolume),
        );
        break;
      case 'stat':
        tile = StatTile(
          id: id,
          icon: '📊',
          label: label.isEmpty ? 'CPU' : label,
          source: const StatSource(
            kind: StatSource.kindCpu,
            field: 'load',
            unit: '%',
          ),
        );
        break;
      case 'sound':
        tile = SoundTile(
          id: id,
          icon: '🔊',
          label: label.isEmpty ? 'Novo Som' : label,
          soundId: _selectedSoundId ?? id,
        );
        break;
      case 'folder':
        if (_targetPage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecione uma página de destino válida')),
          );
          return;
        }
        tile = FolderTile(
          id: id,
          icon: '📁',
          label: label.isEmpty ? 'Nova pasta' : label,
          target: _targetPage!,
        );
        break;
      case 'back':
        tile = BackTile(
          id: id,
          icon: '⬅️',
          label: label.isEmpty ? 'Voltar' : label,
        );
        break;
      default:
        return;
    }

    Navigator.of(context).pop(tile);
  }

  @override
  Widget build(BuildContext context) {
    final isFolder = widget.type == 'folder';
    final isSound = widget.type == 'sound';

    return AlertDialog(
      title: Text(_typeTitle()),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 440),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _idCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'ID do Tile *',
                  hintText: 'ex: som_aplausos, buzzer, sound_1',
                  border: OutlineInputBorder(),
                  helperText: 'Identificador único no sistema',
                ),
                validator: _validateId,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rótulo / Nome',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              if (isFolder) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _targetPage,
                  decoration: const InputDecoration(
                    labelText: 'Página de Destino',
                    border: OutlineInputBorder(),
                  ),
                  items: _availableFolderPages.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(p),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _targetPage = val);
                  },
                ),
              ],
              if (isSound) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        // ignore: deprecated_member_use
                        value: (_selectedSoundId != null &&
                                _availableSounds.any((s) => s.id == _selectedSoundId))
                            ? _selectedSoundId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Arquivo da Biblioteca',
                          border: OutlineInputBorder(),
                        ),
                        items: _availableSounds.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSoundId = val;
                            final sound = _availableSounds.firstWhere((s) => s.id == val);
                            if (_labelCtrl.text.isEmpty || _labelCtrl.text == 'Novo Som') {
                              _labelCtrl.text = sound.name;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.library_music),
                      tooltip: 'Abrir Biblioteca de Sons',
                      onPressed: () async {
                        final selected = await showSoundLibraryDialog(
                          context: context,
                          ref: ref,
                          selectMode: true,
                        );
                        if (selected != null) {
                          await _loadSounds();
                          setState(() {
                            _selectedSoundId = selected.id;
                            if (_labelCtrl.text.isEmpty || _labelCtrl.text == 'Novo Som') {
                              _labelCtrl.text = selected.name;
                            }
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (_availableSounds.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Nenhum som na biblioteca ainda. Clique no ícone ao lado para importar um arquivo de áudio.',
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Criar'),
        ),
      ],
    );
  }
}
