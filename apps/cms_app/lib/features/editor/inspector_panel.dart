import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'editor_controller.dart';
import 'emoji_picker.dart';
import 'brightness_picker.dart';
import 'process_discovery.dart';

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
      StatTile() => _ShortcutInspector(tile: tile, state: state),
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
    } else if (tile is StatTile) {
      final s = tile as StatTile;
      newTile = StatTile(
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

enum _ShortcutBehavior {
  builtin,
  hotkey,
  custom,
}

const _builtinMediaActions = <String, String>{
  'play_pause': 'Reproduzir / Pausar',
  'next': 'Próxima faixa',
  'prev': 'Faixa anterior',
};

class _ShortcutInspectorState extends ConsumerState<_ShortcutInspector> {
  late _ShortcutBehavior _behavior;

  static _ShortcutBehavior _detectBehavior(
      Tile tile, Map<String, List<List<String>>> bindings) {
    if (tile is! ShortcutTile) return _ShortcutBehavior.custom;
    if (_builtinMediaActions.containsKey(tile.id)) {
      return _ShortcutBehavior.builtin;
    }
    final cmds = bindings[tile.id];
    if (cmds != null &&
        cmds.length == 1 &&
        cmds.first.isNotEmpty &&
        cmds.first.first == '__sendkeys__') {
      return _ShortcutBehavior.hotkey;
    }
    return _ShortcutBehavior.custom;
  }

  @override
  void initState() {
    super.initState();
    _behavior = _detectBehavior(widget.tile, widget.state.layout.bindings);
  }

  @override
  void didUpdateWidget(covariant _ShortcutInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tile.id != widget.tile.id ||
        oldWidget.state.layout.bindings != widget.state.layout.bindings) {
      _behavior = _detectBehavior(widget.tile, widget.state.layout.bindings);
    }
  }

  Tile _updateTile({String? id, String? icon, String? label}) {
    final current = widget.tile;
    if (current is ShortcutTile) {
      return current.copyWith(id: id, icon: icon, label: label);
    } else if (current is SliderTile) {
      return current.copyWith(id: id, icon: icon, label: label);
    } else if (current is StatTile) {
      return current.copyWith(id: id, icon: icon, label: label);
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(editorControllerProvider.notifier);
    final dispatcher = ref.read(agentRuntimeProvider).dispatcher;

    final isShortcut = widget.tile is ShortcutTile;
    final isStat = widget.tile is StatTile;

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
        if (!isShortcut || _behavior != _ShortcutBehavior.builtin) ...[
          const Divider(height: 32, color: Colors.white10),
          _IdField(
            initialValue: widget.tile.id,
            hasBinding: widget.state.layout.bindings.containsKey(widget.tile.id),
            existingIds: widget.state.layout.pages.values
                .expand((list) => list)
                .map((t) => t.id)
                .toSet(),
            onSubmitted: (newId) {
              notifier.replaceTile(
                  widget.state.currentPage, widget.tile.id, _updateTile(id: newId));
            },
          ),
        ],
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
            _AppVolumeEditor(
              currentMatch: (widget.tile as SliderTile).source.match,
              audio: ref.read(agentRuntimeProvider).audio,
              onChanged: (val) {
                final current = widget.tile as SliderTile;
                notifier.upsertTile(
                  widget.state.currentPage,
                  SliderTile(
                    id: current.id,
                    icon: current.icon,
                    label: current.label,
                    source: current.source.copyWith(
                        match: val.trim(), clearMatch: val.trim().isEmpty),
                  ),
                );
              },
              onApplyPreset: (preset) {
                final current = widget.tile as SliderTile;
                final newLabel = (current.label.isEmpty || current.label == 'Novo Slider')
                    ? 'Volume ${preset.name}'
                    : current.label;
                final newIcon = (current.icon.isEmpty || current.icon == '🎚️')
                    ? preset.icon
                    : current.icon;
                notifier.upsertTile(
                  widget.state.currentPage,
                  SliderTile(
                    id: current.id,
                    icon: newIcon,
                    label: newLabel,
                    source: current.source.copyWith(match: preset.match),
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
        if (isStat) ...[
          const Divider(height: 32, color: Colors.white10),
          const Text('Fonte do Stat',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: (widget.tile as StatTile).source.kind,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: StatSource.kindCpu, child: Text('CPU')),
              DropdownMenuItem(value: StatSource.kindRam, child: Text('RAM')),
              DropdownMenuItem(
                  value: StatSource.kindDisk, child: Text('Disco')),
            ],
            onChanged: (kind) {
              if (kind == null) return;
              final current = widget.tile as StatTile;

              String newField = 'load';
              String newUnit = '%';
              if (kind == StatSource.kindRam) {
                newField = 'percent';
              } else if (kind == StatSource.kindDisk) {
                newField = 'percent';
              }

              notifier.upsertTile(
                widget.state.currentPage,
                current.copyWith(
                    source: current.source
                        .copyWith(kind: kind, field: newField, unit: newUnit)),
              );
            },
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final kind = (widget.tile as StatTile).source.kind;
            List<String> fields = [];
            if (kind == StatSource.kindCpu) {
              fields = ['load', 'temp', 'freq_mhz'];
            } else if (kind == StatSource.kindRam) {
              fields = ['percent', 'used_mb', 'total_mb'];
            } else if (kind == StatSource.kindDisk) {
              fields = ['percent', 'used_gb', 'total_gb'];
            }

            return DropdownButtonFormField<String>(
              initialValue: (widget.tile as StatTile).source.field,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Campo',
                border: OutlineInputBorder(),
              ),
              items: fields
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (field) {
                if (field == null) return;
                final current = widget.tile as StatTile;

                String newUnit = '%';
                if (field == 'temp') newUnit = '°C';
                if (field == 'freq_mhz') newUnit = 'MHz';
                if (field == 'used_mb' || field == 'total_mb') newUnit = 'MB';
                if (field == 'used_gb' || field == 'total_gb') newUnit = 'GB';

                notifier.upsertTile(
                  widget.state.currentPage,
                  current.copyWith(
                      source:
                          current.source.copyWith(field: field, unit: newUnit)),
                );
              },
            );
          }),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: (widget.tile as StatTile).source.unit,
            decoration: const InputDecoration(
              labelText: 'Unidade (sufixo)',
              border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (value) {
              final current = widget.tile as StatTile;
              notifier.upsertTile(
                widget.state.currentPage,
                current.copyWith(
                    source: current.source.copyWith(unit: value.trim())),
              );
            },
          ),
        ],
        if (isShortcut) ...[
          const SizedBox(height: 16),
          const Text('Comportamento',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<_ShortcutBehavior>(
            segments: const [
              ButtonSegment(
                value: _ShortcutBehavior.builtin,
                label: Text('Mídia', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.music_note, size: 16),
              ),
              ButtonSegment(
                value: _ShortcutBehavior.hotkey,
                label: Text('Teclado', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.keyboard, size: 16),
              ),
              ButtonSegment(
                value: _ShortcutBehavior.custom,
                label: Text('Terminal', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.terminal, size: 16),
              ),
            ],
            selected: {_behavior},
            onSelectionChanged: (newSelection) {
              final newBehavior = newSelection.first;
              setState(() => _behavior = newBehavior);

              if (newBehavior == _ShortcutBehavior.builtin) {
                const targetAction = 'play_pause';
                notifier.setBinding(widget.tile.id, null);
                notifier.replaceTile(
                    widget.state.currentPage, widget.tile.id, _updateTile(id: targetAction));
                notifier.selectTile(targetAction);
              } else if (newBehavior == _ShortcutBehavior.hotkey) {
                String targetId = widget.tile.id;
                if (_builtinMediaActions.containsKey(targetId)) {
                  targetId = widget.state.layout.nextTileId('shortcut');
                  notifier.replaceTile(
                      widget.state.currentPage, widget.tile.id, _updateTile(id: targetId));
                  notifier.selectTile(targetId);
                }
                final existing = widget.state.layout.bindings[targetId];
                final currentCombo = (existing != null &&
                        existing.isNotEmpty &&
                        existing.first.length > 1 &&
                        existing.first.first == '__sendkeys__')
                    ? existing.first[1]
                    : 'ctrl+shift+esc';
                notifier.setBinding(
                    targetId, [
                  ['__sendkeys__', currentCombo]
                ]);
              } else if (newBehavior == _ShortcutBehavior.custom) {
                String targetId = widget.tile.id;
                if (_builtinMediaActions.containsKey(targetId)) {
                  targetId = widget.state.layout.nextTileId('shortcut');
                  notifier.replaceTile(
                      widget.state.currentPage, widget.tile.id, _updateTile(id: targetId));
                  notifier.selectTile(targetId);
                  notifier.setBinding(targetId, null);
                }
              }
            },
          ),
          const SizedBox(height: 16),
          if (_behavior == _ShortcutBehavior.builtin) ...[
            DropdownButtonFormField<String>(
              initialValue: _builtinMediaActions.containsKey(widget.tile.id)
                  ? widget.tile.id
                  : 'play_pause',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ação de Mídia',
                border: OutlineInputBorder(),
              ),
              items: _builtinMediaActions.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  notifier.setBinding(widget.tile.id, null);
                  notifier.replaceTile(
                      widget.state.currentPage, widget.tile.id, _updateTile(id: val));
                  notifier.selectTile(val);
                }
              },
            ),
            const SizedBox(height: 6),
            Text(
                Platform.isWindows
                    ? 'Esta ação controla o player de mídia nativo via NirCmd.'
                    : 'Esta ação controla o player de mídia ativo via playerctl.',
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ] else if (_behavior == _ShortcutBehavior.hotkey) ...[
            _HotkeyEditor(
              initialCombo: () {
                final b = widget.state.layout.bindings[widget.tile.id];
                if (b != null &&
                    b.isNotEmpty &&
                    b.first.length > 1 &&
                    b.first.first == '__sendkeys__') {
                  return b.first[1];
                }
                return 'ctrl+shift+esc';
              }(),
              onChanged: (combo) {
                if (combo.isEmpty) {
                  notifier.setBinding(widget.tile.id, null);
                } else {
                  notifier.setBinding(
                      widget.tile.id, [
                    ['__sendkeys__', combo]
                  ]);
                }
              },
              onTest: (combo) async {
                return dispatcher.keySender.send(combo);
              },
            ),
          ] else ...[
            if ((widget.state.layout.bindings[widget.tile.id] ?? []).isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nenhum comando adicionado. O botão não fará nada até que você adicione um comando.',
                        style: TextStyle(fontSize: 11, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
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
        _IdField(
          initialValue: tile.id,
          hasBinding: false,
          existingIds: state.layout.pages.values
              .expand((list) => list)
              .map((t) => t.id)
              .toSet(),
          onSubmitted: (newId) {
            notifier.replaceTile(
              state.currentPage,
              tile.id,
              FolderTile(
                id: newId,
                icon: tile.icon,
                label: tile.label,
                target: tile.target,
              ),
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
              notifier.replaceTile(
                state.currentPage,
                tile.id,
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
        _IdField(
          initialValue: tile.id,
          hasBinding: false,
          existingIds: state.layout.pages.values
              .expand((list) => list)
              .map((t) => t.id)
              .toSet(),
          onSubmitted: (newId) {
            notifier.replaceTile(
              state.currentPage,
              tile.id,
              BackTile(id: newId, icon: tile.icon, label: tile.label),
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
  final Set<String> existingIds;
  final ValueChanged<String> onSubmitted;

  const _IdField({
    required this.initialValue,
    required this.hasBinding,
    this.existingIds = const {},
    required this.onSubmitted,
  });

  @override
  State<_IdField> createState() => _IdFieldState();
}

class _IdFieldState extends State<_IdField> {
  late final TextEditingController _ctrl;
  String? _errorText;
  bool _canApply = false;

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
      _canApply = false;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _validate(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorText = 'O ID não pode ser vazio';
        _canApply = false;
      });
      return;
    }
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(trimmed)) {
      setState(() {
        _errorText = 'Apenas letras minúsculas, números, _ e -';
        _canApply = false;
      });
      return;
    }
    if (trimmed != widget.initialValue && widget.existingIds.contains(trimmed)) {
      setState(() {
        _errorText = 'Este ID já está em uso em outro tile';
        _canApply = false;
      });
      return;
    }
    setState(() {
      _errorText = null;
      _canApply = trimmed != widget.initialValue;
    });
  }

  void _apply() {
    _validate(_ctrl.text);
    final trimmed = _ctrl.text.trim();
    if (_errorText == null && trimmed.isNotEmpty && trimmed != widget.initialValue) {
      widget.onSubmitted(trimmed);
      setState(() => _canApply = false);
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
            suffixIcon: _canApply
                ? IconButton(
                    icon: const Icon(Icons.check, color: Colors.greenAccent),
                    tooltip: 'Salvar ID (Enter)',
                    onPressed: _apply,
                  )
                : null,
            border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8))),
            helperText:
                _canApply ? 'Pressione Enter ou clique no ícone para salvar' : null,
          ),
          onChanged: _validate,
          onSubmitted: (_) => _apply(),
        ),
        if (widget.hasBinding) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3))),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.lightBlueAccent, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Este id tem comando configurado. Ao alterar o ID, os comandos serão transferidos automaticamente.',
                        style: TextStyle(
                            color: Colors.lightBlueAccent, fontSize: 11))),
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

class _HotkeyEditor extends StatefulWidget {
  final String initialCombo;
  final ValueChanged<String> onChanged;
  final Future<bool> Function(String combo) onTest;

  const _HotkeyEditor({
    required this.initialCombo,
    required this.onChanged,
    required this.onTest,
  });

  @override
  State<_HotkeyEditor> createState() => _HotkeyEditorState();
}

class _HotkeyEditorState extends State<_HotkeyEditor> {
  late final TextEditingController _ctrl;
  bool _testing = false;
  bool? _testSuccess;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialCombo);
  }

  @override
  void didUpdateWidget(covariant _HotkeyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCombo != widget.initialCombo &&
        _ctrl.text.trim().toLowerCase() !=
            widget.initialCombo.trim().toLowerCase()) {
      _ctrl.text = widget.initialCombo;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _insertModifier(String mod) {
    final cur = _ctrl.text.trim();
    if (cur.isEmpty) {
      _ctrl.text = '$mod+';
    } else if (cur.endsWith('+')) {
      _ctrl.text = '$cur$mod+';
    } else {
      _ctrl.text = '$cur+$mod+';
    }
    _onTextChange(_ctrl.text);
  }

  void _setPreset(String preset) {
    _ctrl.text = preset;
    _onTextChange(preset);
  }

  void _onTextChange(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(_ctrl.text.trim().toLowerCase());
    });
  }

  Future<void> _testKey() async {
    final combo = _ctrl.text.trim();
    if (combo.isEmpty) return;
    setState(() {
      _testing = true;
      _testSuccess = null;
    });
    final ok = await widget.onTest(combo);
    if (mounted) {
      setState(() {
        _testing = false;
        _testSuccess = ok;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _testSuccess = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText: 'Combinação de teclas',
            hintText: 'ex: ctrl+shift+esc, alt+f4, win+d',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                _ctrl.clear();
                _onTextChange('');
              },
            ),
          ),
          onChanged: _onTextChange,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ActionChip(
              label: const Text('+ Ctrl', style: TextStyle(fontSize: 12)),
              onPressed: () => _insertModifier('ctrl'),
            ),
            ActionChip(
              label: const Text('+ Alt', style: TextStyle(fontSize: 12)),
              onPressed: () => _insertModifier('alt'),
            ),
            ActionChip(
              label: const Text('+ Shift', style: TextStyle(fontSize: 12)),
              onPressed: () => _insertModifier('shift'),
            ),
            ActionChip(
              label: const Text('+ Win', style: TextStyle(fontSize: 12)),
              onPressed: () => _insertModifier('win'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Atalhos populares:',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _PresetChip(
                label: 'Alt+F4', onSelected: () => _setPreset('alt+f4')),
            _PresetChip(label: 'Win+D', onSelected: () => _setPreset('win+d')),
            _PresetChip(
                label: 'Ctrl+Shift+Esc',
                onSelected: () => _setPreset('ctrl+shift+esc')),
            _PresetChip(label: 'F11', onSelected: () => _setPreset('f11')),
            _PresetChip(
                label: 'Win+Tab', onSelected: () => _setPreset('win+tab')),
            _PresetChip(
                label: 'Ctrl+W', onSelected: () => _setPreset('ctrl+w')),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _testing || _ctrl.text.trim().isEmpty ? null : _testKey,
          icon: _testing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(_testSuccess == true ? Icons.check : Icons.keyboard,
                  size: 18),
          label: Text(_testing
              ? 'Enviando...'
              : _testSuccess == true
                  ? 'Enviado com sucesso!'
                  : 'Testar tecla no PC'),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onSelected;

  const _PresetChip({required this.label, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
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

class _AppVolumeEditor extends StatefulWidget {
  final String? currentMatch;
  final ValueChanged<String> onChanged;
  final void Function(AppPreset preset)? onApplyPreset;
  final AudioController? audio;

  const _AppVolumeEditor({
    required this.currentMatch,
    required this.onChanged,
    this.onApplyPreset,
    this.audio,
  });

  @override
  State<_AppVolumeEditor> createState() => _AppVolumeEditorState();
}

class _AppVolumeEditorState extends State<_AppVolumeEditor> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  List<String> _runningProcesses = [];
  bool _loadingProcesses = false;
  String? _testMessage;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentMatch ?? '');
    _loadProcesses();
  }

  @override
  void didUpdateWidget(covariant _AppVolumeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentMatch != oldWidget.currentMatch &&
        widget.currentMatch != _controller.text) {
      _controller.text = widget.currentMatch ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProcesses() async {
    setState(() => _loadingProcesses = true);
    try {
      final list = await ProcessDiscovery.getRunningProcesses();
      if (mounted) {
        setState(() {
          _runningProcesses = list;
          _loadingProcesses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProcesses = false);
    }
  }

  Future<void> _runTest() async {
    final match = _controller.text.trim();
    if (match.isEmpty) {
      setState(() => _testMessage = 'Selecione ou digite o nome do app primeiro.');
      return;
    }
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      if (widget.audio != null) {
        await widget.audio!.setAppVolumeByName(match, 50);
        if (mounted) {
          setState(() {
            _testing = false;
            _testMessage =
                'Volume de "$match" ajustado para 50%! Confira no mixer do sistema.';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _testing = false;
            _testMessage = 'Controlador de áudio não inicializado.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testMessage = 'Erro no teste: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Presets Rápidos',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            IconButton(
              icon: _loadingProcesses
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              tooltip: 'Recarregar processos ativos',
              onPressed: _loadingProcesses ? null : _loadProcesses,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ProcessDiscovery.commonPresets.map((preset) {
            final isSelected = _controller.text.toLowerCase() == preset.match.toLowerCase() ||
                _controller.text.toLowerCase() == preset.name.toLowerCase();
            return ActionChip(
              avatar: Text(preset.icon, style: const TextStyle(fontSize: 12)),
              label: Text(preset.name, style: const TextStyle(fontSize: 11)),
              backgroundColor: isSelected ? Colors.deepPurple.shade700 : const Color(0xFF2E2E3E),
              side: BorderSide(
                color: isSelected ? Colors.deepPurpleAccent : Colors.white12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              onPressed: () {
                _controller.text = preset.match;
                widget.onChanged(preset.match);
                widget.onApplyPreset?.call(preset);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focusNode,
          optionsBuilder: (TextEditingValue textVal) {
            final query = textVal.text.trim().toLowerCase();
            final allOptions = <String>{
              ...ProcessDiscovery.commonPresets.map((p) => p.match),
              ..._runningProcesses,
            };
            if (query.isEmpty) {
              return allOptions.take(15);
            }
            return allOptions.where((opt) => opt.toLowerCase().contains(query)).take(15);
          },
          onSelected: (String selection) {
            _controller.text = selection;
            widget.onChanged(selection);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Nome do App (Processo / Executável)',
                hintText: Platform.isWindows
                    ? 'ex: Spotify.exe, Discord.exe, chrome.exe'
                    : 'ex: Spotify, Discord, Firefox',
                border: const OutlineInputBorder(),
                helperText: Platform.isWindows
                    ? 'Nome do .exe no Windows (ex: Spotify.exe)'
                    : 'application.name ou processo no PulseAudio/PipeWire',
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: () {
                    focusNode.requestFocus();
                  },
                ),
              ),
              onChanged: (val) {
                widget.onChanged(val.trim());
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: const Color(0xFF2A2A3C),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 288),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      final isRunning = _runningProcesses.any(
                          (p) => p.toLowerCase() == option.toLowerCase());
                      return InkWell(
                        onTap: () => onSelected(option),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                isRunning ? Icons.circle : Icons.apps,
                                size: 10,
                                color: isRunning ? Colors.greenAccent : Colors.white38,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isRunning)
                                const Text(
                                  'aberto',
                                  style: TextStyle(fontSize: 10, color: Colors.greenAccent),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _testing ? null : _runTest,
          icon: _testing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.volume_up, size: 16),
          label: Text(_testing ? 'Testando...' : 'Testar Volume no PC (50%)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        if (_testMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            _testMessage!,
            style: TextStyle(
              fontSize: 11,
              color: _testMessage!.contains('ajustado')
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
            ),
          ),
        ],
      ],
    );
  }
}

