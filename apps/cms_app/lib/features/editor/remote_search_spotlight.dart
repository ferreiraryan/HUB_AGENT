import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'remote_search_controller.dart';

class RemoteSearchInput extends ConsumerStatefulWidget {
  const RemoteSearchInput({super.key});

  @override
  ConsumerState<RemoteSearchInput> createState() => _RemoteSearchInputState();
}

class _RemoteSearchInputState extends ConsumerState<RemoteSearchInput> {
  late final TextEditingController _textController;
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _listScrollController = ScrollController();

  static const double _itemHeight = 46.0;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(remoteSearchControllerProvider).query;
    _textController = TextEditingController(text: initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_listScrollController.hasClients) return;
    final targetTop = index * _itemHeight;
    final targetBottom = targetTop + _itemHeight;
    final viewport = _listScrollController.position.viewportDimension;
    final current = _listScrollController.offset;

    if (targetTop < current) {
      _listScrollController.jumpTo(targetTop.clamp(0.0, _listScrollController.position.maxScrollExtent));
    } else if (targetBottom > current + viewport) {
      _listScrollController.jumpTo(
        (targetBottom - viewport).clamp(0.0, _listScrollController.position.maxScrollExtent),
      );
    }
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
    List<SearchResultItem> results,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final notifier = ref.read(remoteSearchControllerProvider.notifier);

    // ESC fecha imediatamente
    if (key == LogicalKeyboardKey.escape) {
      notifier.close();
      return KeyEventResult.handled;
    }

    // TAB / Shift+TAB cicla entre os filtros sem perder o foco do texto
    if (key == LogicalKeyboardKey.tab) {
      notifier.cycleFilter(reverse: isShift);
      return KeyEventResult.handled;
    }

    // Ctrl+1..6 ou Alt+1..6 seleciona filtro direto
    if (isCtrl || isAlt) {
      final digitIdx = _digitKeyToIndex(key);
      if (digitIdx != null && digitIdx < kSearchFilters.length) {
        notifier.setFilter(kSearchFilters[digitIdx].id);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyL) {
        _textController.clear();
        notifier.clear();
        return KeyEventResult.handled;
      }
    }

    // Navegação na lista: ↓ / ↑ ou Ctrl+J / Ctrl+K / Ctrl+N / Ctrl+P
    final isDown = key == LogicalKeyboardKey.arrowDown ||
        (isCtrl && (key == LogicalKeyboardKey.keyJ || key == LogicalKeyboardKey.keyN));
    final isUp = key == LogicalKeyboardKey.arrowUp ||
        (isCtrl && (key == LogicalKeyboardKey.keyK || key == LogicalKeyboardKey.keyP));

    if (isDown) {
      notifier.moveSelection(1, results.length);
      final nextIdx = ref.read(remoteSearchControllerProvider).selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToIndex(nextIdx));
      return KeyEventResult.handled;
    }
    if (isUp) {
      notifier.moveSelection(-1, results.length);
      final nextIdx = ref.read(remoteSearchControllerProvider).selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToIndex(nextIdx));
      return KeyEventResult.handled;
    }

    // ENTER executa o item selecionado (Shift+Enter mantém aberto)
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (results.isNotEmpty) {
        final idx = ref
            .read(remoteSearchControllerProvider)
            .selectedIndex
            .clamp(0, results.length - 1);
        notifier.executeTile(results[idx].tile, closeAfter: !isShift);
      } else {
        notifier.close();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  int? _digitKeyToIndex(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) return 0;
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) return 1;
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) return 2;
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) return 3;
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) return 4;
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) return 5;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(remoteSearchControllerProvider);
    Layout? layout;
    try {
      final runtime = ref.watch(agentRuntimeProvider);
      if (runtime.repository.isLoaded) {
        layout = runtime.repository.current;
      }
    } catch (_) {
      layout = null;
    }
    final results = layout != null
        ? ref.read(remoteSearchControllerProvider.notifier).computeResults(layout)
        : const <SearchResultItem>[];
    final safeSelected =
        results.isEmpty ? 0 : searchState.selectedIndex.clamp(0, results.length - 1);

    ref.listen<RemoteSearchState>(remoteSearchControllerProvider, (prev, next) {
      if (next.query != _textController.text) {
        _textController.value = TextEditingValue(
          text: next.query,
          selection: TextSelection.collapsed(offset: next.query.length),
        );
      }
    });

    return Focus(
      onKeyEvent: (node, event) => _handleKeyEvent(node, event, results),
      child: Material(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        elevation: 10,
        shadowColor: const Color(0x88000000),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF89B4FA).withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Campo de busca principal
              Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF89B4FA),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _inputFocusNode,
                        autofocus: true,
                        style: const TextStyle(
                          color: Color(0xFFCDD6F4),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Buscar sons, atalhos, widgets...',
                          hintStyle: TextStyle(
                            color: Color(0xFF7F849C),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) {
                          ref
                              .read(remoteSearchControllerProvider.notifier)
                              .updateQuery(val);
                        },
                      ),
                    ),
                    if (results.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          '${results.length}',
                          style: const TextStyle(
                            color: Color(0xFF7F849C),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (_textController.text.isNotEmpty ||
                        searchState.filter != 'all')
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 17),
                        color: const Color(0xFFA6ADC8),
                        splashRadius: 15,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        tooltip: 'Limpar (Ctrl+L)',
                        onPressed: () {
                          _textController.clear();
                          ref
                              .read(remoteSearchControllerProvider.notifier)
                              .clear();
                          _inputFocusNode.requestFocus();
                        },
                      ),
                  ],
                ),
              ),

              // 2. Barra de filtros (navegável com Tab ou Ctrl+1..6)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF181825),
                  border: Border.symmetric(
                    horizontal: BorderSide(color: Color(0xFF313244)),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final opt in kSearchFilters) ...[
                        _FilterPill(
                          option: opt,
                          selected: searchState.filter == opt.id,
                          onTap: () {
                            ref
                                .read(remoteSearchControllerProvider.notifier)
                                .setFilter(opt.id);
                            _inputFocusNode.requestFocus();
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ),

              // 3. Lista de resultados (↑/↓ + Enter)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 140,
                    maxHeight: 274,
                  ),
                  child: results.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nenhum widget encontrado para este filtro.',
                              style: TextStyle(
                                color: Color(0xFF7F849C),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _listScrollController,
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 6),
                          itemExtent: _itemHeight,
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final item = results[index];
                            final isSelected = index == safeSelected;
                            return _ResultRow(
                              item: item,
                              selected: isSelected,
                              onHover: () => ref
                                  .read(remoteSearchControllerProvider.notifier)
                                  .setSelectedIndex(index),
                              onTap: () => ref
                                  .read(remoteSearchControllerProvider.notifier)
                                  .executeTile(item.tile, closeAfter: true),
                            );
                          },
                        ),
                ),
              ),

              // 4. Rodapé de atalhos de teclado
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: const BoxDecoration(
                  color: Color(0xFF181825),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(13),
                  ),
                  border: Border(
                    top: BorderSide(color: Color(0xFF313244)),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _keyHint('↑↓', 'navegar'),
                      const SizedBox(width: 10),
                      _keyHint('Tab', 'filtro'),
                      const SizedBox(width: 10),
                      _keyHint('Ctrl+1-6', 'categoria'),
                      const SizedBox(width: 10),
                      _keyHint('ENTER', 'executar'),
                      const SizedBox(width: 10),
                      _keyHint('Shift+↵', 'manter'),
                      const SizedBox(width: 10),
                      _keyHint('ESC', 'fechar'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keyHint(String keys, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF313244),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF45475A)),
          ),
          child: Text(
            keys,
            style: const TextStyle(
              color: Color(0xFFCDD6F4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7F849C),
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final SearchFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF89B4FA).withValues(alpha: 0.2)
              : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF89B4FA)
                : const Color(0xFF313244),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.shortcutHint,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF89B4FA)
                    : const Color(0xFF6C7086),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              option.label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFCDD6F4)
                    : const Color(0xFFA6ADC8),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final SearchResultItem item;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _ResultRow({
    required this.item,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = item.tile;
    final (icon, typeLabel, accent) = _tileMeta(tile);

    return MouseRegion(
      onEnter: (_) => onHover(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF313244)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(
                    color: const Color(0xFF89B4FA).withValues(alpha: 0.45),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tile.label.isEmpty ? tile.id : tile.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFF5F7FF)
                        : const Color(0xFFCDD6F4),
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF181825),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  item.pageName,
                  style: const TextStyle(
                    color: Color(0xFF7F849C),
                    fontSize: 10.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_return_rounded,
                  size: 14,
                  color: Color(0xFF89B4FA),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (IconData, String, Color) _tileMeta(Tile tile) {
    if (tile is SoundTile) {
      return (Icons.graphic_eq_rounded, 'Som', const Color(0xFFF5C2E7));
    }
    if (tile is ShortcutTile) {
      return (Icons.bolt_rounded, 'Atalho', const Color(0xFF89B4FA));
    }
    if (tile is SliderTile) {
      return (Icons.tune_rounded, 'Slider', const Color(0xFF94E2D5));
    }
    if (tile is StatTile) {
      return (Icons.analytics_outlined, 'Stat', const Color(0xFFFAB387));
    }
    if (tile is ToggleTile) {
      return (Icons.toggle_on_outlined, 'Toggle', const Color(0xFFA6E3A1));
    }
    if (tile is PomodoroTile) {
      return (Icons.timer_outlined, 'Pomodoro', const Color(0xFFF38BA8));
    }
    if (tile is TodoTile) {
      return (Icons.checklist_rounded, 'Tarefas', const Color(0xFFCBA6F7));
    }
    if (tile is FolderTile) {
      return (Icons.folder_outlined, 'Pasta', const Color(0xFFF9E2AF));
    }
    return (Icons.widgets_outlined, 'Widget', const Color(0xFFA6ADC8));
  }
}

/// Visualização compacta frameless (quando o CMS estava minimizado na bandeja).
class RemoteSearchCompactView extends StatelessWidget {
  const RemoteSearchCompactView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF11111B),
      body: Padding(
        padding: EdgeInsets.all(6),
        child: RemoteSearchInput(),
      ),
    );
  }
}

/// Visualização overlay flutuante (quando o CMS já estava visível na tela).
class RemoteSearchOverlayView extends ConsumerWidget {
  const RemoteSearchOverlayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(remoteSearchControllerProvider.notifier).close();
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 84),
          child: GestureDetector(
            onTap: () {},
            child: const SizedBox(
              width: 640,
              child: RemoteSearchInput(),
            ),
          ),
        ),
      ),
    );
  }
}
