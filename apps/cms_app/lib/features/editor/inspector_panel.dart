import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'editor_controller.dart';
import 'emoji_picker.dart';

class InspectorPanel extends ConsumerWidget {
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider);
    final tileId = state.selectedTileId;
    final tiles = state.layout.tilesOf(state.currentPage);

    Tile? tile;
    if (tileId != null) {
      for (final t in tiles) {
        if (t.id == tileId) {
          tile = t;
          break;
        }
      }
    }

    return Container(
      width: 320,
      color: const Color(0xFF1E1E2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Inspector',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          Expanded(
            child: tile == null
                ? _buildEmptyState(context, ref, state, tiles.length)
                : _buildTileState(context, ref, state, tile),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, WidgetRef ref, EditorState state, int tileCount) {
    final issues = state.layout
        .validate()
        .where((i) => i.pageId == state.currentPage)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Página: ${state.currentPage}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('$tileCount tiles nesta página',
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 24),
        const Text('Diagnóstico da página:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (issues.isEmpty)
          const Text('Nenhum problema detectado',
              style: TextStyle(color: Colors.green, fontSize: 13))
        else
          ...issues.map((issue) {
            final isError = issue.level == IssueLevel.error;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isError ? Icons.error : Icons.warning_amber,
                color: isError ? Colors.red : Colors.orange,
              ),
              title: Text(issue.message, style: const TextStyle(fontSize: 12)),
              onTap: () {
                final notifier = ref.read(editorControllerProvider.notifier);
                notifier.selectPage(issue.pageId!);
                if (issue.tileId != null) {
                  notifier.selectTile(issue.tileId);
                }
              },
            );
          }),
      ],
    );
  }

  Widget _buildTileState(
      BuildContext context, WidgetRef ref, EditorState state, Tile tile) {
    final child = switch (tile) {
      ShortcutTile() => _ShortcutInspector(tile: tile, state: state),
      SliderTile() => _ShortcutInspector(tile: tile, state: state),
      FolderTile() => _FolderInspector(tile: tile, state: state),
      BackTile() => _BackInspector(tile: tile, state: state),
    };

    return Column(
      children: [
        Expanded(child: child),
        const Divider(height: 1, thickness: 1, color: Colors.white10),
        _InspectorFooter(tile: tile, state: state),
      ],
    );
  }
}

class _InspectorFooter extends ConsumerWidget {
  final Tile tile;
  final EditorState state;

  const _InspectorFooter({required this.tile, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.content_copy, size: 16),
              label: const Text('Duplicar'),
              onPressed: () => _handleDuplicate(ref),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Excluir'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                foregroundColor: Colors.redAccent,
              ),
              onPressed: () => _handleDelete(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDuplicate(WidgetRef ref) {
    final notifier = ref.read(editorControllerProvider.notifier);
    final allIds = state.layout.pages.values
        .expand((list) => list)
        .map((t) => t.id)
        .toSet();

    String newId = '${tile.id}_copy';
    int counter = 2;
    while (allIds.contains(newId)) {
      newId = '${tile.id}_copy_$counter';
      counter++;
    }

    Tile newTile;
    if (tile is ShortcutTile) {
      newTile = ShortcutTile(id: newId, icon: tile.icon, label: tile.label);
    } else if (tile is FolderTile) {
      final f = tile as FolderTile;
      newTile = FolderTile(
          id: newId, icon: tile.icon, label: tile.label, target: f.target);
    } else if (tile is BackTile) {
      newTile = BackTile(id: newId, icon: tile.icon, label: tile.label);
    } else if (tile is SliderTile) {
      newTile = SliderTile(id: newId, icon: tile.icon, label: tile.label);
    } else {
      return;
    }

    final tiles = state.layout.tilesOf(state.currentPage);
    final originalIndex = tiles.indexWhere((t) => t.id == tile.id);

    notifier.upsertTile(state.currentPage, newTile);

    if (originalIndex >= 0) {
      final tempIndex = tiles.length;
      notifier.reorderTile(state.currentPage, tempIndex, originalIndex + 1);
    }

    notifier.selectTile(newId);
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(editorControllerProvider.notifier);

    if (tile is ShortcutTile) {
      if (state.layout.bindings.containsKey(tile.id)) {
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir comando associado?'),
            content: const Text(
                'Este atalho tem um comando configurado. O que fazer?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'keep'),
                child: const Text('Manter comando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'all'),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Excluir tudo'),
              ),
            ],
          ),
        );

        if (result == 'cancel' || result == null) return;

        notifier.removeTile(state.currentPage, tile.id);
        if (result == 'all') {
          notifier.setBinding(tile.id, null);
        }
        notifier.selectTile(null);
        return;
      }
    } else if (tile is FolderTile) {
      final f = tile as FolderTile;
      int refCount = 0;
      for (final list in state.layout.pages.values) {
        for (final t in list) {
          if (t is FolderTile && t.target == f.target) refCount++;
        }
      }

      if (refCount > 1) {
        final others = refCount - 1;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir pasta?'),
            content: Text(
                'Existem $others outras pastas apontando para \'${f.target}\'. Excluir só este atalho não apaga a página.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Excluir mesmo assim'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }
    }

    notifier.removeTile(state.currentPage, tile.id);
    notifier.selectTile(null);
  }
}

class _ShortcutInspector extends ConsumerStatefulWidget {
  final Tile tile;
  final EditorState state;

  const _ShortcutInspector({required this.tile, required this.state});

  @override
  ConsumerState<_ShortcutInspector> createState() => _ShortcutInspectorState();
}

class _ShortcutInspectorState extends ConsumerState<_ShortcutInspector> {
  late bool _isBuiltinMode;

  bool get _isShortcut => widget.tile is ShortcutTile;

  @override
  void initState() {
    super.initState();
    _isBuiltinMode =
        _isShortcut && Layout.builtinActions.contains(widget.tile.id);
  }

  @override
  void didUpdateWidget(covariant _ShortcutInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tile.id != widget.tile.id ||
        oldWidget.tile.runtimeType != widget.tile.runtimeType) {
      _isBuiltinMode =
          _isShortcut && Layout.builtinActions.contains(widget.tile.id);
    }
  }

  Tile _updateTile({String? id, String? icon, String? label}) {
    final current = widget.tile;

    if (current is SliderTile) {
      return SliderTile(
        id: id ?? current.id,
        icon: icon ?? current.icon,
        label: label ?? current.label,
      );
    }

    return ShortcutTile(
      id: id ?? current.id,
      icon: icon ?? current.icon,
      label: label ?? current.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(editorControllerProvider.notifier);
    final dispatcher = ref.read(agentRuntimeProvider).dispatcher;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LabelField(
          initialValue: widget.tile.label,
          onSubmitted: (newLabel) {
            notifier.upsertTile(
              widget.state.currentPage,
              _updateTile(label: newLabel),
            );
          },
        ),
        const SizedBox(height: 16),
        _IconField(
          icon: widget.tile.icon,
          onPicked: (newIcon) {
            notifier.upsertTile(
              widget.state.currentPage,
              _updateTile(icon: newIcon),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        _IdField(
          initialValue: widget.tile.id,
          hasBinding: widget.state.layout.bindings.containsKey(widget.tile.id),
          onSubmitted: (newId) {
            notifier.upsertTile(
              widget.state.currentPage,
              _updateTile(id: newId),
            );
          },
        ),
        const SizedBox(height: 16),
        if (_isShortcut) ...[
          const Text('Comportamento',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RadioGroup<bool>(
            groupValue: _isBuiltinMode,
            onChanged: (v) {
              if (v != null) setState(() => _isBuiltinMode = v);
            },
            child: Column(
              children: [
                Row(
                  children: [
                    Radio<bool>(
                        value: true, visualDensity: VisualDensity.compact),
                    const Text('Ação embutida', style: TextStyle(fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    Radio<bool>(
                        value: false, visualDensity: VisualDensity.compact),
                    const Text('Comando personalizado',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (_isShortcut && _isBuiltinMode) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: Layout.builtinActions.contains(widget.tile.id)
                ? widget.tile.id
                : Layout.builtinActions.first,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: Layout.builtinActions
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                notifier.upsertTile(
                  widget.state.currentPage,
                  ShortcutTile(
                      id: val,
                      icon: widget.tile.icon,
                      label: widget.tile.label),
                );
              }
            },
          ),
          const SizedBox(height: 4),
          const Text('Esta ação é tratada pelo agente; não precisa de comando.',
              style: TextStyle(fontSize: 11, color: Colors.white54)),
        ],
        if (!_isShortcut || !_isBuiltinMode) ...[
          const SizedBox(height: 8),
          _ArgvEditor(
            initialArgv: widget.state.layout.bindings[widget.tile.id] ?? [],
            dispatcher: dispatcher,
            onChanged: (argv) {
              notifier.setBinding(widget.tile.id, argv);
            },
          ),
        ],
      ],
    );
  }
}

class _FolderInspector extends ConsumerWidget {
  final FolderTile tile;
  final EditorState state;

  const _FolderInspector({required this.tile, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(editorControllerProvider.notifier);
    final availableTargets =
        state.layout.pages.keys.where((k) => k != state.currentPage).toList();

    int refCount = 0;
    for (final list in state.layout.pages.values) {
      for (final t in list) {
        if (t is FolderTile && t.target == tile.target) refCount++;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LabelField(
          initialValue: tile.label,
          onSubmitted: (newLabel) {
            notifier.upsertTile(
              state.currentPage,
              FolderTile(
                  id: tile.id,
                  icon: tile.icon,
                  label: newLabel,
                  target: tile.target),
            );
          },
        ),
        const SizedBox(height: 16),
        _IconField(
          icon: tile.icon,
          onPicked: (newIcon) {
            notifier.upsertTile(
              state.currentPage,
              FolderTile(
                  id: tile.id,
                  icon: newIcon,
                  label: tile.label,
                  target: tile.target),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        const Text('Destino', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue:
              availableTargets.contains(tile.target) ? tile.target : null,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          hint: const Text('Selecione a página'),
          items: availableTargets
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (newTarget) {
            if (newTarget != null && newTarget != tile.target) {
              notifier.removeTile(state.currentPage, tile.id);
              notifier.upsertTile(
                state.currentPage,
                FolderTile(
                    id: tile.id,
                    icon: tile.icon,
                    label: tile.label,
                    target: newTarget),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        Text('Referenciado por $refCount folders',
            style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ],
    );
  }
}

class _BackInspector extends ConsumerWidget {
  final BackTile tile;
  final EditorState state;

  const _BackInspector({required this.tile, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(editorControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LabelField(
          initialValue: tile.label,
          onSubmitted: (newLabel) {
            notifier.upsertTile(
              state.currentPage,
              BackTile(id: tile.id, icon: tile.icon, label: newLabel),
            );
          },
        ),
        const SizedBox(height: 16),
        _IconField(
          icon: tile.icon,
          onPicked: (newIcon) {
            notifier.upsertTile(
              state.currentPage,
              BackTile(id: tile.id, icon: newIcon, label: tile.label),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        const Text('Este tile sempre volta para a Home.',
            style: TextStyle(fontSize: 12, color: Colors.white54)),
      ],
    );
  }
}

// ============================================================================
// Componentes Reutilizáveis
// ============================================================================

class _LabelField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onSubmitted;

  const _LabelField({required this.initialValue, required this.onSubmitted});

  @override
  State<_LabelField> createState() => _LabelFieldState();
}

class _LabelFieldState extends State<_LabelField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _LabelField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _ctrl.text != widget.initialValue) {
      _ctrl.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: const InputDecoration(
        labelText: 'Rótulo',
        border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
      onSubmitted: (val) {
        if (val.trim() != widget.initialValue) widget.onSubmitted(val.trim());
      },
    );
  }
}

class _IdField extends StatefulWidget {
  final String initialValue;
  final bool hasBinding;
  final ValueChanged<String> onSubmitted;

  const _IdField(
      {required this.initialValue,
      required this.hasBinding,
      required this.onSubmitted});

  @override
  State<_IdField> createState() => _IdFieldState();
}

class _IdFieldState extends State<_IdField> {
  late final TextEditingController _ctrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _IdField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _ctrl.text != widget.initialValue) {
      _ctrl.text = widget.initialValue;
      _errorText = null;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _validate(String val) {
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(val)) {
      setState(() => _errorText = 'Apenas letras minúsculas, números e _');
    } else {
      setState(() => _errorText = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText: 'ID do Tile',
            errorText: _errorText,
            border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
          onChanged: _validate,
          onSubmitted: (val) {
            _validate(val);
            if (_errorText == null && val != widget.initialValue) {
              widget.onSubmitted(val);
            }
          },
        ),
        if (widget.hasBinding) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4)),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Este id tem comando associado. Renomear não move o comando.',
                        style: TextStyle(color: Colors.orange, fontSize: 11))),
              ],
            ),
          )
        ],
      ],
    );
  }
}

class _IconField extends StatelessWidget {
  final String icon;
  final ValueChanged<String>? onPicked;

  const _IconField({required this.icon, this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Ícone', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 16),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            if (onPicked == null) return;
            final picked = await showEmojiPicker(context, current: icon);
            if (picked != null && picked != icon) onPicked!(picked);
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(icon.isEmpty ? '?' : icon,
                style: const TextStyle(fontSize: 32)),
          ),
        ),
      ],
    );
  }
}

class _ArgvEditor extends StatefulWidget {
  final List<String> initialArgv;
  final ValueChanged<List<String>?> onChanged;
  final CommandDispatcher dispatcher;

  const _ArgvEditor(
      {required this.initialArgv,
      required this.onChanged,
      required this.dispatcher});

  @override
  State<_ArgvEditor> createState() => _ArgvEditorState();
}

class _ArgvEditorState extends State<_ArgvEditor> {
  late List<TextEditingController> _ctrls;
  Timer? _debounce;
  bool _isTesting = false;
  CommandResult? _testResult;

  @override
  void initState() {
    super.initState();
    _initCtrls();
  }

  @override
  void didUpdateWidget(covariant _ArgvEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialArgv.join('\u0000') !=
        widget.initialArgv.join('\u0000')) {
      _disposeCtrls();
      _initCtrls();
      _testResult = null;
    }
  }

  void _initCtrls() {
    _ctrls =
        widget.initialArgv.map((a) => TextEditingController(text: a)).toList();
  }

  void _disposeCtrls() {
    for (final c in _ctrls) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _disposeCtrls();
    super.dispose();
  }

  void _fireChanged() {
    _debounce?.cancel();
    setState(() {}); // Força rebuild para o FutureBuilder e UI geral
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final argv =
          _ctrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
      widget.onChanged(argv.isEmpty ? null : argv);
    });
  }

  Future<void> _runTest() async {
    final argv =
        _ctrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (argv.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final res = await widget.dispatcher.test(argv);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstArg = _ctrls.isNotEmpty ? _ctrls.first.text.trim() : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Argumentos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        if (firstArg.isNotEmpty)
          FutureBuilder<bool>(
            future: widget.dispatcher.exists(firstArg),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final exists = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(exists ? Icons.check_circle : Icons.cancel,
                        color: exists ? Colors.green : Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        exists
                            ? 'Binário encontrado no PATH'
                            : 'Binário não está no PATH',
                        style: TextStyle(
                            color: exists ? Colors.green : Colors.red,
                            fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ..._ctrls.asMap().entries.map((e) {
          final i = e.key;
          final ctrl = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: i == 0 ? 'Comando (ex: code)' : 'Argumento',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _fireChanged(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    final c = _ctrls.removeAt(i);
                    c.dispose();
                    _fireChanged();
                  },
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Adicionar argumento'),
          onPressed: () {
            setState(() {
              _ctrls.add(TextEditingController());
            });
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: _isTesting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow, size: 16),
          label: const Text('Testar'),
          onPressed: _ctrls.isEmpty || _isTesting ? null : _runTest,
        ),
        if (_testResult != null) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              _testResult!.started
                  ? 'Exit code: ${_testResult!.exitCode}'
                  : 'Não executou',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: _testResult!.error != null
                ? Text(_testResult!.error!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 11))
                : null,
            childrenPadding: const EdgeInsets.all(8),
            children: [
              if (_testResult!.stdout.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(4)),
                  child: SelectableText(_testResult!.stdout,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.white70)),
                ),
              if (_testResult!.stderr.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(4)),
                  child: SelectableText(_testResult!.stderr,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.redAccent)),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _testResult = null),
                  child: const Text('Fechar', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
