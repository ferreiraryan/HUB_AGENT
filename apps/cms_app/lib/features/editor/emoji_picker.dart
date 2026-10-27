import 'package:flutter/material.dart';
import 'helpers/image_icon_helper.dart';
import 'widgets/tile_icon_view.dart';

Future<String?> showEmojiPicker(
  BuildContext context, {
  required String current,
}) {
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedEmoji = widget.initialEmoji;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handlePickImage() async {
    try {
      final base64Image = await ImageIconHelper.pickAndProcessImage(targetSize: 96);
      if (base64Image != null && mounted) {
        setState(() {
          _selectedEmoji = base64Image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar imagem: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim();
    final hasSearch = query.isNotEmpty;
    final results = hasSearch ? _filterEmojis(query.toLowerCase()) : const <String>[];
    final isSelectedImage = ImageIconHelper.isImageDataUri(_selectedEmoji);
    final accent = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        height: 620,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Escolha um ícone ou imagem',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                FilledButton.tonalIcon(
                  onPressed: _handlePickImage,
                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                  label: const Text('Carregar Imagem'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Banner se houver imagem carregada
            if (isSelectedImage) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent),
                ),
                child: Row(
                  children: [
                    TileIconView(icon: _selectedEmoji, size: 36),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Imagem personalizada selecionada',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Remover imagem',
                      onPressed: () {
                        setState(() {
                          _selectedEmoji = '⚡';
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _searchController,
              autofocus: !isSelectedImage,
              decoration: InputDecoration(
                hintText: 'Buscar ou colar emoji livremente (Win + .)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            const SizedBox(height: 10),

            // Card para permitir usar texto/emoji digitado diretamente (Win + .)
            if (hasSearch) ...[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _selectedEmoji = query;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedEmoji == query
                        ? accent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedEmoji == query ? accent : Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      TileIconView(icon: query, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Usar exatamente: "$query"',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            Expanded(
              child: hasSearch
                  ? _buildGrid(results)
                  : CustomScrollView(
                      slivers: _categories.entries.expand((entry) {
                        return [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 6),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Selecionado: ', style: TextStyle(color: Colors.white60)),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TileIconView(icon: _selectedEmoji, size: 24),
                    ),
                  ],
                ),
                Row(
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
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<String> emojis) {
    if (emojis.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum ícone no catálogo. Você pode clicar no botão acima para usar o texto/emoji digitado!',
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
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

  Widget _buildEmojiCell(String iconValue) {
    final isSelected = _selectedEmoji == iconValue;
    final accent = Theme.of(context).colorScheme.primary;

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
          color: isSelected ? accent.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: TileIconView(icon: iconValue, size: 26),
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

    // Se o próprio termo digitado estiver no mapa ou for um emoji das categorias
    for (final list in _categories.values) {
      for (final item in list) {
        if (!added.contains(item) && item.toLowerCase().contains(query)) {
          results.add(item);
          added.add(item);
        }
      }
    }

    return results;
  }
}

IconData getMaterialIcon(String? iconName) {
  if (iconName == null || iconName.isEmpty) {
    return Icons.widgets;
  }
  return iconMap[iconName] ?? Icons.help_outline;
}

// ----------------------------------------------------------------------------
// Base de dados expandida de Categorias e Emojis/Ícones
// ----------------------------------------------------------------------------
const _categories = <String, List<String>>{
  '🎮 Games & E-Sports': [
    'sports_esports',
    'videogame_asset',
    '🎮',
    '🕹️',
    '👾',
    '🎯',
    '🎲',
    '⚔️',
    '🛡️',
    '🏆',
    '🥇',
    '🥈',
    '🥉',
    '🔫',
    '💣',
    '🏹',
    '🪄',
    '🃏',
    '♟️',
    '🏎️',
    '🚀',
    '🔥',
    '💀',
    '👑',
    '💎',
  ],
  '🎬 Mídia & Streaming': [
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
    'loop',
    'volume_up',
    'volume_down',
    'volume_mute',
    'volume_off',
    'music_note',
    'headphones',
    'mic',
    'mic_off',
    'radio',
    'tv',
    'videocam',
    'videocam_off',
    'equalizer',
    'tune',
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
    '🎧',
    '🎙️',
    '📻',
    '📺',
    '🎬',
    '🎥',
    '📹',
    '📽️',
    '🎸',
    '🎹',
    '🥁',
    '🎺',
    '🎷',
    '🔔',
    '🔕',
  ],
  '💻 Hardware & Sistema': [
    'computer',
    'desktop_windows',
    'smartphone',
    'watch',
    'keyboard',
    'mouse',
    'print',
    'battery_full',
    'power_settings_new',
    'restart_alt',
    'power',
    'lightbulb',
    'flashlight_on',
    'photo_camera',
    'screenshot',
    'brightness_high',
    'brightness_low',
    'fullscreen',
    'fullscreen_exit',
    '💻',
    '🖥️',
    '📱',
    '⌚',
    '⌨️',
    '🖱️',
    '🖨️',
    '🔋',
    '🔌',
    '💡',
    '🔦',
    '📷',
    '📸',
    '💽',
    '💾',
    '💿',
    '📀',
    '🎚️',
    '🎛️',
  ],
  '⚡ Ações & Produtividade': [
    'bolt',
    'local_fire_department',
    'star',
    'warning',
    'block',
    'help_outline',
    'priority_high',
    'verified',
    'check',
    'close',
    'add',
    'remove',
    'delete',
    'refresh',
    'search',
    'settings',
    'home',
    'dashboard',
    'timer',
    'alarm',
    'hourglass_empty',
    'rocket_launch',
    'flash_on',
    '⚡',
    '🔥',
    '💥',
    '✨',
    '🌟',
    '⭐',
    '💤',
    '🛑',
    '⛔',
    '🚫',
    '⚠️',
    '❓',
    '❔',
    '❗',
    '❕',
    'ℹ️',
    '✔️',
    '❌',
    '➕',
    '➖',
    '🔄',
    '🔃',
    '🔁',
    '🔂',
    '⚙️',
    '🔧',
    '🔨',
    '🛠️',
    '🪛',
    '🪚',
    '🧲',
    '⏰',
    '⏱️',
    '⏲️',
    '⏳',
    '🚀',
  ],
  '🌐 Apps, Dev & Comunicação': [
    'language',
    'chat',
    'smart_toy',
    'mail',
    'call',
    'terminal',
    'build',
    'science',
    'radar',
    'calculate',
    'folder',
    'folder_open',
    'folder_zip',
    'insert_drive_file',
    'cloud_upload',
    'cloud_download',
    'lock',
    'lock_open',
    'visibility',
    'visibility_off',
    'bar_chart',
    'show_chart',
    'content_paste',
    'inventory_2',
    'palette',
    '💬',
    '🗨️',
    '🗯️',
    '💭',
    '📧',
    '📩',
    '📨',
    '📞',
    '☎️',
    '📢',
    '📣',
    '🌐',
    '🤖',
    '💻',
    '📡',
    '🧪',
    '🧮',
    '📊',
    '📈',
    '📉',
    '📋',
    '📑',
    '📁',
    '📂',
    '📄',
    '📌',
    '📍',
    '🔗',
    '🔒',
    '🔓',
    '🔑',
  ],
  '😀 Expressões & Reações': [
    '👍',
    '👎',
    '👌',
    '✌️',
    '👊',
    '👏',
    '🙌',
    '🤝',
    '💪',
    '🧠',
    '👀',
    '😎',
    '🔥',
    '💀',
    '🤖',
    '💩',
    '🎉',
    '🎊',
    '❤️',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '💔',
    '💯',
  ],
  '🔢 Números & Marcadores': [
    'looks_one',
    'looks_two',
    'looks_3',
    'looks_4',
    'looks_5',
    'looks_6',
    'filter_7',
    'filter_8',
    'filter_9',
    '1️⃣',
    '2️⃣',
    '3️⃣',
    '4️⃣',
    '5️⃣',
    '6️⃣',
    '7️⃣',
    '8️⃣',
    '9️⃣',
    '0️⃣',
    '🔟',
    '🟥',
    '🟧',
    '🟨',
    '🟩',
    '🟦',
    '🟪',
    '🟫',
    '⬛',
    '⬜',
    '⚪',
    '⚫',
    '🔴',
    '🔵',
  ],
  '🏠 Casa & Clima': [
    'chair',
    'shower',
    'wb_sunny',
    'cloud',
    'water_drop',
    'ac_unit',
    'dark_mode',
    '🛋️',
    '🛏️',
    '🚪',
    '🪟',
    '🚿',
    '🛁',
    '🧹',
    '🌡️',
    '❄️',
    '🌀',
    '🕰️',
    '⏰',
    '🧯',
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
  'loop': Icons.loop,
  'volume_up': Icons.volume_up,
  'volume_down': Icons.volume_down,
  'volume_mute': Icons.volume_mute,
  'volume_off': Icons.volume_off,
  'music_note': Icons.music_note,
  'headphones': Icons.headphones,
  'radio': Icons.radio,
  'mic': Icons.mic,
  'mic_off': Icons.mic_off,
  'tv': Icons.tv,
  'videocam': Icons.videocam,
  'videocam_off': Icons.videocam_off,
  'equalizer': Icons.equalizer,
  'tune': Icons.tune,
  'arrow_back': Icons.arrow_back,
  'arrow_forward': Icons.arrow_forward,
  'arrow_upward': Icons.arrow_upward,
  'arrow_downward': Icons.arrow_downward,
  'home': Icons.home,
  'dashboard': Icons.dashboard,
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
  'folder_zip': Icons.folder_zip,
  'insert_drive_file': Icons.insert_drive_file,
  'cloud_upload': Icons.cloud_upload,
  'cloud_download': Icons.cloud_download,
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
  'power_settings_new': Icons.power_settings_new,
  'restart_alt': Icons.restart_alt,
  'lightbulb': Icons.lightbulb,
  'flashlight_on': Icons.flashlight_on,
  'photo_camera': Icons.photo_camera,
  'screenshot': Icons.screenshot,
  'brightness_high': Icons.brightness_high,
  'brightness_low': Icons.brightness_low,
  'fullscreen': Icons.fullscreen,
  'fullscreen_exit': Icons.fullscreen_exit,
  'language': Icons.language,
  'local_fire_department': Icons.local_fire_department,
  'chat': Icons.chat,
  'smart_toy': Icons.smart_toy,
  'sports_esports': Icons.sports_esports,
  'videogame_asset': Icons.videogame_asset,
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
  'timer': Icons.timer,
  'alarm': Icons.alarm,
  'hourglass_empty': Icons.hourglass_empty,
  'rocket_launch': Icons.rocket_launch,
  'flash_on': Icons.flash_on,
  'lock': Icons.lock,
  'lock_open': Icons.lock_open,
  'visibility': Icons.visibility,
  'visibility_off': Icons.visibility_off,
  'palette': Icons.palette,
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
  'mic_off': ['mute mic', 'mutar microfone'],
  'videocam_off': ['desligar camera', 'sem video'],
  'music_note': ['musica', 'som', 'spotify'],
  'headphones': ['fone', 'audio'],
  'tv': ['tv', 'tela', 'video'],
  'arrow_back': ['voltar', 'esquerda'],
  'home': ['home', 'casa', 'inicio'],
  'refresh': ['atualizar', 'recarregar'],
  'settings': ['config', 'engrenagem'],
  'close': ['x', 'fechar', 'cancelar', 'kill'],
  'delete': ['lixo', 'excluir', 'apagar'],
  'folder': ['pasta', 'diretorio'],
  'insert_drive_file': ['arquivo', 'documento'],
  'desktop_windows': ['pc', 'monitor', 'hyprland'],
  'lightbulb': ['luz', 'brilho', 'brightness'],
  'language': ['web', 'internet', 'browser', 'chrome', 'firefox'],
  'chat': ['chat', 'discord', 'mensagem'],
  'sports_esports': ['jogo', 'game', 'steam', 'cs', 'lol'],
  'videogame_asset': ['gamepad', 'controle', 'jogo'],
  'terminal': ['terminal', 'linux', 'arch', 'bash', 'cmd', 'powershell'],
  'dark_mode': ['noite', 'escuro', 'lua'],
  'power_settings_new': ['desligar', 'power', 'shutdown'],
  'restart_alt': ['reiniciar', 'reboot'],
  'screenshot': ['print', 'captura', 'tela'],
  'timer': ['tempo', 'timer', 'cronometro'],
  'lock': ['trancar', 'bloquear', 'senha'],
  'rocket_launch': ['foguete', 'iniciar', 'executar', 'launch'],
};
