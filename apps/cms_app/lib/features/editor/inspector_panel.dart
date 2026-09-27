import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'editor_controller.dart';
import 'emoji_picker.dart';
import 'brightness_picker.dart';

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

    return Material(
      color: const Color(0xFF1E1E2E),
      child: SizedBox(
        width: 320,
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
    } else if (tile is SliderTile) {
      final s = tile as SliderTile;
      newTile = SliderTile(
          id: newId, icon: tile.icon, label: tile.label, source: s.source);
    } else if (tile is FolderTile) {
      final f = tile as FolderTile;
      newTile = FolderTile(
          id: newId, icon: tile.icon, label: tile.label, target: f.target);
    } else if (tile is BackTile) {
      newTile = BackTile(id: newId, icon: tile.icon, label: tile.label);
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

  @override
  void initState() {
    super.initState();
    if (widget.tile is ShortcutTile) {
      _isBuiltinMode = Layout.builtinActions.contains(widget.tile.id);
    } else {
      _isBuiltinMode = false;
    }
  }

  @override
  void didUpdateWidget(covariant _ShortcutInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tile.id != widget.tile.id) {
      if (widget.tile is ShortcutTile) {
        _isBuiltinMode = Layout.builtinActions.contains(widget.tile.id);
      } else {
        _isBuiltinMode = false;
      }
    }
  }

  Tile _updateTile({String? id, String? icon, String? label}) {
    final current = widget.tile;
    if (current is ShortcutTile) {
      return ShortcutTile(
        id: id ?? current.id,
        icon: icon ?? current.icon,
        label: label ?? current.label,
      );
    } else if (current is SliderTile) {
      return SliderTile(
        id: id ?? current.id,
        icon: icon ?? current.icon,
        label: label ?? current.label,
        source: current.source,
      );
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(editorControllerProvider.notifier);
    final dispatcher = ref.read(agentRuntimeProvider).dispatcher;

    final isShortcut = widget.tile is ShortcutTile;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LabelField(
          initialValue: widget.tile.label,
          onSubmitted: (newLabel) {
            notifier.upsertTile(
                widget.state.currentPage, _updateTile(label: newLabel));
          },
        ),
        const SizedBox(height: 16),
        _IconField(
          icon: widget.tile.icon,
          onPicked: (newIcon) {
            notifier.upsertTile(
                widget.state.currentPage, _updateTile(icon: newIcon));
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        _IdField(
          initialValue: widget.tile.id,
          hasBinding: widget.state.layout.bindings.containsKey(widget.tile.id),
          onSubmitted: (newId) {
            notifier.upsertTile(
                widget.state.currentPage, _updateTile(id: newId));
          },
        ),
        if (widget.tile is SliderTile) ...[
          const Divider(height: 32, color: Colors.white10),
          const Text('Fonte do Slider',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: (widget.tile as SliderTile).source.kind,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: SliderSource.kindMasterVolume,
                child: Text('Volume Master'),
              ),
              DropdownMenuItem(
                value: SliderSource.kindAppVolume,
                child: Text('Volume de App'),
              ),
              DropdownMenuItem(
                value: SliderSource.kindBrightness,
                child: Text('Brilho'),
              ),
            ],
            onChanged: (kind) {
              if (kind == null) return;
              final current = widget.tile as SliderTile;
              final newSource = kind == SliderSource.kindAppVolume
                  ? SliderSource(kind: kind, match: '')
                  : SliderSource(kind: kind);
              notifier.upsertTile(
                widget.state.currentPage,
                SliderTile(
                  id: current.id,
                  icon: current.icon,
                  label: current.label,
                  source: newSource,
                ),
              );
            },
          ),
          if ((widget.tile as SliderTile).source.kind ==
              SliderSource.kindMasterVolume) ...[
            const SizedBox(height: 8),
            const Text(
              'Aplica o volume geral do sistema.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ] else if ((widget.tile as SliderTile).source.kind ==
              SliderSource.kindAppVolume) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: (widget.tile as SliderTile).source.match ?? '',
              decoration: const InputDecoration(
                labelText: 'Nome do App (match)',
                hintText: 'ex: Firefox, Spotify, mpv',
                border: OutlineInputBorder(),
                helperText: 'Case-sensitive. É o application.name do pactl.',
              ),
              onFieldSubmitted: (value) {
                final current = widget.tile as SliderTile;
                notifier.upsertTile(
                  widget.state.currentPage,
                  SliderTile(
                    id: current.id,
                    icon: current.icon,
                    label: current.label,
                    source: current.source.copyWith(
                        match: value.trim(), clearMatch: value.trim().isEmpty),
                  ),
                );
              },
            ),
          ] else if ((widget.tile as SliderTile).source.kind ==
              SliderSource.kindBrightness) ...[
            const SizedBox(height: 12),
            MonitorDropdown(
              currentMatch: (widget.tile as SliderTile).source.match,
              onChanged: (val) {
                final current = widget.tile as SliderTile;
                notifier.upsertTile(
                  widget.state.currentPage,
                  SliderTile(
                    id: current.id,
                    icon: current.icon,
                    label: current.label,
                    source: current.source
                        .copyWith(match: val, clearMatch: val.isEmpty),
                  ),
                );
              },
            ),
          ],
        ],
        if (isShortcut) ...[
          const SizedBox(height: 16),
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
          if (_isBuiltinMode) ...[
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
                      widget.state.currentPage, _updateTile(id: val));
                }
              },
            ),
            const SizedBox(height: 4),
            const Text(
                'Esta ação é tratada pelo agente; não precisa de comando.',
                style: TextStyle(fontSize: 11, color: Colors.white54)),
          ] else ...[
            const SizedBox(height: 8),
            _CommandsEditor(
              initialCommands:
                  widget.state.layout.bindings[widget.tile.id] ?? const [],
              dispatcher: dispatcher,
              onChanged: (cmds) {
                notifier.setBinding(widget.tile.id, cmds);
              },
            ),
          ],
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

class _CmdCtrl {
  final List<TextEditingController> args;
  bool isTesting = false;
  CommandResult? testResult;

  _CmdCtrl(List<String> initial)
      : args = initial.isEmpty
            ? [TextEditingController()]
            : initial.map((a) => TextEditingController(text: a)).toList();

  void dispose() {
    for (final c in args) {
      c.dispose();
    }
  }
}

class _CommandsEditor extends StatefulWidget {
  final List<List<String>> initialCommands;
  final ValueChanged<List<List<String>>?> onChanged;
  final CommandDispatcher dispatcher;

  const _CommandsEditor({
    required this.initialCommands,
    required this.onChanged,
    required this.dispatcher,
  });

  @override
  State<_CommandsEditor> createState() => _CommandsEditorState();
}

class _CommandsEditorState extends State<_CommandsEditor> {
  late List<_CmdCtrl> _commands;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initCtrls();
  }

  @override
  void didUpdateWidget(covariant _CommandsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStr =
        oldWidget.initialCommands.map((c) => c.join('\u0000')).join('\u0001');
    final newStr =
        widget.initialCommands.map((c) => c.join('\u0000')).join('\u0001');
    if (oldStr != newStr) {
      _disposeCtrls();
      _initCtrls();
    }
  }

  void _initCtrls() {
    if (widget.initialCommands.isEmpty) {
      _commands = [];
    } else {
      _commands = widget.initialCommands.map((c) => _CmdCtrl(c)).toList();
    }
  }

  void _disposeCtrls() {
    for (final c in _commands) {
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
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final cmds = <List<String>>[];
      for (final ctrl in _commands) {
        final argv = ctrl.args
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (argv.isNotEmpty) {
          cmds.add(argv);
        }
      }
      widget.onChanged(cmds.isEmpty ? null : cmds);
    });
  }

  Future<void> _runTest(int index) async {
    final ctrl = _commands[index];
    final argv =
        ctrl.args.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (argv.isEmpty) return;

    setState(() {
      ctrl.isTesting = true;
      ctrl.testResult = null;
    });

    final res = await widget.dispatcher.test(argv);

    if (mounted) {
      setState(() {
        ctrl.isTesting = false;
        ctrl.testResult = res;
      });
    }
  }

  void _moveCmd(int index, int dir) {
    if (index + dir < 0 || index + dir >= _commands.length) return;
    final temp = _commands[index];
    _commands[index] = _commands[index + dir];
    _commands[index + dir] = temp;
    _fireChanged();
  }

  void _deleteCmd(int index) {
    _commands[index].dispose();
    _commands.removeAt(index);
    _fireChanged();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSingle = _commands.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_commands.isNotEmpty) ...[
          if (!isSingle)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Comandos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ..._commands.asMap().entries.map((e) {
            final i = e.key;
            final ctrl = e.value;
            final firstArg =
                ctrl.args.isNotEmpty ? ctrl.args.first.text.trim() : '';

            Widget content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isSingle)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 16),
                          onPressed: i > 0 ? () => _moveCmd(i, -1) : null,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 16),
                          onPressed: i < _commands.length - 1
                              ? () => _moveCmd(i, 1)
                              : null,
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _deleteCmd(i),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                if (isSingle)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('Comando',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
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
                                color: exists ? Colors.green : Colors.red,
                                size: 14),
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
                ...ctrl.args.asMap().entries.map((argEntry) {
                  return _ArgTextField(
                    controller: argEntry.value,
                    isFirst: argEntry.key == 0,
                    onChanged: _fireChanged,
                    onDeleted: () {
                      argEntry.value.dispose();
                      ctrl.args.removeAt(argEntry.key);
                      _fireChanged();
                    },
                  );
                }),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Argumento'),
                        onPressed: () {
                          setState(() {
                            ctrl.args.add(TextEditingController());
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        icon: ctrl.isTesting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Testar'),
                        onPressed: ctrl.args.isEmpty || ctrl.isTesting
                            ? null
                            : () => _runTest(i),
                      ),
                    ),
                  ],
                ),
                if (ctrl.testResult != null) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    initiallyExpanded: true,
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      ctrl.testResult!.started
                          ? 'Exit code: ${ctrl.testResult!.exitCode}'
                          : 'Não executou',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: ctrl.testResult!.error != null
                        ? Text(ctrl.testResult!.error!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 11))
                        : null,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    children: [
                      if (ctrl.testResult!.stdout.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4)),
                          child: SelectableText(ctrl.testResult!.stdout,
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.white70)),
                        ),
                      if (ctrl.testResult!.stderr.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(4)),
                          child: SelectableText(ctrl.testResult!.stderr,
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Colors.redAccent)),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => ctrl.testResult = null),
                          child: const Text('Fechar',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );

            if (isSingle) {
              return content;
            } else {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: content,
              );
            }
          }),
        ],
        if (_commands.length < 10)
          OutlinedButton.icon(
            icon: const Icon(Icons.add_to_photos, size: 16),
            label: const Text('Adicionar comando na sequência'),
            onPressed: () {
              setState(() {
                _commands.add(_CmdCtrl([]));
              });
              _fireChanged();
            },
          ),
      ],
    );
  }
}

class _ArgTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool isFirst;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;

  const _ArgTextField({
    required this.controller,
    required this.isFirst,
    required this.onChanged,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                hintText: isFirst ? 'Comando (ex: code)' : 'Argumento',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDeleted,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
