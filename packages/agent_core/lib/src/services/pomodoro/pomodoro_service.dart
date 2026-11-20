import 'dart:async';

import '../../models/agent_event.dart';
import '../../models/pomodoro_state.dart';
import '../../models/tile.dart';
import '../sound/sound_controller.dart';

class PomodoroService {
  final SoundController? sound;
  final void Function(AgentEvent event)? onNotification;

  int focusDurationMinutes;
  int shortBreakDurationMinutes;
  int longBreakDurationMinutes;
  int cyclesBeforeLongBreak;
  String? startPhaseSoundId;
  String? endPhaseSoundId;

  late PomodoroState _state;
  final _controller = StreamController<PomodoroState>.broadcast();
  Timer? _timer;
  bool _disposed = false;

  PomodoroService({
    this.sound,
    this.onNotification,
    this.focusDurationMinutes = 25,
    this.shortBreakDurationMinutes = 5,
    this.longBreakDurationMinutes = 15,
    this.cyclesBeforeLongBreak = 4,
    this.startPhaseSoundId,
    this.endPhaseSoundId,
  }) {
    _state = PomodoroState.initial(
      focusDurationMinutes: focusDurationMinutes,
      totalCycles: cyclesBeforeLongBreak,
    );
  }

  PomodoroState get current => _state;
  Stream<PomodoroState> get changes => _controller.stream;

  void configureFromTile(PomodoroTile tile) {
    focusDurationMinutes = tile.focusDurationMinutes;
    shortBreakDurationMinutes = tile.shortBreakDurationMinutes;
    longBreakDurationMinutes = tile.longBreakDurationMinutes;
    cyclesBeforeLongBreak = tile.cyclesBeforeLongBreak;
    startPhaseSoundId = tile.startPhaseSoundId;
    endPhaseSoundId = tile.endPhaseSoundId;

    if (_state.phase == PomodoroPhase.idle && !_state.isRunning) {
      _state = PomodoroState.initial(
        focusDurationMinutes: focusDurationMinutes,
        totalCycles: cyclesBeforeLongBreak,
      );
      if (!_controller.isClosed) _controller.add(_state);
    }
  }

  Future<void> toggle() async {
    if (_disposed) return;

    if (_state.phase == PomodoroPhase.idle) {
      _state = PomodoroState(
        phase: PomodoroPhase.focus,
        remainingMs: focusDurationMinutes * 60 * 1000,
        cycle: 1,
        totalCycles: cyclesBeforeLongBreak,
        isRunning: true,
      );
      _startTimer();
      _notify(AgentEvent.info('Pomodoro: Foco iniciado! ($focusDurationMinutes min)'));
      await _playSound(startPhaseSoundId);
    } else if (_state.isRunning) {
      _timer?.cancel();
      _state = _state.copyWith(isRunning: false);
    } else {
      _state = _state.copyWith(isRunning: true);
      _startTimer();
    }

    if (!_controller.isClosed) _controller.add(_state);
  }

  Future<void> skip() async {
    if (_disposed) return;

    _timer?.cancel();

    switch (_state.phase) {
      case PomodoroPhase.idle:
        await toggle();
        return;
      case PomodoroPhase.focus:
        await _playSound(endPhaseSoundId);
        if (_state.cycle >= _state.totalCycles) {
          _state = PomodoroState(
            phase: PomodoroPhase.longBreak,
            remainingMs: longBreakDurationMinutes * 60 * 1000,
            cycle: _state.cycle,
            totalCycles: _state.totalCycles,
            isRunning: true,
          );
          _notify(AgentEvent.info('Pomodoro: Pausa longa adiantada ($longBreakDurationMinutes min).'));
        } else {
          _state = PomodoroState(
            phase: PomodoroPhase.shortBreak,
            remainingMs: shortBreakDurationMinutes * 60 * 1000,
            cycle: _state.cycle,
            totalCycles: _state.totalCycles,
            isRunning: true,
          );
          _notify(AgentEvent.info('Pomodoro: Pausa curta adiantada ($shortBreakDurationMinutes min).'));
        }
      case PomodoroPhase.shortBreak:
        await _playSound(startPhaseSoundId);
        final nextCycle = _state.cycle + 1;
        _state = PomodoroState(
          phase: PomodoroPhase.focus,
          remainingMs: focusDurationMinutes * 60 * 1000,
          cycle: nextCycle,
          totalCycles: _state.totalCycles,
          isRunning: true,
        );
        _notify(AgentEvent.info('Pomodoro: Foco iniciado! Ciclo $nextCycle de ${_state.totalCycles}.'));
      case PomodoroPhase.longBreak:
        await _playSound(startPhaseSoundId);
        _state = PomodoroState(
          phase: PomodoroPhase.focus,
          remainingMs: focusDurationMinutes * 60 * 1000,
          cycle: 1,
          totalCycles: _state.totalCycles,
          isRunning: true,
        );
        _notify(AgentEvent.info('Pomodoro: Novo ciclo de foco iniciado (Ciclo 1 de ${_state.totalCycles}).'));
    }

    _startTimer();
    if (!_controller.isClosed) _controller.add(_state);
  }

  Future<void> reset() async {
    if (_disposed) return;

    _timer?.cancel();
    _state = PomodoroState.initial(
      focusDurationMinutes: focusDurationMinutes,
      totalCycles: cyclesBeforeLongBreak,
    );
    if (!_controller.isClosed) _controller.add(_state);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  Future<void> _onTick(Timer _) async {
    if (_disposed) return;

    final nextRemaining = _state.remainingMs - 1000;
    if (nextRemaining > 0) {
      _state = _state.copyWith(remainingMs: nextRemaining);
      if (!_controller.isClosed) _controller.add(_state);
      return;
    }

    // Fase concluída!
    _timer?.cancel();

    if (_state.phase == PomodoroPhase.focus) {
      await _playSound(endPhaseSoundId);
      if (_state.cycle >= _state.totalCycles) {
        _state = PomodoroState(
          phase: PomodoroPhase.longBreak,
          remainingMs: longBreakDurationMinutes * 60 * 1000,
          cycle: _state.cycle,
          totalCycles: _state.totalCycles,
          isRunning: true,
        );
        _notify(AgentEvent.info('Pomodoro: Todos os ciclos concluídos! Hora da pausa longa ($longBreakDurationMinutes min).'));
      } else {
        _state = PomodoroState(
          phase: PomodoroPhase.shortBreak,
          remainingMs: shortBreakDurationMinutes * 60 * 1000,
          cycle: _state.cycle,
          totalCycles: _state.totalCycles,
          isRunning: true,
        );
        _notify(AgentEvent.info('Pomodoro: Foco concluído! Hora da pausa curta ($shortBreakDurationMinutes min).'));
      }
    } else if (_state.phase == PomodoroPhase.shortBreak) {
      await _playSound(startPhaseSoundId);
      final nextCycle = _state.cycle + 1;
      _state = PomodoroState(
        phase: PomodoroPhase.focus,
        remainingMs: focusDurationMinutes * 60 * 1000,
        cycle: nextCycle,
        totalCycles: _state.totalCycles,
        isRunning: true,
      );
      _notify(AgentEvent.info('Pomodoro: Pausa encerrada! Iniciando Ciclo $nextCycle de ${_state.totalCycles}.'));
    } else if (_state.phase == PomodoroPhase.longBreak) {
      await _playSound(startPhaseSoundId);
      _state = PomodoroState(
        phase: PomodoroPhase.focus,
        remainingMs: focusDurationMinutes * 60 * 1000,
        cycle: 1,
        totalCycles: _state.totalCycles,
        isRunning: true,
      );
      _notify(AgentEvent.info('Pomodoro: Pausa longa encerrada! Novo ciclo de estudos iniciado.'));
    }

    _startTimer();
    if (!_controller.isClosed) _controller.add(_state);
  }

  void _notify(AgentEvent event) {
    onNotification?.call(event);
  }

  Future<void> _playSound(String? soundId) async {
    if (soundId == null || soundId.isEmpty) return;
    try {
      await sound?.play(soundId);
    } catch (_) {}
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _controller.close();
  }
}

