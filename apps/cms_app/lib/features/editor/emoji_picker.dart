import 'package:flutter/material.dart';

Future<String?> showEmojiPicker(BuildContext context,
    {required String current}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _EmojiPickerDialog(initialEmoji: current),
  );
}

class _EmojiPickerDialog extends StatefulWidget {
  final String initialEmoji;

  const _EmojiPickerDialog({required this.initialEmoji});

  @override
  State<_EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<_EmojiPickerDialog> {
  late String _selectedEmoji;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedEmoji = widget.initialEmoji;
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = _searchQuery.trim().isNotEmpty;
    final results = hasSearch ? _filterEmojis(_searchQuery) : const <String>[];

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Escolha um ícone',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar ícone...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8))),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: hasSearch
                  ? _buildGrid(results)
                  : CustomScrollView(
                      slivers: _categories.entries.expand((entry) {
                        return [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70),
                              ),
                            ),
                          ),
                          SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 48,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildEmojiCell(entry.value[index]),
                              childCount: entry.value.length,
                            ),
                          ),
                        ];
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selectedEmoji),
                  child: const Text('Selecionar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<String> emojis) {
    if (emojis.isEmpty) {
      return const Center(
        child: Text('Nenhum ícone encontrado',
            style: TextStyle(color: Colors.white54)),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 48,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) => _buildEmojiCell(emojis[index]),
    );
  }

  // 1. O método atualizado:
  Widget _buildEmojiCell(String iconValue) {
    final isSelected = _selectedEmoji == iconValue;
    final accent = Theme.of(context).colorScheme.primary;

    // A mágica acontece aqui: define o widget dinamicamente
    Widget iconWidget;
    if (iconMap.containsKey(iconValue)) {
      iconWidget = Icon(iconMap[iconValue], size: 28, color: Colors.white);
    } else {
      iconWidget = Text(iconValue, style: const TextStyle(fontSize: 28));
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          _selectedEmoji = iconValue;
        });
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected ? accent : Colors.transparent, width: 2),
        ),
        child: iconWidget,
      ),
    );
  }

  List<String> _filterEmojis(String query) {
    final results = <String>[];
    final added = <String>{};

    for (final entry in _keywords.entries) {
      final emoji = entry.key;
      if (added.contains(emoji)) continue;

      final matches = entry.value.any((kw) => kw.contains(query));
      if (matches) {
        results.add(emoji);
        added.add(emoji);
      }
    }
    return results;
  }
}

IconData getMaterialIcon(String? iconName) {
  if (iconName == null || iconName.isEmpty) {
    return Icons.widgets; // Fallback genérico
  }
  return iconMap[iconName] ?? Icons.help_outline;
}
// ----------------------------------------------------------------------------
// Base de dados de Emojis (Otimizada para Android Legacy / Unicode Clássico)
// ----------------------------------------------------------------------------

// 2. Substitua a base de dados inteira no final do arquivo por esta arquitetura baseada no Material:
const _categories = <String, List<String>>{
  'Números': [
    'looks_one',
    'looks_two',
    'looks_3',
    'looks_4',
    'looks_5',
    'looks_6',
    'filter_7',
    'filter_8',
    'filter_9'
  ],
  'Mídia & Áudio': [
    'play_arrow',
    'pause',
    'stop',
    'fiber_manual_record',
    'skip_next',
    'skip_previous',
    'fast_forward',
    'fast_rewind',
    'shuffle',
    'repeat',
    'volume_up',
    'volume_down',
    'volume_mute',
    'volume_off',
    'music_note',
    'headphones',
    'radio',
    'mic',
    'tv',
    '▶️',
    '⏸️',
    '⏯️',
    '⏹️',
    '⏺️',
    '⏭️',
    '⏮️',
    '⏩',
    '⏪',
    '🔀',
    '🔁',
    '🔊',
    '🔉',
    '🔈',
    '🔇',
    '🎵',
    '🎶',
    '📻',
    '🎧',
    '🎙️',
    '📺',
    '💬',
    '🗨️',
    '🗯️',
    '💭',
    '📧',
    '📩',
    '📨',
    '📦',
    '📞',
    '☎️',
    '📟',
    '📠',
    '📢',
    '📣'
  ],
  'Navegação & UI': [
    'arrow_back',
    'arrow_forward',
    'arrow_upward',
    'arrow_downward',
    'home',
    'refresh',
    'search',
    'settings',
    'close',
    'check',
    'add',
    'remove',
    'delete',
    'push_pin',
    'location_on',
    'link',
    'notifications',
    'notifications_off',
    '⬅️',
    '➡️',
    '⬆️',
    '⬇️',
    '🏠',
    '🔙',
    '🔄',
    '🔍',
    '⚙️',
    '❌',
    '✖️',
    '✔️',
    '➕',
    '➖',
    '🗑️',
    '📁',
    '📂',
    '📄',
    '📑',
    '🔖',
    '📌',
    '📍',
    '🔗',
    '🔔',
    '🔕'
  ],
  'Pastas & Arquivos': [
    'folder',
    'folder_open',
    'insert_drive_file',
    'bar_chart',
    'show_chart',
    'content_paste',
    'inventory_2'
  ],
  'Hardware & Dispositivos': [
    'computer',
    'desktop_windows',
    'smartphone',
    'watch',
    'keyboard',
    'mouse',
    'print',
    'battery_full',
    'power',
    'lightbulb',
    'flashlight_on',
    'photo_camera',
    'videocam',
    '💻',
    '🖥️',
    '📱',
    '⌚',
    '⌨️',
    '🖱️',
    '🖨️',
    '🎮',
    '🕹️',
    '🔋',
    '🔌',
    '💡',
    '🔦',
    '📷',
    '📸',
    '📹',
    '📼'
  ],
  'Apps & Games': [
    'language',
    'local_fire_department',
    'chat',
    'smart_toy',
    'sports_esports',
    'mail',
    'call'
  ],
  'Dev & Ferramentas': [
    'terminal',
    'build',
    'science',
    'radar',
    'calculate',
    '🛠️',
    '⚒️',
    '🔧',
    '🪛',
    '🪚',
    '🧲',
    '🧱',
    '🔬',
    '🔭',
    '📡',
    '🧩',
    '🧪',
    '🧮',
    '📊',
    '📈',
    '📉',
    '📋'
  ],
  'Casa & Clima': [
    'chair',
    'door_front',
    'shower',
    'wb_sunny',
    'cloud',
    'water_drop',
    'bolt',
    'ac_unit',
    'dark_mode',
    'star',
    '🛋️',
    '🛏️',
    '🚪',
    '🪟',
    '🚿',
    '🛁',
    '🚽',
    '🧹',
    '🧺',
    '🌡️',
    '❄️',
    '🌀',
    '🪭',
    '🕰️',
    '⏰',
    '🧯'
  ],
  'Símbolos & Alertas': [
    'warning',
    'block',
    'help_outline',
    'priority_high',
    'verified',
    'loop',
    '⚠️',
    '⛔',
    '🚫',
    '❓',
    '❔',
    '❗',
    '❕',
    '💯',
    '💢',
    '💤',
    '🌐',
    '💠',
    '⚕️',
    '♻️',
    '🟩',
    '🟥',
    '🟦',
    '🟨'
  ],
};

// Mapeamento String -> IconData do Flutter
const iconMap = <String, IconData>{
  'looks_one': Icons.looks_one,
  'looks_two': Icons.looks_two,
  'looks_3': Icons.looks_3,
  'looks_4': Icons.looks_4,
  'looks_5': Icons.looks_5,
  'looks_6': Icons.looks_6,
  'filter_7': Icons.filter_7,
  'filter_8': Icons.filter_8,
  'filter_9': Icons.filter_9,
  'play_arrow': Icons.play_arrow,
  'pause': Icons.pause,
  'stop': Icons.stop,
  'fiber_manual_record': Icons.fiber_manual_record,
  'skip_next': Icons.skip_next,
  'skip_previous': Icons.skip_previous,
  'fast_forward': Icons.fast_forward,
  'fast_rewind': Icons.fast_rewind,
  'shuffle': Icons.shuffle,
  'repeat': Icons.repeat,
  'volume_up': Icons.volume_up,
  'volume_down': Icons.volume_down,
  'volume_mute': Icons.volume_mute,
  'volume_off': Icons.volume_off,
  'music_note': Icons.music_note,
  'headphones': Icons.headphones,
  'radio': Icons.radio,
  'mic': Icons.mic,
  'tv': Icons.tv,
  'arrow_back': Icons.arrow_back,
  'arrow_forward': Icons.arrow_forward,
  'arrow_upward': Icons.arrow_upward,
  'arrow_downward': Icons.arrow_downward,
  'home': Icons.home,
  'refresh': Icons.refresh,
  'search': Icons.search,
  'settings': Icons.settings,
  'close': Icons.close,
  'check': Icons.check,
  'add': Icons.add,
  'remove': Icons.remove,
  'delete': Icons.delete,
  'push_pin': Icons.push_pin,
  'location_on': Icons.location_on,
  'link': Icons.link,
  'notifications': Icons.notifications,
  'notifications_off': Icons.notifications_off,
  'folder': Icons.folder,
  'folder_open': Icons.folder_open,
  'insert_drive_file': Icons.insert_drive_file,
  'bar_chart': Icons.bar_chart,
  'show_chart': Icons.show_chart,
  'content_paste': Icons.content_paste,
  'inventory_2': Icons.inventory_2,
  'computer': Icons.computer,
  'desktop_windows': Icons.desktop_windows,
  'smartphone': Icons.smartphone,
  'watch': Icons.watch,
  'keyboard': Icons.keyboard,
  'mouse': Icons.mouse,
  'print': Icons.print,
  'battery_full': Icons.battery_full,
  'power': Icons.power,
  'lightbulb': Icons.lightbulb,
  'flashlight_on': Icons.flashlight_on,
  'photo_camera': Icons.photo_camera,
  'videocam': Icons.videocam,
  'language': Icons.language,
  'local_fire_department': Icons.local_fire_department,
  'chat': Icons.chat,
  'smart_toy': Icons.smart_toy,
  'sports_esports': Icons.sports_esports,
  'mail': Icons.mail,
  'call': Icons.call,
  'terminal': Icons.terminal,
  'build': Icons.build,
  'science': Icons.science,
  'radar': Icons.radar,
  'calculate': Icons.calculate,
  'chair': Icons.chair,
  'shower': Icons.shower,
  'wb_sunny': Icons.wb_sunny,
  'cloud': Icons.cloud,
  'water_drop': Icons.water_drop,
  'bolt': Icons.bolt,
  'ac_unit': Icons.ac_unit,
  'dark_mode': Icons.dark_mode,
  'star': Icons.star,
  'warning': Icons.warning,
  'block': Icons.block,
  'help_outline': Icons.help_outline,
  'priority_high': Icons.priority_high,
  'verified': Icons.verified,
  'loop': Icons.loop,
};

const _keywords = <String, List<String>>{
  'looks_one': ['1', 'um', 'workspace', 'numero'],
  'looks_two': ['2', 'dois', 'workspace', 'numero'],
  'looks_3': ['3', 'tres', 'workspace', 'numero'],
  'looks_4': ['4', 'quatro', 'workspace', 'numero'],
  'looks_5': ['5', 'cinco', 'workspace', 'numero'],
  'looks_6': ['6', 'seis', 'workspace', 'numero'],
  'filter_7': ['7', 'sete', 'workspace', 'numero'],
  'filter_8': ['8', 'oito', 'workspace', 'numero'],
  'filter_9': ['9', 'nove', 'workspace', 'numero'],
  'play_arrow': ['play', 'tocar', 'iniciar', 'midia'],
  'pause': ['pause', 'pausar', 'parar'],
  'stop': ['stop', 'parar'],
  'fiber_manual_record': ['rec', 'gravar'],
  'skip_next': ['next', 'proximo', 'avançar'],
  'skip_previous': ['prev', 'anterior', 'voltar'],
  'volume_up': ['volume', 'som', 'alto'],
  'volume_down': ['volume', 'baixo'],
  'volume_mute': ['mute', 'mudo'],
  'volume_off': ['sem som'],
  'music_note': ['musica', 'som', 'spotify'],
  'headphones': ['fone', 'audio'],
  'tv': ['tv', 'tela', 'video'],
  'arrow_back': ['voltar', 'esqueda'],
  'home': ['home', 'casa', 'inicio'],
  'refresh': ['atualizar', 'recarregar'],
  'settings': ['config', 'engrenagem'],
  'close': ['x', 'fechar', 'cancelar', 'kill'],
  'delete': ['lixo', 'excluir', 'apagar'],
  'folder': ['pasta', 'diretorio'],
  'insert_drive_file': ['arquivo', 'documento'],
  'desktop_windows': ['pc', 'monitor', 'hyprland'],
  'lightbulb': ['luz', 'brilho', 'brightness'],
  'language': ['web', 'internet', 'browser', 'firefox'],
  'chat': ['chat', 'discord', 'mensagem'],
  'sports_esports': ['jogo', 'game', 'steam'],
  'terminal': ['terminal', 'linux', 'arch', 'bash'],
  'dark_mode': ['noite', 'escuro', 'lua'],
};
