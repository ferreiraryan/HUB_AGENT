import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('MqttService deduplicação de tópicos retidos', () {
    test('evita reenvio de payloads retidos idênticos e permite force/mudança', () {
      final mqtt = MqttService(host: '127.0.0.1', deviceId: 'test-pc');

      expect(mqtt.shouldPublishRetained('nodes/test-pc/stats/disk', '{"percent":40}'), isTrue);
      // Payload idêntico deve ser ignorado
      expect(mqtt.shouldPublishRetained('nodes/test-pc/stats/disk', '{"percent":40}'), isFalse);
      // Force deve permitir reenvio
      expect(mqtt.shouldPublishRetained('nodes/test-pc/stats/disk', '{"percent":40}', force: true), isTrue);
      // Payload alterado deve ser enviado
      expect(mqtt.shouldPublishRetained('nodes/test-pc/stats/disk', '{"percent":41}'), isTrue);
      // Após limpar cache (ex: reconexão), deve voltar a enviar
      mqtt.clearPublishCache();
      expect(mqtt.shouldPublishRetained('nodes/test-pc/stats/disk', '{"percent":41}'), isTrue);
    });
  });

  group('MediaService emissão inteligente', () {
    test('suprime ticks contínuos normais, detecta seek manual e calibra no intervalo', () async {
      final media = MediaService(positionSyncInterval: const Duration(seconds: 12));
      final emitted = <MediaState>[];
      final sub = media.changes.listen(emitted.add);

      final t0 = DateTime(2026, 11, 20, 12, 0, 0);
      const s0 = MediaState(
        status: PlaybackStatus.playing,
        title: 'Faixa A',
        artist: 'Artista A',
        position: 10,
        duration: 200,
        playbackRate: 1.0,
      );

      // 1. Primeira emissão sempre passa
      media.acceptState(s0, now: t0);
      await Future<void>.delayed(Duration.zero);
      expect(emitted.length, equals(1));

      // 2. Avanço normal de 1s em 1s deve ser suprimido (tablet interpola)
      media.acceptState(
        const MediaState(
          status: PlaybackStatus.playing,
          title: 'Faixa A',
          artist: 'Artista A',
          position: 11,
          duration: 200,
          playbackRate: 1.0,
        ),
        now: t0.add(const Duration(seconds: 1)),
      );
      media.acceptState(
        const MediaState(
          status: PlaybackStatus.playing,
          title: 'Faixa A',
          artist: 'Artista A',
          position: 15,
          duration: 200,
          playbackRate: 1.0,
        ),
        now: t0.add(const Duration(seconds: 5)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(emitted.length, equals(1));
      expect(media.current.position, equals(15));

      // 3. Seek manual (> 2.5s de desvio) deve emitir imediatamente
      media.acceptState(
        const MediaState(
          status: PlaybackStatus.playing,
          title: 'Faixa A',
          artist: 'Artista A',
          position: 90,
          duration: 200,
          playbackRate: 1.0,
        ),
        now: t0.add(const Duration(seconds: 6)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(emitted.length, equals(2));
      expect(emitted.last.position, equals(90));

      // 4. Calibração periódica após 12s deve emitir
      media.acceptState(
        const MediaState(
          status: PlaybackStatus.playing,
          title: 'Faixa A',
          artist: 'Artista A',
          position: 102,
          duration: 200,
          playbackRate: 1.0,
        ),
        now: t0.add(const Duration(seconds: 18)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(emitted.length, equals(3));

      // 5. Pausa deve emitir imediatamente
      media.acceptState(
        const MediaState(
          status: PlaybackStatus.paused,
          title: 'Faixa A',
          artist: 'Artista A',
          position: 103,
          duration: 200,
          playbackRate: 1.0,
        ),
        now: t0.add(const Duration(seconds: 19)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(emitted.length, equals(4));

      await sub.cancel();
      media.dispose();
    });
  });

  group('PomodoroService economia de emissões', () {
    test('emite imediatamente em ações e reduz ticks contínuos conforme syncIntervalSeconds', () async {
      final pomo = PomodoroService(
        focusDurationMinutes: 1,
        syncIntervalSeconds: 15,
      );
      final emitted = <PomodoroState>[];
      final sub = pomo.changes.listen(emitted.add);

      await pomo.toggle();
      await Future<void>.delayed(Duration.zero);
      expect(emitted.length, equals(1));

      // Aguarda 2.3s: o timer interno avança, mas não dispara pacotes MQTT a cada 1s
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      expect(pomo.current.remainingMs, lessThan(60 * 1000));
      expect(emitted.length, equals(1));

      // Pausar emite imediatamente
      await pomo.toggle();
      await Future<void>.delayed(Duration.zero);
      expect(emitted.length, equals(2));
      expect(emitted.last.isRunning, isFalse);

      await sub.cancel();
      await pomo.dispose();
    });
  });

  group('ScreensaverRepository debounce de emissão', () {
    test('agrupa múltiplas atualizações rápidas em uma única emissão no stream', () async {
      final dir = await Directory.systemTemp.createTemp('ss_debounce_test_');
      addTearDown(() => dir.delete(recursive: true));

      final repo = ScreensaverRepository(
        file: File('${dir.path}/screensaver.json'),
        debounce: const Duration(milliseconds: 80),
      );
      await repo.load();

      final emitted = <ScreensaverConfig>[];
      final sub = repo.changes.listen(emitted.add);

      // Simula arrasto rápido de 20 frames
      for (var i = 0; i < 20; i++) {
        repo.update(repo.current.copyWith(backgroundDim: (i * 0.03).clamp(0.0, 0.85)));
      }
      expect(emitted, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(emitted.length, equals(1));

      await sub.cancel();
      await repo.dispose();
    });
  });

  group('WindowsHelperBridge protocolo NDJSON', () {
    test('roteia eventos assíncronos de janela ativa, áudio, mídia, hotkey e notificação', () async {
      final bridge = WindowsHelperBridge();
      final activeWin = <Map<String, dynamic>>[];
      final audio = <Map<String, dynamic>>[];
      final media = <Map<String, dynamic>>[];
      final hotkey = <Map<String, dynamic>>[];
      final notif = <Map<String, dynamic>>[];

      final s1 = bridge.activeWindowEvents.listen(activeWin.add);
      final s2 = bridge.audioEvents.listen(audio.add);
      final s3 = bridge.mediaEvents.listen(media.add);
      final s4 = bridge.hotkeyEvents.listen(hotkey.add);
      final s5 = bridge.notificationEvents.listen(notif.add);

      bridge.handleRawLine('{"event":"active_window","process":"code","title":"VS Code"}');
      bridge.handleRawLine('{"event":"audio","master":{"volume":65,"muted":false}}');
      bridge.handleRawLine('{"event":"media","status":"Playing","title":"Song","artist":"Band","position":12,"duration":180,"playback_rate":1.0}');
      bridge.handleRawLine('{"event":"hotkey","status":"triggered","combo":"alt+space"}');
      bridge.handleRawLine('{"event":"notification","id":9,"app":"Discord","title":"Msg","body":"Oi"}');

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(activeWin.single['process'], equals('code'));
      expect((audio.single['master'] as Map)['volume'], equals(65));
      expect(media.single['title'], equals('Song'));
      expect(hotkey.single['status'], equals('triggered'));
      expect(notif.single['app'], equals('Discord'));

      await s1.cancel();
      await s2.cancel();
      await s3.cancel();
      await s4.cancel();
      await s5.cancel();
      await bridge.dispose();
    });
  });
}
