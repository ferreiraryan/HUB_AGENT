import 'dart:convert';
import 'dart:io';
import '../models/tile.dart';
import '../models/layout.dart';
import 'audio/audio_controller.dart';
import 'brightness_controller.dart';
import 'key_sender.dart';
import 'media_service.dart';
import 'mqtt_service.dart';

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

class CommandDispatcher {
  final AudioController audio;
  final BrightnessController brightness;
  final MediaService media;
  final KeySender keySender;
  final Set<String> allowedBinaries;
  final Layout Function() layoutProvider;
  final void Function()? onLocalVolumeChange;

  CommandDispatcher({
    required this.audio,
    required this.brightness,
    required this.media,
    required this.keySender,
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
        onLocalVolumeChange?.call();
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

      case 'set_slider':
        final id = cmd.sliderId;
        final v = cmd.value;
        if (id == null || v == null) {
          stderr.writeln('set_slider exige id e value');
          return;
        }
        final tile = _findSliderTile(id);
        if (tile == null) {
          stderr.writeln('set_slider: slider "$id" nao encontrado no layout');
          return;
        }
        await _applySlider(tile.source, v);

      default:
        await runShortcut(cmd.action);
    }
  }

  SliderTile? _findSliderTile(String id) {
    final layout = layoutProvider();
    for (final tiles in layout.pages.values) {
      for (final t in tiles) {
        if (t is SliderTile && t.id == id) return t;
      }
    }
    return null;
  }

  Future<void> _applySlider(SliderSource source, int value) async {
    switch (source.kind) {
      case SliderSource.kindMasterVolume:
        onLocalVolumeChange?.call();
        await audio.setMasterVolume(value);

      case SliderSource.kindAppVolume:
        final match = source.match;
        if (match == null || match.isEmpty) {
          stderr.writeln('slider app_volume sem "match"');
          return;
        }
        await audio.setAppVolumeByName(match, value);

      case SliderSource.kindBrightness:
        final match = (source.match ?? '').trim();
        if (match.isEmpty) {
          await brightness.set(value);
        } else {
          await brightness.setForDisplay(match, value);
        }
        return;

      case SliderSource.kindCustom:
        final cmd = source.cmd;
        if (cmd == null || cmd.isEmpty) {
          stderr.writeln('slider custom sem cmd');
          return;
        }
        await _runWithEnv(cmd, {'VALUE': value.toString()});
    }
  }

  Future<void> _runWithEnv(List<String> argv, Map<String, String> env) async {
    if (argv.isEmpty) return;
    if (!_isAllowed(argv.first)) {
      stderr.writeln('binario "${argv.first}" fora da whitelist; bloqueado');
      return;
    }
    try {
      await Process.start(
        argv.first,
        argv.skip(1).toList(),
        environment: env,
        runInShell: false,
      );
    } catch (e) {
      stderr.writeln('slider custom ${argv.join(' ')} falhou: $e');
    }
  }

  Future<bool> runShortcut(String id) async {
    final cmds = layoutProvider().bindingFor(id);
    if (cmds == null || cmds.isEmpty) {
      stderr.writeln('shortcut "$id" sem binding; ignorado');
      return false;
    }
    return _runChain(cmds);
  }

  Future<bool> _runChain(List<List<String>> cmds) async {
    if (cmds.length > 10) {
      stderr.writeln('limite de 10 comandos excedido no dispatcher');
      return false;
    }

    for (final argv in cmds) {
      if (argv.isEmpty) continue;

      if (argv.first == '__sendkeys__') {
        if (argv.length < 2) {
          stderr.writeln('__sendkeys__ sem argumento');
          return false;
        }
        final ok = await keySender.send(argv[1]);
        if (!ok) {
          stderr.writeln('__sendkeys__: combo inválida: "${argv[1]}"');
          return false;
        }
        continue;
      }

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

  Future<CommandResult> test(List<String> argv,
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (argv.isEmpty) {
      return const CommandResult(started: false, error: 'comando vazio');
    }

    if (argv.first == '__sendkeys__') {
      if (argv.length < 2) {
        return const CommandResult(
            started: false, error: '__sendkeys__ sem argumento');
      }
      return const CommandResult(
        started: true,
        exitCode: 0,
        stdout: 'tecla validada (não executada no teste)',
      );
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
