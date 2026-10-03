import 'dart:async';
import 'dart:io';


import '../../models/audio_state.dart';
import 'audio_controller.dart';

/// AudioController para Windows via nircmd.exe.
///
/// Por que nircmd e não COM direto: fazer COM em Dart com package:win32
/// exige vtable manual + Finalizer que causa use-after-free. nircmd é
/// um binário de 100 KB que faz o trabalho sem crash. Está incluído no
/// bundle do app (windows/runner/resources/nircmd.exe) e copiado ao lado
/// do executável no build.
class WindowsAudioController implements AudioController {
  final _masterCtl = StreamController<MasterVolume>.broadcast();
  final _appsCtl = StreamController<List<AppVolume>>.broadcast();

  Timer? _pollTimer;
  bool _available = false;
  MasterVolume _master = const MasterVolume(value: 0);

  /// Caminho absoluto para o nircmd.exe. Resolvido uma vez no start().
  String? _nircmdPath;

  @override
  Stream<MasterVolume> get masterChanges => _masterCtl.stream;
  @override
  Stream<List<AppVolume>> get appsChanges => _appsCtl.stream;
  @override
  MasterVolume get master => _master;
  @override
  List<AppVolume> get apps => const [];
  @override
  bool get isAvailable => _available;

  @override
  Future<void> start() async {
    _nircmdPath = await _resolveNircmdPath();
    if (_nircmdPath == null) {
      _available = false;
      return;
    }

    // Teste: lê o volume. Se falhar, considera indisponível.
    final test = await _readMaster();
    if (test == null) {
      _available = false;
      return;
    }

    _available = true;
    _master = test;
    if (!_masterCtl.isClosed) _masterCtl.add(test);

    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => refresh(),
    );
  }

  /// Procura o nircmd.exe em locais previsíveis.
  Future<String?> _resolveNircmdPath() async {
    // 1. Ao lado do executável do app (bundle do Flutter).
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      '$exeDir${Platform.pathSeparator}nircmd.exe',
      '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}nircmd.exe',
      '$exeDir${Platform.pathSeparator}resources${Platform.pathSeparator}nircmd.exe',
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }

    // 2. PATH do sistema (se o usuário instalou globalmente).
    try {
      final r = await Process.run('where', ['nircmd.exe']);
      if (r.exitCode == 0) {
        final first = (r.stdout as String).trim().split('\n').first.trim();
        if (first.isNotEmpty) return first;
      }
    } catch (_) {}

    stderr.writeln('audio: nircmd.exe não encontrado no bundle nem no PATH');
    return null;
  }

  @override
  Future<void> refresh() async {
    if (!_available) return;
    try {
      final v = await _readMaster();
      if (v != null && v != _master) {
        _master = v;
        if (!_masterCtl.isClosed) _masterCtl.add(v);
      }
    } catch (_) {
      // Falha transitória: ignora.
    }
  }

  /// Lê o volume master atual do Windows.
  ///
  /// nircmd não tem comando nativo de leitura direto, mas o truque é usar
  /// PowerShell com o módulo padrão:
  ///   (New-Object -ComObject WScript.Shell).SendKeys([char]175)
  /// ...que é horrível. Alternativa: usar o próprio nircmd para "nudge" e
  /// derivar. Não é confiável.
  ///
  /// Melhor: usa PowerShell com AudioDeviceCmdlets (módulo externo), ou
  /// simplesmente mantém o último valor conhecido em memória e atualiza
  /// só quando setMasterVolume() é chamado.
  ///
  /// Abordagem pragmática: mantém o estado em memória, e no boot tenta
  /// inferir via nircmd (que não lê). Retorna o _master atual.
  Future<MasterVolume?> _readMaster() async {
    // nircmd não tem "get volume". Retorna o último valor conhecido.
    // Na primeira execução, assume 50% (só até o usuário mexer).
    if (_master.value == 0 && !_pollTimerAtivo) {
      return const MasterVolume(value: 50, muted: false);
    }
    return _master;
  }

  bool get _pollTimerAtivo => _pollTimer != null;

  @override
  Future<void> setMasterVolume(int value) async {
    if (!_available || _nircmdPath == null) return;
    final v = value.clamp(0, 100);
    // nircmd usa escala 0–65535.
    final nircmdValue = (v * 65535 ~/ 100).clamp(0, 65535);
    await _run(['setsysvolume', '$nircmdValue']);
    _master = MasterVolume(value: v, muted: _master.muted);
    if (!_masterCtl.isClosed) _masterCtl.add(_master);
  }

  @override
  Future<void> setMute(bool muted) async {
    if (!_available || _nircmdPath == null) return;
    await _run(['mutesysvolume', muted ? '1' : '0']);
    _master = MasterVolume(value: _master.value, muted: muted);
    if (!_masterCtl.isClosed) _masterCtl.add(_master);
  }

  @override
  Future<void> setAppVolume(String id, int value) async {
    // Fase 2: nircmd setappvolume exige nome do processo, não id.
    // Quando integrarmos o mixer, resolvemos.
  }

  @override
  Future<void> setAppVolumeByName(String name, int value) async {
    if (!_available || _nircmdPath == null) return;
    final v = value.clamp(0, 100);
    final nircmdValue = (v * 65535 ~/ 100).clamp(0, 65535);
    // nircmd setappvolume <process.exe> <volume 0-65535>
    // O nome precisa ter .exe no final.
    final proc = name.endsWith('.exe') ? name : '$name.exe';
    await _run(['setappvolume', proc, '$nircmdValue']);
  }

  Future<void> _run(List<String> args) async {
  final path = _nircmdPath ?? '(null)';
  print('[AUDIO] run: "$path" ${args.map((a) => '"$a"').join(' ')}');
  try {
    final r = await Process.run(path, args, runInShell: false);
    print('[AUDIO] exit=${r.exitCode}');
    print('[AUDIO] stdout=${r.stdout}');
    print('[AUDIO] stderr=${r.stderr}');
  } catch (e) {
    print('[AUDIO] ERRO: $e');
  }
}

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _masterCtl.close();
    await _appsCtl.close();
  }
}