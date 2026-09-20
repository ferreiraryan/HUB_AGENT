import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/layout.dart';

/// Dono unico do `layout.json`.
///
/// Toda a aplicacao le o estado daqui e escreve o estado aqui. O MqttService
/// se inscreve em [changes] e publica; a UI nunca publica direto. Esse e o
/// invariante que garante que o tablet jamais receba algo fora do disco.
class LayoutRepository {
  /// Arquivo de destino. O nucleo e Dart puro, entao quem resolve o diretorio
  /// e a camada de cima: no app Flutter, `path_provider`; no daemon,
  /// `$XDG_CONFIG_HOME/hub_agent/layout.json` ou `%APPDATA%`.
  final File file;

  /// Janela de agrupamento das escritas. Arrastar um slider de cor dispara
  /// ~60 eventos/s; sem isso voce mata o disco e inunda o broker.
  final Duration debounce;

  final _controller = StreamController<Layout>.broadcast();
  Timer? _timer;
  Future<void> _writeChain = Future.value();
  bool _disposed = false;

  Layout? _current;

  LayoutRepository({
    required this.file,
    this.debounce = const Duration(milliseconds: 400),
  });

  /// Emite a cada estado efetivamente persistido.
  Stream<Layout> get changes => _controller.stream;

  /// Ultimo estado conhecido. Lanca se [load] ainda nao rodou.
  Layout get current {
    final c = _current;
    if (c == null) {
      throw StateError('LayoutRepository.load() precisa rodar antes');
    }
    return c;
  }

  bool get isLoaded => _current != null;

  /// Le o disco. Em arquivo corrompido, preserva o original como `.bak` e
  /// sobe com o layout inicial, em vez de deixar o agente morto no boot.
  Future<Layout> load({required String fallbackDeviceName}) async {
    try {
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          _current = Layout.fromJson(json);
          _controller.add(_current!);
          return _current!;
        }
      }
    } catch (e) {
      final backup = File('${file.path}.bak');
      try {
        if (await file.exists()) await file.copy(backup.path);
      } catch (_) {/* backup e best effort */}
      stderr.writeln('layout.json invalido ($e). Backup em ${backup.path}');
    }

    _current = Layout.initial(fallbackDeviceName);
    await _writeNow(_current!);
    _controller.add(_current!);
    return _current!;
  }

  /// Agenda a persistencia. Retorna imediatamente: a UI ja deve ter atualizado
  /// o proprio estado antes de chamar isso.
  void save(Layout layout) {
    if (_disposed) return;
    _current = layout;
    _timer?.cancel();
    _timer = Timer(debounce, () => _commit(layout));
  }

  /// Persiste agora, ignorando o debounce. Chame ao fechar o app e antes de
  /// qualquer operacao que dependa do arquivo em disco.
  Future<void> flush() async {
    _timer?.cancel();
    final c = _current;
    if (c != null) _commit(c);
    await _writeChain;
  }

  void _commit(Layout layout) {
    // Serializa as escritas: duas gravacoes concorrentes no mesmo arquivo
    // sao a receita classica de JSON truncado.
    _writeChain = _writeChain.then((_) async {
      await _writeNow(layout);
      if (!_controller.isClosed) _controller.add(layout);
    }).catchError((Object e) {
      stderr.writeln('falha ao gravar layout: $e');
    });
  }

  /// Escrita atomica: grava em `.tmp` e renomeia. Rename e atomico no mesmo
  /// filesystem, entao uma queda de energia no meio nunca deixa um arquivo
  /// meio escrito.
  Future<void> _writeNow(Layout layout) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await tmp.writeAsString(encoder.convert(layout.toDiskJson()), flush: true);
    await tmp.rename(file.path);
  }

  Future<void> dispose() async {
    _disposed = true;
    await flush();
    _timer?.cancel();
    await _controller.close();
  }
}
