import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'editor_controller.dart';
import 'emoji_picker.dart';
import 'brightness_picker.dart';
import 'key_combo_helper.dart';
import 'process_discovery.dart';
import 'sound_library_dialog.dart';
import 'widgets/tile_icon_view.dart';
import 'helpers/image_icon_helper.dart';

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
      SoundTile() => _SoundInspector(tile: tile, state: state),
      ToggleTile() => _ToggleInspector(tile: tile, state: state),
      PomodoroTile() => _PomodoroInspector(tile: tile, state: state),
      TodoTile() => _TodoInspector(tile: tile, state: state),
      FolderTile() => _FolderInspector(tile: tile, state: state),
      BackTile() => _BackInspector(tile: tile, state: state),
    };

    return Column(
      children: [
        _TileSizeSelector(tile: tile, currentPage: state.currentPage),
        const Divider(height: 1, thickness: 1, color: Colors.white10),
        Expanded(child: child),
        const Divider(height: 1, thickness: 1, color: Colors.white10),
        _InspectorFooter(tile: tile, state: state),
      ],
    );
  }
}

class _TileSizeSelector extends ConsumerWidget {
  final Tile tile;
  final String currentPage;

  const _TileSizeSelector({required this.tile, required this.currentPage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSize = (tile.width, tile.height);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tamanho do Widget',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<(int, int)>(
            segments: const [
              ButtonSegment<(int, int)>(
                value: (1, 1),
                label: Text('1×1', style: TextStyle(fontSize: 11)),
                tooltip: '1 coluna × 1 linha (Padrão)',
              ),
              ButtonSegment<(int, int)>(
                value: (2, 1),
                label: Text('2×1 ↔', style: TextStyle(fontSize: 11)),
                tooltip: '2 colunas × 1 linha (Horizontal)',
              ),
              ButtonSegment<(int, int)>(
                value: (1, 2),
                label: Text('1×2 ↕', style: TextStyle(fontSize: 11)),
                tooltip: '1 coluna × 2 linhas (Vertical / Fader)',
              ),
              ButtonSegment<(int, int)>(
                value: (2, 2),
                label: Text('2×2 ⤢', style: TextStyle(fontSize: 11)),
                tooltip: '2 colunas × 2 linhas (Grande / Pro)',
              ),
            ],
            selected: {currentSize},
            onSelectionChanged: (newSelection) {
              final selected = newSelection.first;
              final w = selected.$1;
              final h = selected.$2;

              final notifier = ref.read(editorControllerProvider.notifier);
              notifier.resizeTile(currentPage, tile.id, w, h);
            },
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorFooter extends ConsumerWidget {
  final Tile tile;
  final EditorState state;

  const _InspectorFooter({required this.tile, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canTest =
        tile is ShortcutTile || tile is SoundTile || tile is ToggleTile;

    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canTest) ...[
            FilledButton.tonalIcon(
              icon: const Icon(Icons.play_arrow_rounded, size: 17),
              label: const Text('Executar agora no PC'),
              onPressed: () async {
                final runtime = ref.read(agentRuntimeProvider);
                await runtime.dispatcher.dispatch(
                  AgentCommand(tile.id, {'action': tile.id}),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ação "${tile.label}" executada'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.content_copy, size: 15),
                  label: const Text('Duplicar'),
                  onPressed: () => _handleDuplicate(ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Excluir'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.18),
                    foregroundColor: Colors.redAccent,
                  ),
                  onPressed: () => _handleDelete(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleDuplicate(WidgetRef ref) {
    final notifier = ref.read(editorControllerProvider.notifier);
    final allIds = state.layout.allTileIds;

    String newId = '${tile.id}_copy';
    int counter = 2;
    while (allIds.contains(newId)) {
      newId = '${tile.id}_copy_$counter';
      counter++;
    }

    final Tile newTile = tile.copyWithPosition(clearCoords: true).copyWithCommon(id: newId);

    notifier.upsertTile(state.currentPage, newTile);
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

const _builtinActions = <String, String>{
  'stop_sound': '⏹️ Parar todos os sons (Sound Pad)',
  'play_pause': '⏯️ Reproduzir / Pausar (Mídia)',
  'next': '⏭️ Próxima faixa (Mídia)',
  'prev': '⏮️ Faixa anterior (Mídia)',
  'mute_master': '🔇 Silenciar / Restaurar Áudio Master',
  'toggle_mic_mute': '🎙️ Silenciar / Ativar Microfone',
  'vol_up': '🔊 Aumentar Volume (+5%)',
  'vol_down': '🔉 Diminuir Volume (-5%)',
  'window_always_on_top': '📌 Fixar Janela Atual no Topo',
  'clipboard_sync_to_tablet': '📋 Enviar Clipboard do PC ao Tablet',
  'lock_screen': '🔒 Bloquear Tela do PC',
  'open_cms': '🖥️ Abrir Janela do CMS no PC',
  'remote_search_prompt': '🔍 Busca rápida no PC (Spotlight)',
  'remote_todo_prompt': '✅ Nova Tarefa no PC (Spotlight)',
  'pomodoro_toggle': '⏱️ Pomodoro: Iniciar / Pausar',
  'pomodoro_skip': '⏭️ Pomodoro: Pular Fase',
  'pomodoro_reset': '🔄 Pomodoro: Reiniciar',
};

class _ShortcutInspectorState extends ConsumerState<_ShortcutInspector> {
  late _ShortcutBehavior _behavior;

  static _ShortcutBehavior _detectBehavior(
      Tile tile, Map<String, List<List<String>>> bindings) {
    if (tile is! ShortcutTile) return _ShortcutBehavior.custom;
    if (_builtinActions.containsKey(tile.id)) {
      return _ShortcutBehavior.builtin;
    }
    final cmds = bindings[tile.id];
    if (cmds != null && cmds.isNotEmpty) {
      if (cmds.length == 1 &&
          cmds.first.isNotEmpty &&
          cmds.first.first == '__sendkeys__') {
        return _ShortcutBehavior.hotkey;
      }
      if (cmds.length == 1 &&
          cmds.first.isNotEmpty &&
          (cmds.first.first == '__builtin__' || _builtinActions.containsKey(cmds.first.first))) {
        return _ShortcutBehavior.builtin;
      }
    }
    final labelNorm = tile.label.trim().toLowerCase();
    if (labelNorm == 'parar sons' ||
        labelNorm == 'parar tudo' ||
        labelNorm == 'parar som' ||
        labelNorm == 'stop sound' ||
        labelNorm == 'stop sounds') {
      return _ShortcutBehavior.builtin;
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

  Tile _updateTile({
    String? id,
    String? icon,
    String? staticIcon,
    String? animationMode,
    String? label,
  }) {
    final current = widget.tile;
    if (current is ShortcutTile) {
      return current.copyWith(
        id: id,
        icon: icon,
        staticIcon: staticIcon,
        animationMode: animationMode,
        label: label,
      );
    } else if (current is SliderTile) {
      return current.copyWith(
        id: id,
        icon: icon,
        staticIcon: staticIcon,
        animationMode: animationMode,
        label: label,
      );
    } else if (current is StatTile) {
      return current.copyWith(
        id: id,
        icon: icon,
        staticIcon: staticIcon,
        animationMode: animationMode,
        label: label,
      );
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
          staticIcon: widget.tile.staticIcon,
          animationMode: widget.tile.animationMode,
          isSoundOrToggle: false,
          onPicked: (newIcon, newStatic) {
            notifier.upsertTile(
              widget.state.currentPage,
              _updateTile(icon: newIcon, staticIcon: newStatic),
            );
          },
          onAnimationModeChanged: (mode, newStatic) {
            notifier.upsertTile(
              widget.state.currentPage,
              _updateTile(animationMode: mode, staticIcon: newStatic),
            );
          },
        ),
        if (!isShortcut || _behavior != _ShortcutBehavior.builtin) ...[
          const Divider(height: 32, color: Colors.white10),
          _IdField(
            initialValue: widget.tile.id,
            hasBinding: widget.state.layout.bindings.containsKey(widget.tile.id),
            existingIds: widget.state.layout.allTileIds,
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
              DropdownMenuItem(
                value: SliderSource.kindSoundVolume,
                child: Text('Volume do Sound Pad'),
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
                current.copyWith(source: newSource),
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
              SliderSource.kindSoundVolume) ...[
            const SizedBox(height: 8),
            const Text(
              'Ajusta o volume de reprodução dos sons do Sound Pad.',
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
                  current.copyWith(
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
                  current.copyWith(
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
                  current.copyWith(
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
              DropdownMenuItem(
                  value: 'net', child: Text('Rede (Download / Upload)')),
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
              } else if (kind == 'net') {
                newField = 'rx_kbps';
                newUnit = ' KB/s';
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
            } else if (kind == 'net') {
              fields = ['rx_kbps', 'tx_kbps'];
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
                const targetAction = 'stop_sound';
                final hasConflict = widget.state.layout.pages[widget.state.currentPage]!
                    .any((t) => t.id == targetAction && t != widget.tile);
                if (!hasConflict) {
                  notifier.setBinding(widget.tile.id, null);
                  notifier.replaceTile(
                      widget.state.currentPage, widget.tile.id, _updateTile(id: targetAction, icon: '⏹️', label: 'Parar Sons'));
                  notifier.selectTile(targetAction);
                } else {
                  notifier.setBinding(widget.tile.id, [
                    ['__builtin__', targetAction]
                  ]);
                }
              } else if (newBehavior == _ShortcutBehavior.hotkey) {
                String targetId = widget.tile.id;
                if (_builtinActions.containsKey(targetId)) {
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
                if (_builtinActions.containsKey(targetId)) {
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
            Builder(
              builder: (context) {
                String currentBuiltin = 'stop_sound';
                if (_builtinActions.containsKey(widget.tile.id)) {
                  currentBuiltin = widget.tile.id;
                } else {
                  final b = widget.state.layout.bindings[widget.tile.id];
                  if (b != null && b.isNotEmpty && b.first.isNotEmpty) {
                    if (b.first.first == '__builtin__' && b.first.length > 1 && _builtinActions.containsKey(b.first[1])) {
                      currentBuiltin = b.first[1];
                    } else if (_builtinActions.containsKey(b.first.first)) {
                      currentBuiltin = b.first.first;
                    }
                  }
                }

                return DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: currentBuiltin,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ação Pré-determinada',
                    border: OutlineInputBorder(),
                  ),
                  items: _builtinActions.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final hasConflict = widget.state.layout.pages[widget.state.currentPage]!
                          .any((t) => t.id == val && t != widget.tile);
                      if (!hasConflict) {
                        notifier.setBinding(widget.tile.id, null);
                        notifier.replaceTile(
                            widget.state.currentPage, widget.tile.id, _updateTile(id: val));
                        notifier.selectTile(val);
                      } else {
                        notifier.setBinding(widget.tile.id, [
                          ['__builtin__', val]
                        ]);
                      }
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final currentId = widget.tile.id;
                final b = widget.state.layout.bindings[currentId];
                final isStop = currentId == 'stop_sound' || (b != null && b.isNotEmpty && b.first.contains('stop_sound'));
                final isSearch = currentId == 'remote_search_prompt' || (b != null && b.isNotEmpty && b.first.contains('remote_search_prompt'));
                String desc;
                if (isStop) {
                  desc = 'Interrompe imediatamente a reprodução de todos os sons do Sound Pad.';
                } else if (isSearch) {
                  desc = 'Abre a barra de busca rápida (Spotlight) no PC.';
                } else {
                  desc = Platform.isWindows
                      ? 'Controla o player de mídia nativo via NirCmd.'
                      : 'Controla o player de mídia ativo via playerctl.';
                }
                return Text(desc, style: const TextStyle(fontSize: 11, color: Colors.white54));
              },
            ),
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
              tile.copyWith(label: newLabel),
            );
          },
        ),
        const SizedBox(height: 16),
        _IconField(
          icon: tile.icon,
          staticIcon: tile.staticIcon,
          animationMode: tile.animationMode,
          onPicked: (newIcon, newStatic) {
            notifier.upsertTile(
              state.currentPage,
              tile.copyWith(
                icon: newIcon,
                staticIcon: newStatic,
              ),
            );
          },
          onAnimationModeChanged: (mode, newStatic) {
            notifier.upsertTile(
              state.currentPage,
              tile.copyWith(animationMode: mode, staticIcon: newStatic),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        _IdField(
          initialValue: tile.id,
          hasBinding: false,
          existingIds: state.layout.allTileIds,
          onSubmitted: (newId) {
            notifier.replaceTile(
              state.currentPage,
              tile.id,
              tile.copyWith(id: newId),
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
                tile.copyWith(target: newTarget),
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
              tile.copyWith(label: newLabel),
            );
          },
        ),
        const SizedBox(height: 16),
        _IconField(
          icon: tile.icon,
          staticIcon: tile.staticIcon,
          animationMode: tile.animationMode,
          onPicked: (newIcon, newStatic) {
            notifier.upsertTile(
              state.currentPage,
              tile.copyWith(
                icon: newIcon,
                staticIcon: newStatic,
              ),
            );
          },
          onAnimationModeChanged: (mode, newStatic) {
            notifier.upsertTile(
              state.currentPage,
              tile.copyWith(animationMode: mode, staticIcon: newStatic),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        _IdField(
          initialValue: tile.id,
          hasBinding: false,
          existingIds: state.layout.allTileIds,
          onSubmitted: (newId) {
            notifier.replaceTile(
              state.currentPage,
              tile.id,
              tile.copyWith(id: newId),
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
  final String? staticIcon;
  final String? animationMode;
  final bool isSoundOrToggle;
  final void Function(String icon, String? staticIcon)? onPicked;
  final void Function(String mode, String? staticIcon)? onAnimationModeChanged;

  const _IconField({
    required this.icon,
    this.staticIcon,
    this.animationMode,
    this.isSoundOrToggle = false,
    this.onPicked,
    this.onAnimationModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isGif = ImageIconHelper.isGif(icon);
    final currentMode = animationMode ?? 'always';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Ícone', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                if (onPicked == null) return;
                final picked = await showEmojiPicker(
                  context,
                  current: icon,
                  currentStatic: staticIcon,
                );
                if (picked != null) {
                  onPicked!(picked.icon, picked.staticIcon);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TileIconView(
                  icon: icon,
                  staticIcon: staticIcon,
                  animationMode: currentMode,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
        if (isGif && onAnimationModeChanged != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: (currentMode == 'while_playing' && !isSoundOrToggle)
                ? 'always'
                : currentMode,
            decoration: const InputDecoration(
              labelText: 'Comportamento da Animação GIF',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(
                value: 'always',
                child: Text('Rodando sempre (Loop contínuo)'),
              ),
              const DropdownMenuItem(
                value: 'on_tap',
                child: Text('Ao tocar no botão (Feedback)'),
              ),
              if (isSoundOrToggle)
                const DropdownMenuItem(
                  value: 'while_playing',
                  child: Text('Enquanto estiver tocando/ativo'),
                ),
            ],
            onChanged: (val) async {
              if (val != null) {
                String? newStatic = staticIcon;
                if (val != 'always' && (newStatic == null || newStatic.isEmpty)) {
                  final bytes = ImageIconHelper.extractBytes(icon);
                  if (bytes != null) {
                    try {
                      newStatic = await ImageIconHelper.processImageBytes(bytes, targetSize: 96);
                    } catch (_) {}
                  }
                }
                onAnimationModeChanged?.call(val, newStatic);
              }
            },
          ),
        ],
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
  final FocusNode _recordFocusNode = FocusNode();
  bool _recording = false;
  bool _testing = false;
  bool? _testSuccess;
  Timer? _debounce;
  String? _recordedFeedback;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: KeyComboHelper.normalize(widget.initialCombo));
  }

  @override
  void didUpdateWidget(covariant _HotkeyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final normalizedInitial = KeyComboHelper.normalize(widget.initialCombo);
    if (oldWidget.initialCombo != widget.initialCombo &&
        KeyComboHelper.normalize(_ctrl.text) != normalizedInitial) {
      _ctrl.text = normalizedInitial;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recordFocusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _recordedFeedback = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordFocusNode.requestFocus();
    });
  }

  void _stopRecording() {
    setState(() {
      _recording = false;
    });
  }

  void _onKeyEvent(KeyEvent event) {
    if (!_recording) return;
    if (event is! KeyDownEvent) return;

    // Se pressionar Escape isolado, cancela a gravação
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      _stopRecording();
      return;
    }

    final combo = KeyComboHelper.fromKeyEvent(event);
    if (combo != null && combo.isNotEmpty) {
      final isOnlyMod = KeyComboHelper.canonicalModifiers.contains(combo) ||
          combo.split('+').every((k) => KeyComboHelper.canonicalModifiers.contains(k));

      _ctrl.text = combo;
      _onTextChange(combo);

      // Se pressionou uma tecla principal (não apenas modificador), conclui
      if (!isOnlyMod) {
        setState(() {
          _recording = false;
          _recordedFeedback = 'Gravado: ${KeyComboHelper.formatDisplay(combo)}';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _recordedFeedback = null);
        });
      }
    }
  }

  void _toggleModifier(String mod) {
    final updated = KeyComboHelper.toggleModifier(_ctrl.text, mod);
    _ctrl.text = updated;
    _onTextChange(updated);
  }

  void _setPreset(String preset) {
    final norm = KeyComboHelper.normalize(preset);
    _ctrl.text = norm;
    _onTextChange(norm);
  }

  void _onTextChange(String text) {
    final normalized = KeyComboHelper.normalize(text);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(normalized);
    });
    setState(() {});
  }

  Future<void> _testKey() async {
    final combo = KeyComboHelper.normalize(_ctrl.text);
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
    final normalizedCombo = KeyComboHelper.normalize(_ctrl.text);
    final displayCombo = KeyComboHelper.formatDisplay(_ctrl.text);
    final isSoloWin = normalizedCombo == 'win';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Botão de Gravação de Teclas
        KeyboardListener(
          focusNode: _recordFocusNode,
          onKeyEvent: _onKeyEvent,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: _recording
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Pressione as teclas no teclado...\n(ESC para cancelar)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _stopRecording,
                          child: const Text('Cancelar',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  )
                : OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF89B4FA)),
                    ),
                    onPressed: _startRecording,
                    icon: const Icon(Icons.fiber_manual_record,
                        size: 16, color: Color(0xFF89B4FA)),
                    label: const Text(
                      'Gravar Teclas Pressionadas',
                      style: TextStyle(
                          color: Color(0xFF89B4FA),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        ),

        if (_recordedFeedback != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _recordedFeedback!,
              style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
              textAlign: TextAlign.center,
            ),
          ),

        // Visualização das Teclas Atuais (Kbd Badges)
        if (displayCombo.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: _buildKbdBadges(displayCombo),
            ),
          ),
        ],

        // Campo de Texto de Digitação Livre (com auto-normalização)
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText: 'Combinação de teclas',
            hintText: 'ex: ctrl+shift+esc, alt+f4, win+d',
            helperText: 'Case-insensitive (Win, win, super são aceitos)',
            helperStyle: const TextStyle(fontSize: 10, color: Colors.white54),
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
        const SizedBox(height: 10),

        // Chips Inteligentes de Modificadores (Sem + no início, alternam estado)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildModifierChip('ctrl', 'Ctrl'),
            _buildModifierChip('alt', 'Alt'),
            _buildModifierChip('shift', 'Shift'),
            _buildModifierChip('win', 'Win / Super'),
          ],
        ),

        // Dica contextual para a tecla Win/Super
        if (isSoloWin) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.lightBlueAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No Linux (Hyprland) e Windows, a tecla Win costuma ser combinada com outra tecla (ex: Win+D, Win+Space, Win+Enter).',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],

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

  Widget _buildModifierChip(String mod, String label) {
    final isActive = KeyComboHelper.hasModifier(_ctrl.text, mod);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isActive,
      showCheckmark: false,
      selectedColor: const Color(0xFF89B4FA).withValues(alpha: 0.3),
      side: BorderSide(
        color: isActive ? const Color(0xFF89B4FA) : Colors.white24,
      ),
      onSelected: (_) => _toggleModifier(mod),
    );
  }

  List<Widget> _buildKbdBadges(String displayCombo) {
    final parts = displayCombo.split(' + ');
    final widgets = <Widget>[];

    for (int i = 0; i < parts.length; i++) {
      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF89B4FA), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            parts[i],
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCDD6F4),
            ),
          ),
        ),
      );
      if (i < parts.length - 1) {
        widgets.add(const Text('+',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.bold)));
      }
    }
    return widgets;
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
        if (_commands.length < 10) ...[
          const SizedBox(height: 4),
          const Text(
            'Adicionar passo na macro:',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.terminal, size: 14),
                label: const Text('Shell', style: TextStyle(fontSize: 11.5)),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _commands.add(_CmdCtrl([])));
                  _fireChanged();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.language, size: 14),
                label: const Text('Abrir URL', style: TextStyle(fontSize: 11.5)),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _commands
                      .add(_CmdCtrl(['__open_url__', 'https://'])));
                  _fireChanged();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.keyboard_alt_outlined, size: 14),
                label: const Text('Texto', style: TextStyle(fontSize: 11.5)),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _commands
                      .add(_CmdCtrl(['__type_text__', 'Texto aqui'])));
                  _fireChanged();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.timer_outlined, size: 14),
                label: const Text('Delay', style: TextStyle(fontSize: 11.5)),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _commands.add(_CmdCtrl(['__delay__', '500'])));
                  _fireChanged();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.webhook_outlined, size: 14),
                label: const Text('Webhook', style: TextStyle(fontSize: 11.5)),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _commands.add(_CmdCtrl([
                        '__http__',
                        'POST',
                        'http://127.0.0.1:8123/api/webhook',
                        '{}',
                      ])));
                  _fireChanged();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.keyboard, size: 14),
                label: const Text('Tecla', style: TextStyle(fontSize: 11.5)),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => _commands
                      .add(_CmdCtrl(['__sendkeys__', 'ctrl+shift+m'])));
                  _fireChanged();
                },
              ),
            ],
          ),
        ],
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
      if (widget.audio != null) {
        await widget.audio!.refresh();
      }
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
    final activeAudioApps = widget.audio?.apps ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeAudioApps.isNotEmpty) ...[
          const Row(
            children: [
              Text(
                'Apps com Áudio Ativo',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: activeAudioApps.map((app) {
              final isSelected = _controller.text.toLowerCase() == app.id.toLowerCase() ||
                  _controller.text.toLowerCase() == app.name.toLowerCase();
              return ActionChip(
                avatar: const Text('🔊', style: TextStyle(fontSize: 12)),
                label: Text('${app.name} (${app.volume}%)', style: const TextStyle(fontSize: 11)),
                backgroundColor: isSelected ? Colors.green.shade800 : const Color(0xFF1E3A2B),
                side: BorderSide(
                  color: isSelected ? Colors.greenAccent : Colors.white12,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                onPressed: () {
                  _controller.text = app.id;
                  widget.onChanged(app.id);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
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
            final activeIds = activeAudioApps.map((a) => a.id).toList();
            final allOptions = <String>{
              ...activeIds,
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

class _SoundInspector extends ConsumerStatefulWidget {
  final SoundTile tile;
  final EditorState state;

  const _SoundInspector({required this.tile, required this.state});

  @override
  ConsumerState<_SoundInspector> createState() => _SoundInspectorState();
}

class _SoundInspectorState extends ConsumerState<_SoundInspector> {
  List<SoundItem> _sounds = [];
  bool _isLoading = true;
  bool _isPlaying = false;
  StreamSubscription<SoundPlaybackState>? _soundSub;

  @override
  void initState() {
    super.initState();
    _loadSounds();
    final runtime = ref.read(agentRuntimeProvider);
    _isPlaying = runtime.sound?.current.soundId == widget.tile.soundId &&
        (runtime.sound?.current.isPlaying ?? false);

    _soundSub = runtime.sound?.stateChanges.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.isPlaying && state.soundId == widget.tile.soundId;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _SoundInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tile.soundId != widget.tile.soundId) {
      _loadSounds();
      final runtime = ref.read(agentRuntimeProvider);
      _isPlaying = runtime.sound?.current.soundId == widget.tile.soundId &&
          (runtime.sound?.current.isPlaying ?? false);
    }
  }

  @override
  void dispose() {
    _soundSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSounds() async {
    final repo = ref.read(soundLibraryRepositoryProvider);
    final list = await repo.listSounds();
    if (mounted) {
      setState(() {
        _sounds = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePreview() async {
    final runtime = ref.read(agentRuntimeProvider);
    if (_isPlaying) {
      await runtime.sound?.stop();
    } else {
      await runtime.sound?.play(widget.tile.soundId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(editorControllerProvider.notifier);
    final existingIds = widget.state.layout.allTileIds;

    final soundExists = _sounds.any((s) => s.id == widget.tile.soundId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LabelField(
          initialValue: widget.tile.label,
          onSubmitted: (newLabel) {
            notifier.upsertTile(
              widget.state.currentPage,
              widget.tile.copyWith(label: newLabel),
            );
          },
        ),
        const SizedBox(height: 16),
        _IconField(
          icon: widget.tile.icon,
          staticIcon: widget.tile.staticIcon,
          animationMode: widget.tile.animationMode,
          isSoundOrToggle: true,
          onPicked: (newIcon, newStatic) {
            notifier.upsertTile(
              widget.state.currentPage,
              widget.tile.copyWith(
                icon: newIcon,
                staticIcon: newStatic,
              ),
            );
          },
          onAnimationModeChanged: (mode, newStatic) {
            notifier.upsertTile(
              widget.state.currentPage,
              widget.tile.copyWith(animationMode: mode, staticIcon: newStatic),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        _IdField(
          initialValue: widget.tile.id,
          hasBinding: false,
          existingIds: existingIds,
          onSubmitted: (newId) {
            notifier.replaceTile(
              widget.state.currentPage,
              widget.tile.id,
              widget.tile.copyWith(id: newId),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        const Text('Som da Biblioteca',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (!soundExists && !_isLoading) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Arquivo "${widget.tile.soundId}" não encontrado na biblioteca deste PC.',
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: soundExists ? widget.tile.soundId : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                hint: const Text('Selecione um som'),
                items: _sounds
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (newSoundId) {
                  if (newSoundId != null &&
                      newSoundId != widget.tile.soundId) {
                    notifier.upsertTile(
                      widget.state.currentPage,
                      widget.tile.copyWith(soundId: newSoundId),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
              tooltip: _isPlaying ? 'Parar som' : 'Ouvir prévia no PC',
              onPressed: soundExists ? _togglePreview : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.library_music, size: 16),
          label: const Text('Gerenciar Biblioteca de Sons'),
          onPressed: () async {
            final selected = await showSoundLibraryDialog(
              context: context,
              ref: ref,
              selectMode: true,
            );
            if (selected != null) {
              await _loadSounds();
              notifier.upsertTile(
                widget.state.currentPage,
                widget.tile.copyWith(
                  soundId: selected.id,
                  label: widget.tile.label == 'Novo Som'
                      ? selected.name
                      : widget.tile.label,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class _ToggleInspector extends ConsumerStatefulWidget {
  final ToggleTile tile;
  final EditorState state;

  const _ToggleInspector({required this.tile, required this.state});

  @override
  ConsumerState<_ToggleInspector> createState() => _ToggleInspectorState();
}

class _ToggleInspectorState extends ConsumerState<_ToggleInspector> {
  String _selectedState = 'a'; // 'a' ou 'b'

  _ShortcutBehavior _detectBehavior(String suffix) {
    final key = '${widget.tile.id}:$suffix';
    final cmds = widget.state.layout.bindings[key];
    if (cmds != null &&
        cmds.length == 1 &&
        cmds.first.isNotEmpty &&
        cmds.first.first == '__sendkeys__') {
      return _ShortcutBehavior.hotkey;
    }
    return _ShortcutBehavior.custom;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(editorControllerProvider.notifier);
    final dispatcher = ref.read(agentRuntimeProvider).dispatcher;
    final existingIds = widget.state.layout.allTileIds;

    final isStateA = _selectedState == 'a';
    final currentStateConfig = isStateA ? widget.tile.stateA : widget.tile.stateB;
    final bindingKey = '${widget.tile.id}:$_selectedState';
    final behavior = _detectBehavior(_selectedState);
    final currentCmds = widget.state.layout.bindings[bindingKey] ?? const [];

    final hasAnyBinding = widget.state.layout.bindings.containsKey('${widget.tile.id}:a') ||
        widget.state.layout.bindings.containsKey('${widget.tile.id}:b');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _IdField(
          initialValue: widget.tile.id,
          hasBinding: hasAnyBinding,
          existingIds: existingIds,
          onSubmitted: (newId) {
            notifier.replaceTile(widget.state.currentPage, widget.tile.id,
                widget.tile.copyWith(id: newId));
            notifier.selectTile(newId);
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Estado Inicial',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'a',
              label: Text(
                'Estado A (${widget.tile.stateA.label.isEmpty ? "A" : widget.tile.stateA.label})',
                style: const TextStyle(fontSize: 11),
              ),
            ),
            ButtonSegment(
              value: 'b',
              label: Text(
                'Estado B (${widget.tile.stateB.label.isEmpty ? "B" : widget.tile.stateB.label})',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
          selected: {widget.tile.initialState.toLowerCase()},
          onSelectionChanged: (set) {
            notifier.upsertTile(
              widget.state.currentPage,
              widget.tile.copyWith(initialState: set.first),
            );
          },
        ),
        const SizedBox(height: 20),
        const Divider(height: 1, color: Colors.white12),
        const SizedBox(height: 16),
        const Text(
          'Configurar Estados',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.tealAccent,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'a',
              icon: Text(widget.tile.stateA.icon.isEmpty ? '💡❌' : widget.tile.stateA.icon),
              label: Text(widget.tile.stateA.label.isEmpty ? 'Estado A' : widget.tile.stateA.label),
            ),
            ButtonSegment(
              value: 'b',
              icon: Text(widget.tile.stateB.icon.isEmpty ? '💡' : widget.tile.stateB.icon),
              label: Text(widget.tile.stateB.label.isEmpty ? 'Estado B' : widget.tile.stateB.label),
            ),
          ],
          selected: {_selectedState},
          onSelectionChanged: (set) => setState(() => _selectedState = set.first),
        ),
        const SizedBox(height: 16),
        _IconField(
          icon: currentStateConfig.icon,
          staticIcon: widget.tile.staticIcon,
          animationMode: widget.tile.animationMode,
          isSoundOrToggle: true,
          onPicked: (newIcon, newStatic) {
            if (isStateA) {
              notifier.upsertTile(
                widget.state.currentPage,
                widget.tile.copyWith(
                  stateA: widget.tile.stateA.copyWith(icon: newIcon),
                  staticIcon: newStatic,
                ),
              );
            } else {
              notifier.upsertTile(
                widget.state.currentPage,
                widget.tile.copyWith(
                  stateB: widget.tile.stateB.copyWith(icon: newIcon),
                  staticIcon: newStatic,
                ),
              );
            }
          },
          onAnimationModeChanged: (mode, newStatic) {
            notifier.upsertTile(
              widget.state.currentPage,
              widget.tile.copyWith(animationMode: mode, staticIcon: newStatic),
            );
          },
        ),
        const SizedBox(height: 12),
        _LabelField(
          initialValue: currentStateConfig.label,
          onSubmitted: (newLabel) {
            if (isStateA) {
              notifier.upsertTile(
                widget.state.currentPage,
                widget.tile.copyWith(
                  stateA: widget.tile.stateA.copyWith(label: newLabel),
                ),
              );
            } else {
              notifier.upsertTile(
                widget.state.currentPage,
                widget.tile.copyWith(
                  stateB: widget.tile.stateB.copyWith(label: newLabel),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.white54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isStateA
                      ? 'Ação executada ao ativar o Estado A (quando o usuário clica estando em B).'
                      : 'Ação executada ao ativar o Estado B (quando o usuário clica estando em A).',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_ShortcutBehavior>(
          segments: const [
            ButtonSegment(
              value: _ShortcutBehavior.hotkey,
              label: Text('Atalho Teclado', style: TextStyle(fontSize: 11)),
              icon: Icon(Icons.keyboard_outlined, size: 15),
            ),
            ButtonSegment(
              value: _ShortcutBehavior.custom,
              label: Text('Comandos Shell', style: TextStyle(fontSize: 11)),
              icon: Icon(Icons.terminal_outlined, size: 15),
            ),
          ],
          selected: {behavior},
          onSelectionChanged: (set) {
            final next = set.first;
            if (next == _ShortcutBehavior.hotkey) {
              notifier.setBinding(bindingKey, [
                ['__sendkeys__', '']
              ]);
            } else {
              notifier.setBinding(bindingKey, [
                ['']
              ]);
            }
          },
        ),
        const SizedBox(height: 16),
        if (behavior == _ShortcutBehavior.hotkey)
          _HotkeyEditor(
            initialCombo: (currentCmds.isNotEmpty &&
                    currentCmds.first.isNotEmpty &&
                    currentCmds.first.first == '__sendkeys__' &&
                    currentCmds.first.length > 1)
                ? currentCmds.first[1]
                : '',
            onChanged: (combo) {
              if (combo.trim().isEmpty) {
                notifier.setBinding(bindingKey, null);
              } else {
                notifier.setBinding(bindingKey, [
                  ['__sendkeys__', combo.trim()]
                ]);
              }
            },
            onTest: (combo) => dispatcher.keySender.send(combo),
          )
        else
          _CommandsEditor(
            initialCommands: currentCmds,
            onChanged: (cmds) {
              notifier.setBinding(bindingKey, cmds);
            },
            dispatcher: dispatcher,
          ),
      ],
    );
  }
}

class _PomodoroInspector extends ConsumerStatefulWidget {
  final PomodoroTile tile;
  final EditorState state;

  const _PomodoroInspector({required this.tile, required this.state});

  @override
  ConsumerState<_PomodoroInspector> createState() => _PomodoroInspectorState();
}

class _PomodoroInspectorState extends ConsumerState<_PomodoroInspector> {
  List<SoundItem> _sounds = [];
  bool _isLoading = true;
  String? _playingSoundId;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    final repo = ref.read(soundLibraryRepositoryProvider);
    final list = await repo.listSounds();
    if (mounted) {
      setState(() {
        _sounds = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePreview(String? soundId) async {
    if (soundId == null || soundId.isEmpty) return;
    final runtime = ref.read(agentRuntimeProvider);
    if (_playingSoundId == soundId) {
      await runtime.sound?.stop();
      if (mounted) setState(() => _playingSoundId = null);
    } else {
      await runtime.sound?.play(soundId);
      if (mounted) setState(() => _playingSoundId = soundId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(editorControllerProvider.notifier);
    final existingIds = widget.state.layout.allTileIds;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LabelField(
          initialValue: widget.tile.label,
          onSubmitted: (newLabel) {
            notifier.upsertTile(
              widget.state.currentPage,
              widget.tile.copyWith(label: newLabel),
            );
          },
        ),
        const SizedBox(height: 16),
        _IconField(
          icon: widget.tile.icon,
          staticIcon: widget.tile.staticIcon,
          animationMode: widget.tile.animationMode,
          isSoundOrToggle: true,
          onPicked: (newIcon, newStatic) {
            notifier.upsertTile(
              widget.state.currentPage,
              widget.tile.copyWith(
                icon: newIcon,
                staticIcon: newStatic,
              ),
            );
          },
          onAnimationModeChanged: (mode, newStatic) {
            notifier.upsertTile(
              widget.state.currentPage,
              widget.tile.copyWith(animationMode: mode, staticIcon: newStatic),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        _IdField(
          initialValue: widget.tile.id,
          hasBinding: false,
          existingIds: existingIds,
          onSubmitted: (newId) {
            notifier.replaceTile(
              widget.state.currentPage,
              widget.tile.id,
              widget.tile.copyWith(id: newId),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        const Text('Configurações de Ciclo e Duração',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: widget.tile.focusDurationMinutes.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Foco (min)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onFieldSubmitted: (val) {
                  final n = int.tryParse(val) ?? widget.tile.focusDurationMinutes;
                  if (n > 0) {
                    notifier.upsertTile(
                      widget.state.currentPage,
                      widget.tile.copyWith(focusDurationMinutes: n),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: widget.tile.shortBreakDurationMinutes.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pausa Curta (min)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onFieldSubmitted: (val) {
                  final n = int.tryParse(val) ?? widget.tile.shortBreakDurationMinutes;
                  if (n > 0) {
                    notifier.upsertTile(
                      widget.state.currentPage,
                      widget.tile.copyWith(shortBreakDurationMinutes: n),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: widget.tile.longBreakDurationMinutes.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pausa Longa (min)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onFieldSubmitted: (val) {
                  final n = int.tryParse(val) ?? widget.tile.longBreakDurationMinutes;
                  if (n > 0) {
                    notifier.upsertTile(
                      widget.state.currentPage,
                      widget.tile.copyWith(longBreakDurationMinutes: n),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: widget.tile.cyclesBeforeLongBreak.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ciclos p/ Longa',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onFieldSubmitted: (val) {
                  final n = int.tryParse(val) ?? widget.tile.cyclesBeforeLongBreak;
                  if (n > 0) {
                    notifier.upsertTile(
                      widget.state.currentPage,
                      widget.tile.copyWith(cyclesBeforeLongBreak: n),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const Divider(height: 32, color: Colors.white10),
        const Text('Efeitos Sonoros de Transição',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        // Som de Início de Fase
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: widget.tile.startPhaseSoundId,
                decoration: const InputDecoration(
                  labelText: 'Som ao Iniciar Fase',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Nenhum'),
                  ),
                  ..._sounds.map((s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (newSoundId) {
                  notifier.upsertTile(
                    widget.state.currentPage,
                    widget.tile.copyWith(
                      startPhaseSoundId: newSoundId,
                      clearStartPhaseSound: newSoundId == null,
                    ),
                  );
                },
              ),
            ),
            if (widget.tile.startPhaseSoundId != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _playingSoundId == widget.tile.startPhaseSoundId
                      ? Icons.stop
                      : Icons.play_arrow,
                  color: Colors.deepPurpleAccent,
                ),
                tooltip: 'Testar som',
                onPressed: () => _togglePreview(widget.tile.startPhaseSoundId),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Som de Fim de Fase
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: widget.tile.endPhaseSoundId,
                decoration: const InputDecoration(
                  labelText: 'Som ao Finalizar Fase',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Nenhum'),
                  ),
                  ..._sounds.map((s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (newSoundId) {
                  notifier.upsertTile(
                    widget.state.currentPage,
                    widget.tile.copyWith(
                      endPhaseSoundId: newSoundId,
                      clearEndPhaseSound: newSoundId == null,
                    ),
                  );
                },
              ),
            ),
            if (widget.tile.endPhaseSoundId != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _playingSoundId == widget.tile.endPhaseSoundId
                      ? Icons.stop
                      : Icons.play_arrow,
                  color: Colors.deepPurpleAccent,
                ),
                tooltip: 'Testar som',
                onPressed: () => _togglePreview(widget.tile.endPhaseSoundId),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TodoInspector extends ConsumerWidget {
  final TodoTile tile;
  final EditorState state;

  const _TodoInspector({required this.tile, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(editorControllerProvider.notifier);
    final existingIds = state.layout.allTileIds;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LabelField(
          initialValue: tile.label,
          onSubmitted: (newLabel) {
            notifier.upsertTile(
              state.currentPage,
              tile.copyWith(label: newLabel),
            );
          },
        ),
        const SizedBox(height: 16),
        _IconField(
          icon: tile.icon,
          staticIcon: tile.staticIcon,
          animationMode: tile.animationMode,
          isSoundOrToggle: true,
          onPicked: (newIcon, newStatic) {
            notifier.upsertTile(
              state.currentPage,
              tile.copyWith(
                icon: newIcon,
                staticIcon: newStatic,
              ),
            );
          },
          onAnimationModeChanged: (mode, newStatic) {
            notifier.upsertTile(
              state.currentPage,
              tile.copyWith(animationMode: mode, staticIcon: newStatic),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        _IdField(
          initialValue: tile.id,
          hasBinding: false,
          existingIds: existingIds,
          onSubmitted: (newId) {
            notifier.replaceTile(
              state.currentPage,
              tile.id,
              tile.copyWith(id: newId),
            );
          },
        ),
        const Divider(height: 32, color: Colors.white10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.lightGreenAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'As tarefas são adicionadas, marcadas e gerenciadas em tempo real diretamente pelo tablet através da gaveta de tarefas.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


