import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';

import 'editor_controller.dart';

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

class _CreateTileDialog extends StatefulWidget {
  final String type;
  final EditorState state;

  const _CreateTileDialog({
    required this.type,
    required this.state,
  });

  @override
  State<_CreateTileDialog> createState() => _CreateTileDialogState();
}

class _CreateTileDialogState extends State<_CreateTileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idCtrl;
  late final TextEditingController _labelCtrl;
  String? _targetPage;
  late final Set<String> _existingIds;
  late final List<String> _availableFolderPages;

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

    return AlertDialog(
      title: Text(_typeTitle()),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
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
                  hintText: 'ex: spotify_vol, mute_mic, atalho_1',
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
                if (_availableFolderPages.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Crie outra página antes de adicionar uma pasta de navegação.',
                            style: TextStyle(fontSize: 12, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _targetPage,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Página de Destino *',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableFolderPages
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) => setState(() => _targetPage = val),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (isFolder && _availableFolderPages.isEmpty) ? null : _submit,
          child: const Text('Criar'),
        ),
      ],
    );
  }
}
