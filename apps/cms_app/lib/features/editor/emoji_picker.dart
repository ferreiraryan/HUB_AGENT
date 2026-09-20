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

  Widget _buildEmojiCell(String emoji) {
    final isSelected = _selectedEmoji == emoji;
    final accent = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          _selectedEmoji = emoji;
        });
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: accent, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
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

// ----------------------------------------------------------------------------
// Base de dados de Emojis
// ----------------------------------------------------------------------------

const _categories = <String, List<String>>{
  'Mídia': [
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
    '📺'
  ],
  'Navegação & UI': [
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
  'Dispositivos': [
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
  'Casa & Objetos': [
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
  'Ferramentas & Dev': [
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
  'Comunicação': [
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
  'Tempo & Clima': [
    '☀️',
    '🌤️',
    '⛅',
    '🌥️',
    '☁️',
    '🌦️',
    '🌧️',
    '⛈️',
    '🌩️',
    '🌨️',
    '💨',
    '💧',
    '☔',
    '☂️',
    '🌙',
    '🌛',
    '🌟',
    '⭐',
    '⏳',
    '⌛'
  ],
  'Símbolos & Alertas': [
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

const _keywords = <String, List<String>>{
  // Mídia
  '▶️': ['play', 'tocar', 'iniciar', 'midia', 'direita'],
  '⏸️': ['pause', 'pausar', 'parar', 'midia'],
  '⏯️': ['play', 'pause', 'tocar', 'midia'],
  '⏹️': ['stop', 'parar', 'quadrado', 'midia'],
  '⏺️': ['rec', 'gravar', 'record', 'midia', 'circulo'],
  '⏭️': ['next', 'proximo', 'avançar', 'pular', 'midia'],
  '⏮️': ['prev', 'anterior', 'voltar', 'midia'],
  '⏩': ['fast', 'forward', 'avançar', 'rapido'],
  '⏪': ['rewind', 'retroceder', 'voltar', 'rapido'],
  '🔀': ['shuffle', 'aleatorio', 'embaralhar'],
  '🔁': ['repeat', 'repetir', 'loop'],
  '🔊': ['volume', 'som', 'alto', 'caixa', 'alto-falante'],
  '🔉': ['volume', 'som', 'medio'],
  '🔈': ['volume', 'som', 'baixo'],
  '🔇': ['mute', 'mudo', 'silencio', 'sem som'],
  '🎵': ['nota', 'musica', 'som', 'audio'],
  '🎶': ['notas', 'musica', 'som', 'audio'],
  '📻': ['radio', 'musica', 'audio'],
  '🎧': ['fone', 'headphone', 'musica', 'audio', 'ouvir'],
  '🎙️': ['microfone', 'podcast', 'voz', 'audio', 'gravar'],
  '📺': ['tv', 'televisao', 'tela', 'video', 'assistir'],

  // Navegação & UI
  '⬅️': ['esqueda', 'voltar', 'seta'],
  '➡️': ['direita', 'proximo', 'ir', 'seta'],
  '⬆️': ['cima', 'subir', 'seta'],
  '⬇️': ['baixo', 'descer', 'seta'],
  '🏠': ['home', 'casa', 'inicio', 'principal'],
  '🔙': ['back', 'voltar', 'retornar'],
  '🔄': ['refresh', 'atualizar', 'recarregar', 'sincronizar'],
  '🔍': ['busca', 'pesquisa', 'lupa', 'procurar', 'zoom'],
  '⚙️': ['config', 'engrenagem', 'opçoes', 'ajustes'],
  '❌': ['x', 'fechar', 'cancelar', 'erro', 'excluir'],
  '✖️': ['x', 'multiplicar', 'fechar'],
  '✔️': ['check', 'ok', 'certo', 'confirmar', 'sucesso'],
  '➕': ['mais', 'adicionar', 'soma', 'novo'],
  '➖': ['menos', 'remover', 'subtrair'],
  '🗑️': ['lixo', 'excluir', 'apagar', 'remover', 'lixeira'],
  '📁': ['pasta', 'diretorio', 'arquivos', 'grupo'],
  '📂': ['pasta', 'aberta', 'diretorio', 'arquivos'],
  '📄': ['arquivo', 'documento', 'folha', 'texto'],
  '📑': ['tabs', 'abas', 'favoritos'],
  '🔖': ['marca', 'favorito', 'salvar', 'tag'],
  '📌': ['pino', 'fixar', 'marcar', 'pin'],
  '📍': ['local', 'mapa', 'gps', 'pino', 'pin'],
  '🔗': ['link', 'elo', 'url', 'corrente'],
  '🔔': ['sino', 'notificação', 'alerta', 'aviso'],
  '🔕': ['sino', 'mudo', 'silencio', 'notificação'],

  // Dispositivos
  '💻': ['pc', 'notebook', 'laptop', 'computador'],
  '🖥️': ['pc', 'monitor', 'desktop', 'tela', 'computador'],
  '📱': ['celular', 'smartphone', 'telefone', 'mobile'],
  '⌚': ['relogio', 'smartwatch', 'hora'],
  '⌨️': ['teclado', 'digitar', 'escrever'],
  '🖱️': ['mouse', 'clique'],
  '🖨️': ['impressora', 'print', 'papel'],
  '🎮': ['jogo', 'game', 'controle', 'console', 'play'],
  '🕹️': ['jogo', 'game', 'arcade', 'joystick'],
  '🔋': ['bateria', 'carga', 'energia'],
  '🔌': ['tomada', 'cabo', 'energia', 'ligar', 'plug'],
  '💡': ['lampada', 'luz', 'ideia', 'brilho'],
  '🔦': ['lanterna', 'luz', 'escuro', 'brilho'],
  '📷': ['camera', 'foto', 'imagem'],
  '📸': ['camera', 'foto', 'flash', 'imagem'],
  '📹': ['video', 'camera', 'gravar', 'filmar'],
  '📼': ['fita', 'vhs', 'video', 'retro'],

  // Casa & Objetos
  '🛋️': ['sofa', 'sala', 'assento', 'moveis'],
  '🛏️': ['cama', 'quarto', 'dormir', 'moveis'],
  '🚪': ['porta', 'entrada', 'saida'],
  '🪟': ['janela', 'vidro', 'abrir'],
  '🚿': ['chuveiro', 'banho', 'agua'],
  '🛁': ['banheira', 'banho', 'agua'],
  '🚽': ['privada', 'banheiro', 'toilette'],
  '🧹': ['vassoura', 'limpar', 'limpeza'],
  '🧺': ['cesto', 'roupa', 'lavar'],
  '🌡️': ['termometro', 'temperatura', 'calor', 'frio', 'clima'],
  '❄️': ['frio', 'gelo', 'ar', 'neve', 'condicionado'],
  '🌀': ['ventilador', 'vento', 'girar', 'ar'],
  '🪭': ['leque', 'vento', 'ar'],
  '🕰️': ['relogio', 'antigo', 'hora', 'tempo'],
  '⏰': ['alarme', 'relogio', 'acordar', 'hora'],
  '🧯': ['extintor', 'fogo', 'emergencia'],

  // Ferramentas & Dev
  '🛠️': ['ferramentas', 'conserto', 'dev', 'construir'],
  '⚒️': ['martelo', 'ferramenta', 'bater', 'construir'],
  '🔧': ['chave', 'ferramenta', 'conserto', 'ajuste'],
  '🪛': ['chave', 'fenda', 'ferramenta', 'parafuso'],
  '🪚': ['serra', 'cortar', 'ferramenta', 'madeira'],
  '🧲': ['ima', 'magnetico', 'atrair'],
  '🧱': ['tijolo', 'construção', 'parede', 'bloco'],
  '🔬': ['microscopio', 'ciencia', 'pesquisa', 'detalhe'],
  '🔭': ['telescopio', 'ciencia', 'espaço', 'longe'],
  '📡': ['antena', 'sinal', 'rede', 'wifi', 'internet'],
  '🧩': ['quebra-cabeca', 'plugin', 'extensao', 'modulo', 'peça'],
  '🧪': ['tubo', 'teste', 'ciencia', 'quimica', 'laboratorio'],
  '🧮': ['abaco', 'calculo', 'matematica', 'contar'],
  '📊': ['grafico', 'dados', 'analytics', 'barras'],
  '📈': ['grafico', 'crescimento', 'subir', 'dados'],
  '📉': ['grafico', 'queda', 'descer', 'dados'],
  '📋': ['prancheta', 'lista', 'clipboard', 'copiar', 'tarefas'],

  // Comunicação
  '💬': ['balao', 'fala', 'chat', 'conversa', 'mensagem'],
  '🗨️': ['balao', 'fala', 'chat', 'conversa'],
  '🗯️': ['balao', 'grito', 'raiva', 'exclamação'],
  '💭': ['balao', 'pensamento', 'nuvem', 'imaginar'],
  '📧': ['email', 'correio', 'mensagem', 'arroba'],
  '📩': ['email', 'mensagem', 'receber', 'carta'],
  '📨': ['email', 'mensagem', 'enviar', 'carta'],
  '📦': ['caixa', 'pacote', 'entrega'],
  '📞': ['telefone', 'ligar', 'chamada'],
  '☎️': ['telefone', 'fixo', 'ligar', 'chamada'],
  '📟': ['pager', 'bip', 'mensagem', 'retro'],
  '📠': ['fax', 'enviar', 'documento'],
  '📢': ['mega-fone', 'anuncio', 'aviso', 'som'],
  '📣': ['mega-fone', 'torcida', 'aviso', 'som'],

  // Tempo & Clima
  '☀️': ['sol', 'dia', 'quente', 'claro', 'clima'],
  '🌤️': ['sol', 'nuvem', 'dia', 'clima'],
  '⛅': ['nuvem', 'sol', 'nublado', 'clima'],
  '🌥️': ['nuvem', 'sombra', 'nublado', 'clima'],
  '☁️': ['nuvem', 'nublado', 'clima'],
  '🌦️': ['chuva', 'sol', 'nuvem', 'clima'],
  '🌧️': ['chuva', 'nuvem', 'agua', 'clima'],
  '⛈️': ['raio', 'trovao', 'tempestade', 'chuva', 'nuvem', 'clima'],
  '🌩️': ['raio', 'trovao', 'tempestade', 'nuvem', 'clima'],
  '🌨️': ['neve', 'nuvem', 'frio', 'clima'],
  '💨': ['vento', 'ar', 'sopro'],
  '💧': ['gota', 'agua', 'chuva'],
  '☔': ['guarda-chuva', 'chuva', 'clima'],
  '☂️': ['guarda-chuva', 'chuva'],
  '🌙': ['lua', 'noite', 'escuro'],
  '🌛': ['lua', 'noite', 'rosto'],
  '🌟': ['estrela', 'brilho', 'destaque'],
  '⭐': ['estrela', 'favorito'],
  '⏳': ['ampulheta', 'tempo', 'espera', 'carregando'],
  '⌛': ['ampulheta', 'tempo', 'espera', 'pronto'],

  // Símbolos & Alertas
  '⚠️': ['aviso', 'alerta', 'perigo', 'atenção'],
  '⛔': ['proibido', 'parar', 'nao', 'bloqueado'],
  '🚫': ['proibido', 'nao', 'bloqueado', 'cancelar'],
  '❓': ['duvida', 'pergunta', 'interrogação'],
  '❔': ['duvida', 'pergunta', 'interrogação'],
  '❗': ['aviso', 'exclamação', 'alerta', 'importante'],
  '❕': ['aviso', 'exclamação', 'alerta'],
  '💯': ['100', 'cem', 'perfeito', 'nota'],
  '💢': ['raiva', 'veia', 'bravo'],
  '💤': ['sono', 'dormir', 'z'],
  '🌐': ['globo', 'mundo', 'internet', 'web', 'rede'],
  '💠': ['losango', 'ponto', 'diamante'],
  '⚕️': ['medicina', 'saude', 'medico', 'hospital'],
  '♻️': ['reciclar', 'meio ambiente', 'verde', 'loop'],
  '🟩': ['quadrado', 'verde', 'cor'],
  '🟥': ['quadrado', 'vermelho', 'cor'],
  '🟦': ['quadrado', 'azul', 'cor'],
  '🟨': ['quadrado', 'amarelo', 'cor'],
};
