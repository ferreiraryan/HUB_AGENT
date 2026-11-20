import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/agent_event.dart';
import '../models/tile.dart';
import '../models/layout.dart';
import '../util/hex_color.dart';
import 'audio/audio_controller.dart';
import 'brightness_controller.dart';
import 'clipboard/clipboard_service.dart';
import 'key_sender.dart';
import 'media_service.dart';
import 'mqtt_service.dart';
import 'osd/osd_service.dart';
import 'pomodoro/pomodoro_service.dart';
import 'sound/sound_controller.dart';
import 'todo/todo_service.dart';
import 'window/active_window_monitor.dart';

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
  final SoundController? sound;
  final PomodoroService? pomodoro;
  final TodoService? todo;
  final OsdService? osd;
  final ActiveWindowMonitor? activeWindow;
  final ClipboardService? clipboard;
  final Set<String> allowedBinaries;
  final Layout Function() layoutProvider;
  final void Function()? onLocalVolumeChange;
  final void Function(AgentEvent event)? onEvent;
  final void Function()? onRemoteSearchPrompt;
  final void Function()? onRemoteTodoPrompt;
  final void Function()? onOpenCms;
  final void Function(String text)? onPublishClipboard;
  final Future<void> Function()? onAudioOutputsRefresh;
  final void Function(String toggleId, String newState)? onToggle;
  final String Function(String toggleId)? getToggleState;

  CommandDispatcher({
    required this.audio,
    required this.brightness,
    required this.media,
    required this.keySender,
    required this.layoutProvider,
    this.sound,
    this.pomodoro,
    this.todo,
    this.osd,
    this.activeWindow,
    this.clipboard,
    this.allowedBinaries = const {},
    this.onLocalVolumeChange,
    this.onEvent,
    this.onRemoteSearchPrompt,
    this.onRemoteTodoPrompt,
    this.onOpenCms,
    this.onPublishClipboard,
    this.onAudioOutputsRefresh,
    this.onToggle,
    this.getToggleState,
  });

  String get _accentHex => argbToHex(layoutProvider().theme.accentColor);

  /// Invalida caches em memória de arquivos de som do controlador de som associado.
  void invalidateSoundCache() {
    sound?.invalidateSoundCache();
  }

  Future<void> dispatch(AgentCommand cmd) async {
    switch (cmd.action) {
      case 'play_pause':
        await media.playPause();

      case 'next':
        await media.next();

      case 'prev':
        await media.previous();

      case 'seek':
        final sec = cmd.value ?? (cmd.raw['position'] as num?)?.round();
        if (sec != null) await media.seek(sec);

      case 'rewind':
        final sec = cmd.value ?? (cmd.raw['seconds'] as num?)?.round() ?? 10;
        await media.rewind(sec);

      case 'fast_forward':
        final sec = cmd.value ?? (cmd.raw['seconds'] as num?)?.round() ?? 10;
        await media.fastForward(sec);

      case 'set_playback_rate':
      case 'set_media_speed':
        final rate = (cmd.raw['rate'] ?? cmd.raw['speed'] ?? cmd.value) as num?;
        if (rate != null) await media.setPlaybackRate(rate.toDouble());

      case 'set_volume':
        final v = cmd.value;
        if (v == null) {
          stderr.writeln('set_volume sem value');
          return;
        }
        onLocalVolumeChange?.call();
        await audio.setMasterVolume(v);
        unawaited(osd?.showSlider(
          title: 'Volume Master',
          value: v,
          icon: v == 0 ? 'mute' : 'volume',
          accentHex: _accentHex,
        ));

      case 'set_app_volume':
        final v = cmd.value;
        final id = cmd.appId;
        if (v == null || id == null) {
          stderr.writeln('set_app_volume exige app_id e value');
          return;
        }
        await audio.setAppVolume(id, v);
        unawaited(osd?.showSlider(
          title: id.replaceAll('.exe', ''),
          value: v,
          icon: 'volume',
          accentHex: _accentHex,
        ));

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
        await _applySlider(tile.id, tile.source, v);

      case 'play_sound':
        final soundId = cmd.soundId;
        if (soundId == null || soundId.isEmpty) {
          stderr.writeln('play_sound exige id ou sound_id');
          return;
        }
        await sound?.play(soundId);

      case 'stop_sound':
        await sound?.stop();

      case 'notify':
        final msg = cmd.message;
        if (msg == null || msg.trim().isEmpty) {
          stderr.writeln('notify exige "message"');
          return;
        }
        final event = AgentEvent.fromJson(cmd.raw);
        onEvent?.call(event);

      case 'remote_search_prompt':
        onRemoteSearchPrompt?.call();

      case 'remote_todo_prompt':
        onRemoteTodoPrompt?.call();

      case 'pomodoro_toggle':
        await pomodoro?.toggle();

      case 'pomodoro_skip':
        await pomodoro?.skip();

      case 'pomodoro_reset':
        await pomodoro?.reset();

      case 'todo_toggle':
        final itemId = cmd.raw['item_id']?.toString() ?? cmd.raw['id']?.toString();
        if (itemId != null && itemId.isNotEmpty) {
          await todo?.toggleItem(itemId);
        }

      case 'todo_add':
        final text = cmd.raw['text']?.toString() ?? cmd.raw['title']?.toString();
        if (text != null && text.trim().isNotEmpty) {
          await todo?.addItem(text.trim());
        }

      case 'todo_remove':
        final itemId = cmd.raw['item_id']?.toString() ?? cmd.raw['id']?.toString();
        if (itemId != null && itemId.isNotEmpty) {
          await todo?.removeItem(itemId);
        }

      case 'todo_clear_done':
        await todo?.clearDone();

      case 'mute_master':
      case 'vol_up':
      case 'vol_down':
      case 'lock_screen':
      case 'open_cms':
      case 'toggle_mic_mute':
      case 'window_always_on_top':
      case 'clipboard_sync_to_tablet':
        await _tryDispatchBuiltin(cmd.action);

      case 'set_mic_mute':
        final muted = cmd.raw['muted'] == true || cmd.value == 1;
        if (audio case final ExtendedAudioController ext) {
          await ext.setMicMute(muted);
          unawaited(osd?.showBadge(
            title: 'Microfone',
            subtitle: muted ? 'Mutado' : 'Ativo',
            icon: muted ? 'mic_off' : 'mic',
            accentHex: muted ? '#f38ba8' : '#a6e3a1',
          ));
        }

      case 'set_audio_output':
        final dev = cmd.raw['device']?.toString() ?? cmd.raw['name']?.toString() ?? '';
        if (dev.isNotEmpty && audio is ExtendedAudioController) {
          await (audio as ExtendedAudioController).setDefaultOutput(dev);
          await onAudioOutputsRefresh?.call();
          unawaited(osd?.showBadge(
            title: 'Saída de Áudio',
            subtitle: dev,
            icon: 'volume',
            accentHex: _accentHex,
          ));
        }

      case 'clipboard_set_pc':
        final text = cmd.raw['text']?.toString() ?? '';
        final paste = cmd.raw['paste'] == true;
        if (text.isNotEmpty && clipboard != null) {
          final ok = await clipboard!.setText(text);
          if (ok && paste) {
            await Future<void>.delayed(const Duration(milliseconds: 60));
            await keySender.send('ctrl+v');
          }
          if (ok) {
            unawaited(osd?.showBadge(
              title: 'Clipboard',
              subtitle: paste ? 'Texto colado no PC' : 'Copiado para o PC',
              icon: 'clip',
              accentHex: _accentHex,
            ));
          }
        }

      case 'toggle':
        final id = cmd.raw['id']?.toString();
        if (id != null) {
          final toggleTile = _findToggleTile(id);
          if (toggleTile != null) {
            await _handleToggle(toggleTile);
            return;
          }
        }

      default:
        if (cmd.action == 'stop_sound' || cmd.action.startsWith('stop_sound')) {
          await sound?.stop();
          return;
        }

        final toggleTile = _findToggleTile(cmd.action);
        if (toggleTile != null) {
          await _handleToggle(toggleTile);
          return;
        }

        final soundTile = _findSoundTile(cmd.action);
        if (soundTile != null) {
          await sound?.play(soundTile.soundId);
          return;
        }

        final pomodoroTile = _findPomodoroTile(cmd.action);
        if (pomodoroTile != null) {
          await pomodoro?.toggle();
          return;
        }

        final todoTile = _findTodoTile(cmd.action);
        if (todoTile != null) {
          return;
        }

        final shortcut = _findShortcutTile(cmd.action);
        if (shortcut != null) {
          if (shortcut.id == 'stop_sound' || shortcut.id.startsWith('stop_sound')) {
            await sound?.stop();
            return;
          }
          final labelNorm = shortcut.label.trim().toLowerCase();
          if (labelNorm == 'parar sons' ||
              labelNorm == 'parar tudo' ||
              labelNorm == 'parar som' ||
              labelNorm == 'stop sound' ||
              labelNorm == 'stop sounds') {
            await sound?.stop();
            return;
          }
        }

        await runShortcut(cmd.action);
    }
  }

  Future<void> _handleToggle(ToggleTile tile) async {
    final currentState = getToggleState?.call(tile.id) ?? tile.initialState;
    final nextState = (currentState.toLowerCase() == 'a') ? 'b' : 'a';

    final layout = layoutProvider();
    final specificKey = '${tile.id}:$nextState';
    final bindingKey = layout.bindings.containsKey(specificKey) ? specificKey : tile.id;

    if (layout.bindings.containsKey(bindingKey)) {
      await runShortcut(bindingKey);
    }
    onToggle?.call(tile.id, nextState);
    final cfg = nextState == 'b' ? tile.stateB : tile.stateA;
    unawaited(osd?.showBadge(
      title: tile.label.isNotEmpty ? tile.label : tile.id,
      subtitle: cfg.label.isNotEmpty ? cfg.label : 'Estado ${nextState.toUpperCase()}',
      icon: 'toggle',
      accentHex: _accentHex,
    ));
  }

  T? _findTile<T extends Tile>(String id) => layoutProvider().findTile<T>(id);

  ToggleTile? _findToggleTile(String id) => _findTile<ToggleTile>(id);
  ToggleTile? findToggleTile(String id) => _findTile<ToggleTile>(id);
  SoundTile? _findSoundTile(String id) => _findTile<SoundTile>(id);
  PomodoroTile? _findPomodoroTile(String id) => _findTile<PomodoroTile>(id);
  TodoTile? _findTodoTile(String id) => _findTile<TodoTile>(id);
  SliderTile? _findSliderTile(String id) => _findTile<SliderTile>(id);
  SliderTile? findSliderTile(String id) => _findSliderTile(id);
  ShortcutTile? _findShortcutTile(String id) => _findTile<ShortcutTile>(id);

  Future<bool> _tryDispatchBuiltin(String action) async {
    switch (action) {
      case 'stop_sound':
        await sound?.stop();
        return true;
      case 'play_pause':
        await media.playPause();
        return true;
      case 'next':
        await media.next();
        return true;
      case 'prev':
        await media.previous();
        return true;
      case 'remote_search_prompt':
        onRemoteSearchPrompt?.call();
        return true;

      case 'remote_todo_prompt':
        onRemoteTodoPrompt?.call();
        return true;
      case 'pomodoro_toggle':
        await pomodoro?.toggle();
        return true;
      case 'pomodoro_skip':
        await pomodoro?.skip();
        return true;
      case 'pomodoro_reset':
        await pomodoro?.reset();
        return true;
      case 'mute_master':
        final nextMuted = !audio.master.muted;
        onLocalVolumeChange?.call();
        await audio.setMute(nextMuted);
        onEvent?.call(AgentEvent.info(
          nextMuted ? 'Áudio silenciado' : 'Áudio restaurado',
        ));
        unawaited(osd?.showBadge(
          title: 'Áudio Master',
          subtitle: nextMuted ? 'Silenciado' : 'Restaurado (${audio.master.value}%)',
          icon: nextMuted ? 'mute' : 'volume',
          accentHex: nextMuted ? '#f38ba8' : _accentHex,
        ));
        return true;
      case 'vol_up':
        final nextUp = (audio.master.value + 5).clamp(0, 100);
        onLocalVolumeChange?.call();
        await audio.setMasterVolume(nextUp);
        unawaited(osd?.showSlider(
          title: 'Volume Master',
          value: nextUp,
          icon: 'volume',
          accentHex: _accentHex,
        ));
        return true;
      case 'vol_down':
        final nextDown = (audio.master.value - 5).clamp(0, 100);
        onLocalVolumeChange?.call();
        await audio.setMasterVolume(nextDown);
        unawaited(osd?.showSlider(
          title: 'Volume Master',
          value: nextDown,
          icon: nextDown == 0 ? 'mute' : 'volume',
          accentHex: _accentHex,
        ));
        return true;
      case 'toggle_mic_mute':
        if (audio case final ExtendedAudioController ext) {
          final nextMuted = !ext.mic.muted;
          await ext.setMicMute(nextMuted);
          unawaited(osd?.showBadge(
            title: 'Microfone',
            subtitle: nextMuted ? 'Mutado' : 'Ativo',
            icon: nextMuted ? 'mic_off' : 'mic',
            accentHex: nextMuted ? '#f38ba8' : '#a6e3a1',
          ));
        }
        return true;
      case 'window_always_on_top':
        final res = await activeWindow?.toggleTopmost();
        if (res != null) {
          unawaited(osd?.showBadge(
            title: res.$1 ? 'Janela fixada no topo' : 'Janela desafixada',
            subtitle: res.$2,
            icon: 'pin',
            accentHex: res.$1 ? '#a6e3a1' : _accentHex,
          ));
          onEvent?.call(AgentEvent.info(
            res.$1 ? '📌 Fixada no topo: ${res.$2}' : 'Desafixada: ${res.$2}',
          ));
        }
        return true;
      case 'clipboard_sync_to_tablet':
        if (clipboard != null) {
          final txt = await clipboard!.getText();
          onPublishClipboard?.call(txt);
          unawaited(osd?.showBadge(
            title: 'Clipboard',
            subtitle: txt.isEmpty ? 'Área vazia' : 'Enviado para o tablet',
            icon: 'clip',
            accentHex: _accentHex,
          ));
        }
        return true;
      case 'lock_screen':
        await _lockScreen();
        return true;
      case 'open_cms':
        onOpenCms?.call();
        return true;
      default:
        return false;
    }
  }

  Future<void> _lockScreen() async {
    try {
      if (Platform.isWindows) {
        await Process.start(
          'rundll32.exe',
          ['user32.dll,LockWorkStation'],
          runInShell: false,
        );
      } else if (Platform.isLinux) {
        await Process.start('loginctl', ['lock-session'], runInShell: false);
      }
    } catch (e) {
      stderr.writeln('lock_screen falhou: $e');
    }
  }

  Future<void> _applySlider(String sliderId, SliderSource source, int value) async {
    final tile = _findSliderTile(sliderId);
    final label = (tile != null && tile.label.trim().isNotEmpty) ? tile.label.trim() : sliderId;

    switch (source.kind) {
      case SliderSource.kindMasterVolume:
        onLocalVolumeChange?.call();
        await audio.setMasterVolume(value);
        unawaited(osd?.showSlider(
          title: label,
          value: value,
          icon: value == 0 ? 'mute' : 'volume',
          accentHex: _accentHex,
        ));

      case SliderSource.kindAppVolume:
        final match = source.match;
        if (match == null || match.isEmpty) {
          stderr.writeln('slider app_volume sem "match"');
          return;
        }
        await audio.setAppVolumeByName(match, value);
        unawaited(osd?.showSlider(
          title: label,
          value: value,
          icon: 'volume',
          accentHex: _accentHex,
        ));

      case SliderSource.kindBrightness:
        final match = (source.match ?? '').trim();
        if (match.isEmpty) {
          await brightness.set(value);
        } else {
          await brightness.setForDisplay(match, value);
        }
        unawaited(osd?.showSlider(
          title: label,
          value: value,
          icon: 'brightness',
          accentHex: _accentHex,
        ));
        return;

      case SliderSource.kindSoundVolume:
        await sound?.setVolume(value);
        unawaited(osd?.showSlider(
          title: label,
          value: value,
          icon: 'sound',
          accentHex: _accentHex,
        ));
        return;

      case SliderSource.kindCustom:
        final bindingCmds = layoutProvider().bindingFor(sliderId);
        final cmd = (bindingCmds != null && bindingCmds.isNotEmpty)
            ? bindingCmds.first
            : source.cmd;
        if (cmd == null || cmd.isEmpty) {
          stderr.writeln('slider custom sem cmd');
          return;
        }
        await _runWithEnv(cmd, {'VALUE': value.toString()});
        unawaited(osd?.showSlider(
          title: label,
          value: value,
          icon: 'toggle',
          accentHex: _accentHex,
        ));
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
        runInShell: Platform.isWindows,
      );
    } catch (e) {
      stderr.writeln('slider custom ${argv.join(' ')} falhou: $e');
    }
  }

  Future<bool> runShortcut(String id) async {
    if (id == 'stop_sound' || id.startsWith('stop_sound')) {
      await sound?.stop();
      return true;
    }
    if (id == 'play_pause') {
      await media.playPause();
      return true;
    }
    if (id == 'next') {
      await media.next();
      return true;
    }
    if (id == 'prev') {
      await media.previous();
      return true;
    }
    if (id == 'remote_search_prompt') {
      onRemoteSearchPrompt?.call();
      return true;
    }
    if (id == 'remote_todo_prompt') {
      onRemoteTodoPrompt?.call();
      return true;
    }
    if (await _tryDispatchBuiltin(id)) {
      return true;
    }

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

      if (argv.first == '__builtin__') {
        final action = argv.length > 1 ? argv[1] : '';
        await _tryDispatchBuiltin(action);
        continue;
      }

      if (argv.first == '__delay__') {
        final rawMs = argv.length > 1 ? int.tryParse(argv[1]) : null;
        final ms = (rawMs ?? 300).clamp(10, 30000);
        await Future<void>.delayed(Duration(milliseconds: ms));
        continue;
      }

      if (argv.first == '__open_url__') {
        if (argv.length < 2 || argv[1].trim().isEmpty) {
          stderr.writeln('__open_url__ sem argumento');
          return false;
        }
        final ok = await _openUrlOrPath(argv[1].trim());
        if (!ok) return false;
        continue;
      }

      if (argv.first == '__type_text__') {
        if (argv.length < 2) {
          stderr.writeln('__type_text__ sem argumento');
          return false;
        }
        final ok = await _typeText(argv[1]);
        if (!ok) return false;
        continue;
      }

      if (argv.first == '__http__') {
        if (argv.length < 3) {
          stderr.writeln('__http__ exige metodo e URL');
          return false;
        }
        final method = argv[1].trim().toUpperCase();
        final url = argv[2].trim();
        final body = argv.length > 3 ? argv[3] : null;
        final ok = await _runHttpWebhook(method, url, body);
        if (!ok) return false;
        continue;
      }

      if (await _tryDispatchBuiltin(argv.first)) {
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
          runInShell: Platform.isWindows,
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

  Future<bool> _openUrlOrPath(String target) async {
    try {
      if (Platform.isWindows) {
        await Process.start(
          'cmd',
          ['/c', 'start', '', target],
          mode: ProcessStartMode.detached,
          runInShell: false,
        );
        return true;
      } else if (Platform.isLinux) {
        await Process.start(
          'xdg-open',
          [target],
          mode: ProcessStartMode.detached,
          runInShell: false,
        );
        return true;
      } else if (Platform.isMacOS) {
        await Process.start(
          'open',
          [target],
          mode: ProcessStartMode.detached,
          runInShell: false,
        );
        return true;
      }
      return false;
    } catch (e) {
      stderr.writeln('__open_url__ falhou ($target): $e');
      return false;
    }
  }

  Future<bool> _typeText(String text) async {
    try {
      if (Platform.isWindows) {
        final escaped = text.replaceAll("'", "''");
        final r = await Process.run(
          'powershell',
          ['-NoProfile', '-Command', "Set-Clipboard -Value '$escaped'"],
          runInShell: false,
        ).timeout(const Duration(seconds: 3));
        if (r.exitCode != 0) return false;
        await Future<void>.delayed(const Duration(milliseconds: 60));
        return await keySender.send('ctrl+v');
      } else if (Platform.isLinux) {
        if (await exists('wtype')) {
          final r = await Process.run('wtype', ['--', text], runInShell: false);
          return r.exitCode == 0;
        }
        if (await exists('xdotool')) {
          final r = await Process.run(
              'xdotool', ['type', '--clearmodifiers', '--', text],
              runInShell: false);
          return r.exitCode == 0;
        }
        return false;
      }
      return false;
    } catch (e) {
      stderr.writeln('__type_text__ falhou: $e');
      return false;
    }
  }

  Future<bool> _runHttpWebhook(
      String method, String url, String? body) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      stderr.writeln('__http__: URL invalida "$url"');
      return false;
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 5));
      if (body != null && body.isNotEmpty) {
        final trimmed = body.trim();
        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          req.headers.contentType = ContentType.json;
        } else {
          req.headers.contentType = ContentType.text;
        }
        req.write(body);
      }
      final resp = await req.close().timeout(const Duration(seconds: 5));
      await resp.drain<void>();
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (!ok) {
        stderr.writeln('__http__: status ${resp.statusCode} em $url');
        onEvent?.call(AgentEvent.error(
          'Webhook falhou (${resp.statusCode})',
        ));
      }
      return ok;
    } catch (e) {
      stderr.writeln('__http__ falhou ($url): $e');
      onEvent?.call(AgentEvent.error(
        'Erro no webhook: $e',
      ));
      return false;
    } finally {
      client.close(force: true);
    }
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
        runInShell: Platform.isWindows,
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

    if (argv.first == '__builtin__') {
      if (argv.length < 2 || argv[1].trim().isEmpty) {
        return const CommandResult(
            started: false, error: '__builtin__ sem ação');
      }
      return CommandResult(
        started: true,
        exitCode: 0,
        stdout: 'ação interna "${argv[1]}" validada',
      );
    }

    if (argv.first == '__delay__') {
      final ms = argv.length > 1 ? int.tryParse(argv[1]) : null;
      if (ms == null || ms <= 0) {
        return const CommandResult(
            started: false, error: '__delay__ exige milissegundos > 0');
      }
      return CommandResult(
        started: true,
        exitCode: 0,
        stdout: 'pausa de ${ms.clamp(10, 30000)} ms validada',
      );
    }

    if (argv.first == '__open_url__') {
      if (argv.length < 2 || argv[1].trim().isEmpty) {
        return const CommandResult(
            started: false, error: '__open_url__ sem URL/caminho');
      }
      return CommandResult(
        started: true,
        exitCode: 0,
        stdout: 'alvo "${argv[1]}" validado',
      );
    }

    if (argv.first == '__type_text__') {
      if (argv.length < 2 || argv[1].isEmpty) {
        return const CommandResult(
            started: false, error: '__type_text__ sem texto');
      }
      return const CommandResult(
        started: true,
        exitCode: 0,
        stdout: 'texto validado (não digitado no teste)',
      );
    }

    if (argv.first == '__http__') {
      if (argv.length < 3) {
        return const CommandResult(
            started: false, error: '__http__ exige método e URL');
      }
      final uri = Uri.tryParse(argv[2].trim());
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return CommandResult(
            started: false, error: 'URL inválida: "${argv[2]}"');
      }
      return CommandResult(
        started: true,
        exitCode: 0,
        stdout: 'webhook ${argv[1].toUpperCase()} ${argv[2]} validado',
      );
    }

    if (!await exists(argv.first)) {
      return CommandResult(
          started: false, error: '"${argv.first}" nao encontrado no PATH');
    }

    try {
      final proc = await Process.start(argv.first, argv.skip(1).toList(),
          runInShell: Platform.isWindows);
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
