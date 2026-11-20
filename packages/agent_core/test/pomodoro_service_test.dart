import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('PomodoroService', () {
    test('estado inicial e idle', () {
      final pomo = PomodoroService(
        focusDurationMinutes: 20,
        cyclesBeforeLongBreak: 3,
      );

      expect(pomo.current.phase, equals(PomodoroPhase.idle));
      expect(pomo.current.remainingMs, equals(20 * 60 * 1000));
      expect(pomo.current.cycle, equals(1));
      expect(pomo.current.totalCycles, equals(3));
      expect(pomo.current.isRunning, isFalse);
    });

    test('configureFromTile atualiza configuracoes em idle', () {
      final pomo = PomodoroService();
      const tile = PomodoroTile(
        id: 'pomo_1',
        focusDurationMinutes: 45,
        shortBreakDurationMinutes: 10,
        longBreakDurationMinutes: 20,
        cyclesBeforeLongBreak: 5,
        startPhaseSoundId: 'bell_start',
        endPhaseSoundId: 'bell_end',
      );

      pomo.configureFromTile(tile);
      expect(pomo.focusDurationMinutes, equals(45));
      expect(pomo.shortBreakDurationMinutes, equals(10));
      expect(pomo.longBreakDurationMinutes, equals(20));
      expect(pomo.cyclesBeforeLongBreak, equals(5));
      expect(pomo.startPhaseSoundId, equals('bell_start'));
      expect(pomo.endPhaseSoundId, equals('bell_end'));
      expect(pomo.current.remainingMs, equals(45 * 60 * 1000));
      expect(pomo.current.totalCycles, equals(5));
    });

    test('toggle inicia e pausa o timer', () async {
      final pomo = PomodoroService(focusDurationMinutes: 25);
      expect(pomo.current.phase, equals(PomodoroPhase.idle));
      expect(pomo.current.isRunning, isFalse);

      await pomo.toggle();
      expect(pomo.current.phase, equals(PomodoroPhase.focus));
      expect(pomo.current.isRunning, isTrue);

      await pomo.toggle();
      expect(pomo.current.phase, equals(PomodoroPhase.focus));
      expect(pomo.current.isRunning, isFalse);

      await pomo.toggle();
      expect(pomo.current.phase, equals(PomodoroPhase.focus));
      expect(pomo.current.isRunning, isTrue);

      await pomo.reset();
      expect(pomo.current.phase, equals(PomodoroPhase.idle));
      expect(pomo.current.isRunning, isFalse);
    });

    test('skip transiciona entre fases corretamente', () async {
      final pomo = PomodoroService(
        focusDurationMinutes: 25,
        shortBreakDurationMinutes: 5,
        longBreakDurationMinutes: 15,
        cyclesBeforeLongBreak: 2,
      );

      // Inicia foco (Ciclo 1)
      await pomo.toggle();
      expect(pomo.current.phase, equals(PomodoroPhase.focus));
      expect(pomo.current.cycle, equals(1));

      // Pula para pausa curta
      await pomo.skip();
      expect(pomo.current.phase, equals(PomodoroPhase.shortBreak));
      expect(pomo.current.remainingMs, equals(5 * 60 * 1000));
      expect(pomo.current.cycle, equals(1));

      // Pula para foco (Ciclo 2)
      await pomo.skip();
      expect(pomo.current.phase, equals(PomodoroPhase.focus));
      expect(pomo.current.cycle, equals(2));

      // Como cycle == totalCycles (2), proximo skip vai para longBreak
      await pomo.skip();
      expect(pomo.current.phase, equals(PomodoroPhase.longBreak));
      expect(pomo.current.remainingMs, equals(15 * 60 * 1000));

      // Pula da pausa longa -> novo ciclo 1
      await pomo.skip();
      expect(pomo.current.phase, equals(PomodoroPhase.focus));
      expect(pomo.current.cycle, equals(1));

      await pomo.dispose();
    });
  });
}

