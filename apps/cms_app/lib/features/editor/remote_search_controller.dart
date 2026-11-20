import 'dart:async';
import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../system/global_hotkey_service.dart';
import '../../system/window_controller.dart';

class SearchFilterOption {
  final String id;
  final String label;
  final String shortcutHint;

  const SearchFilterOption({
    required this.id,
    required this.label,
    required this.shortcutHint,
  });
}

const List<SearchFilterOption> kSearchFilters = [
  SearchFilterOption(id: 'all', label: 'Todos', shortcutHint: '1'),
  SearchFilterOption(id: 'sound', label: 'Sons', shortcutHint: '2'),
  SearchFilterOption(id: 'shortcut', label: 'Atalhos', shortcutHint: '3'),
  SearchFilterOption(id: 'slider', label: 'Sliders', shortcutHint: '4'),
  SearchFilterOption(id: 'stat', label: 'Stats', shortcutHint: '5'),
  SearchFilterOption(id: 'toggle', label: 'Toggles', shortcutHint: '6'),
];

class SearchResultItem {
  final Tile tile;
  final String pageName;

  const SearchResultItem({
    required this.tile,
    required this.pageName,
  });
}

class RemoteSearchState {
  final bool isOpen;
  final String query;
  final String filter;
  final String scope; // 'all' | 'page'
  final int selectedIndex;
  final bool wasHidden;

  const RemoteSearchState({
    this.isOpen = false,
    this.query = '',
    this.filter = 'all',
    this.scope = 'all',
    this.selectedIndex = 0,
    this.wasHidden = false,
  });

  RemoteSearchState copyWith({
    bool? isOpen,
    String? query,
    String? filter,
    String? scope,
    int? selectedIndex,
    bool? wasHidden,
  }) {
    return RemoteSearchState(
      isOpen: isOpen ?? this.isOpen,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      scope: scope ?? this.scope,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      wasHidden: wasHidden ?? this.wasHidden,
    );
  }
}

class RemoteSearchController extends Notifier<RemoteSearchState> {
  StreamSubscription<void>? _searchSub;
  StreamSubscription<void>? _hotkeySub;

  @override
  RemoteSearchState build() {
    final bridge = ref.watch(agentBridgeProvider);
    final initialSpotlight = ref.watch(initialSpotlightProvider);

    _searchSub?.cancel();
    _searchSub = bridge.remoteSearchPrompts.listen((_) {
      open();
    });

    _hotkeySub?.cancel();
    if (!bridge.isDaemonMode) {
      _hotkeySub = GlobalHotkeyService.instance.onTriggered.listen((_) {
        toggle();
      });
    }

    ref.onDispose(() {
      _searchSub?.cancel();
      _hotkeySub?.cancel();
    });

    if (initialSpotlight == 'search') {
      WindowController.instance.setSpotlightBlurHandler(close);
      return const RemoteSearchState(isOpen: true, wasHidden: true);
    }

    return const RemoteSearchState();
  }

  Future<void> toggle() async {
    if (state.isOpen) {
      await close();
    } else {
      await open();
    }
  }

  Future<void> open() async {
    if (state.isOpen) return;
    final wasHidden = await WindowController.instance.isHiddenOrMinimized();
    // 1. Atualiza o estado ANTES do resize da janela, garantindo que o Flutter
    // monte a visualização correta sem tentar redimensionar a EditorPage.
    state = RemoteSearchState(
      isOpen: true,
      query: '',
      filter: 'all',
      scope: 'all',
      selectedIndex: 0,
      wasHidden: wasHidden,
    );
    // 2. Agora redimensiona/exibe a janela de forma segura
    await WindowController.instance.openSpotlight(
      wasHidden: wasHidden,
      title: 'Busca Rápida — Hub Agent',
      onBlur: close,
      size: WindowController.searchSpotlightSize,
    );
  }

  Future<void> _publishCurrent({required bool active}) {
    return ref.read(agentBridgeProvider).publishSearchQuery(
          state.query,
          active: active,
          filter: state.filter,
          scope: state.scope,
        );
  }

  void updateQuery(String query) {
    state = state.copyWith(query: query, selectedIndex: 0);
    unawaited(_publishCurrent(active: true));
  }

  void setFilter(String filter) {
    if (state.filter == filter) return;
    state = state.copyWith(filter: filter, selectedIndex: 0);
    unawaited(_publishCurrent(active: true));
  }

  void cycleFilter({bool reverse = false}) {
    final idx = kSearchFilters.indexWhere((f) => f.id == state.filter);
    final current = idx < 0 ? 0 : idx;
    final next = reverse
        ? (current - 1 + kSearchFilters.length) % kSearchFilters.length
        : (current + 1) % kSearchFilters.length;
    setFilter(kSearchFilters[next].id);
  }

  void toggleScope() {
    final nextScope = state.scope == 'all' ? 'page' : 'all';
    state = state.copyWith(scope: nextScope, selectedIndex: 0);
    unawaited(_publishCurrent(active: true));
  }

  void clear() {
    state = state.copyWith(query: '', filter: 'all', selectedIndex: 0);
    unawaited(_publishCurrent(active: true));
  }

  void moveSelection(int delta, int count) {
    if (count <= 0) return;
    final next = (state.selectedIndex + delta) % count;
    state = state.copyWith(selectedIndex: next < 0 ? next + count : next);
  }

  void setSelectedIndex(int index) {
    if (index == state.selectedIndex) return;
    state = state.copyWith(selectedIndex: index);
  }

  Future<void> executeTile(Tile tile, {bool closeAfter = true}) async {
    final bridge = ref.read(agentBridgeProvider);
    if (tile is SoundTile ||
        tile is ShortcutTile ||
        tile is ToggleTile ||
        tile is PomodoroTile) {
      await bridge.triggerAction(tile.id);
    }
    if (closeAfter) {
      await close();
    }
  }

  /// Filtra os tiles do layout atual respeitando o filtro e termo digitado.
  List<SearchResultItem> computeResults(Layout layout) {
    final q = state.query.trim().toLowerCase();
    final filter = state.filter;
    final results = <SearchResultItem>[];

    for (final entry in layout.pages.entries) {
      final pageName = entry.key;
      for (final tile in entry.value) {
        if (!_matchesFilter(tile, filter)) continue;
        if (q.isNotEmpty) {
          final label = tile.label.toLowerCase();
          final id = tile.id.toLowerCase();
          final page = pageName.toLowerCase();
          if (!label.contains(q) && !id.contains(q) && !page.contains(q)) {
            continue;
          }
        }
        results.add(SearchResultItem(tile: tile, pageName: pageName));
      }
    }

    // Prioriza matches que começam com o termo digitado
    if (q.isNotEmpty) {
      results.sort((a, b) {
        final aStarts = a.tile.label.toLowerCase().startsWith(q) ? 0 : 1;
        final bStarts = b.tile.label.toLowerCase().startsWith(q) ? 0 : 1;
        if (aStarts != bStarts) return aStarts.compareTo(bStarts);
        return a.tile.label.toLowerCase().compareTo(b.tile.label.toLowerCase());
      });
    }

    return results;
  }

  bool _matchesFilter(Tile tile, String filter) {
    switch (filter) {
      case 'all':
        return true;
      case 'sound':
        return tile is SoundTile;
      case 'shortcut':
        return tile is ShortcutTile;
      case 'slider':
        return tile is SliderTile;
      case 'stat':
        return tile is StatTile;
      case 'toggle':
        return tile is ToggleTile || tile is PomodoroTile || tile is TodoTile;
      default:
        return true;
    }
  }

  Future<void> close() async {
    if (!state.isOpen) return;
    await _publishCurrent(active: false);
    await WindowController.instance.closeSpotlight();
    state = const RemoteSearchState(
      isOpen: false,
      query: '',
      filter: 'all',
      scope: 'all',
      selectedIndex: 0,
      wasHidden: false,
    );
  }
}

final remoteSearchControllerProvider =
    NotifierProvider<RemoteSearchController, RemoteSearchState>(
  RemoteSearchController.new,
);
