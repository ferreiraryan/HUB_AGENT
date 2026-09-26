import 'dart:convert';
import 'dart:io';

import '../models/layout.dart';
import 'audio/audio_controller.dart';
import 'media_service.dart';
import 'mqtt_service.dart';

/// Resultado de uma execucao de teste (botao "Testar" do CMS).
class CommandResult {
  final bool started;
  final int exitCode;
  final String stdout;
  final String stderr;
  final String? error;

  const CommandResult({
    required this.started,
    this.exitCode = -1,
    this.stdout = '',
    this.stderr = '',
    this.error,
  });

  bool get ok => started && exitCode == 0;
}

/// Roteia `action` -> handler tipado.
///
/// SEGURANCA: nada que chegue pelo MQTT vira comando de shell. O tablet manda
/// um `action`; se nao for embutida, o dispatcher procura a cadeia de comandos
/// em [Layout.bindings] e valida os binarios contra a whitelist. Uma mensagem
/// MQTT forjada so consegue disparar o que o usuario ja autorizou no CMS.
class CommandDispatcher {
  final AudioController audio;
  final MediaService media;

  /// Binarios permitidos. Vazia = permite qualquer binding do disco (o disco
  /// ja e territorio do usuario); populada = restringe ainda mais.
  final Set<String> allowedBinaries;

  /// Fonte do layout atual, para resolver bindings. Injetada como funcao para
  /// o dispatcher nao depender do repository.
  final Layout Function() layoutProvider;

  /// Chamado quando uma acao muda o volume, para o runtime armar a guarda
  /// de eco.
  final void Function()? onLocalVolumeChange;

  CommandDispatcher({
    required this.audio,
    required this.media,
    required this.layoutProvider,
    this.allowedBinaries = const {},
    this.onLocalVolumeChange,
  });

  Future<void> dispatch(AgentCommand cmd) async {
    switch (cmd.action) {
      case 'play_pause':
        await media.playPause();

      case 'next':
        await media.next();

      case 'prev':
        await media.previous();

      case 'set_volume':
        final v = cmd.value;
        if (v == null) {
          stderr.writeln('set_volume sem value');
          return;
        }
        onLocalVolumeChange?.call(); // arma a guarda de eco ANTES de aplicar
        await audio.setMasterVolume(v);

      case 'set_app_volume':
        final v = cmd.value;
        final id = cmd.appId;
        if (v == null || id == null) {
          stderr.writeln('set_app_volume exige app_id e value');
          return;
        }
        await audio.setAppVolume(id, v);

      case 'run_shortcut':
        final id = cmd.shortcutId;
        if (id == null) {
          stderr.writeln('run_shortcut sem id');
          return;
        }
        await runShortcut(id);

      default:
        // Contrato: "qualquer id de shortcut definido no layout".
        await runShortcut(cmd.action);
    }
  }

  /// Resolve a cadeia associada ao id e a executa com semantica &&.
  Future<bool> runShortcut(String id) async {
    final cmds = layoutProvider().bindingFor(id);
    if (cmds == null || cmds.isEmpty) {
      stderr.writeln('shortcut "$id" sem binding; ignorado');
      return false;
    }
    return _runChain(cmds);
  }

  /// Executa comandos em sequencia (&& semantics), parando no primeiro erro.
  Future<bool> _runChain(List<List<String>> cmds) async {
    if (cmds.length > 10) {
      stderr.writeln('limite de 10 comandos excedido no dispatcher');
      return false;
    }

    for (final argv in cmds) {
      if (argv.isEmpty) continue;
      if (!_isAllowed(argv.first)) {
        stderr.writeln('binario "${argv.first}" fora da whitelist; bloqueado');
        return false;
      }

      try {
        final proc = await Process.start(
          argv.first,
          argv.skip(1).toList(),
          runInShell: false,
        );

        // Consume stdout/stderr silenciosamente para evitar travamentos de buffer
        proc.stdout.listen((_) {});
        proc.stderr.listen((_) {});

        final code = await proc.exitCode;
        if (code != 0) {
          stderr.writeln('comando falhou com codigo $code:${argv.join(' ')}');
          return false;
        }
      } catch (e) {
        stderr.writeln('falha ao executar ${argv.join(' ')}:$e');
        return false;
      }
    }
    return true;
  }

  bool _isAllowed(String binary) =>
      allowedBinaries.isEmpty || allowedBinaries.contains(binary);

  /// Dispara e esquece individual. Retido para legado ou usos onde
  /// a semantica detached seja necessaria sem esperar exit.
  Future<bool> launch(List<String> argv) async {
    if (argv.isEmpty) return false;
    try {
      await Process.start(
        argv.first,
        argv.skip(1).toList(),
        mode: ProcessStartMode.detachedWithStdio,
        runInShell: false,
      );
      return true;
    } catch (e) {
      stderr.writeln('falha ao executar ${argv.join(' ')}:$e');
      return false;
    }
  }

  // ------------------------------------------------------ apoio ao CMS

  final Map<String, bool> _existsCache = {};

  Future<bool> exists(String executable) async {
    final cached = _existsCache[executable];
    if (cached != null) return cached;
    try {
      final probe = Platform.isWindows ? 'where' : 'which';
      final r = await Process.run(probe, [executable],
          runInShell: Platform.isWindows);
      return _existsCache[executable] = r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void clearCache() => _existsCache.clear();

  /// Testa uma cadeia de comandos inteira (para o CMS). Para no erro.
  Future<List<CommandResult>> testChain(List<List<String>> cmds,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final results = <CommandResult>[];
    if (cmds.length > 10) {
      return [
        const CommandResult(
            started: false, error: 'limite de 10 comandos excedido')
      ];
    }
    for (final argv in cmds) {
      if (argv.isEmpty) continue;
      final res = await test(argv, timeout: timeout);
      results.add(res);
      if (!res.ok) break;
    }
    return results;
  }

  /// Executa capturando saida, com timeout. So para o botao "Testar": nao use
  /// para apps de GUI, que nunca terminam.
  Future<CommandResult> test(List<String> argv,
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (argv.isEmpty) {
      return const CommandResult(started: false, error: 'comando vazio');
    }
    if (!await exists(argv.first)) {
      return CommandResult(
          started: false, error: '"${argv.first}" nao encontrado no PATH');
    }
    try {
      final proc = await Process.start(argv.first, argv.skip(1).toList());
      final out = StringBuffer();
      final err = StringBuffer();
      final subs = [
        proc.stdout.transform(utf8.decoder).listen(out.write),
        proc.stderr.transform(utf8.decoder).listen(err.write),
      ];
      final code = await proc.exitCode.timeout(timeout, onTimeout: () {
        proc.kill();
        return -1;
      });
      for (final s in subs) {
        await s.cancel();
      }
      return CommandResult(
        started: true,
        exitCode: code,
        stdout: out.toString(),
        stderr: err.toString(),
        error: code == -1 ? 'timeout apos ${timeout.inSeconds}s' : null,
      );
    } catch (e) {
      return CommandResult(started: false, error: '$e');
    }
  }
}
