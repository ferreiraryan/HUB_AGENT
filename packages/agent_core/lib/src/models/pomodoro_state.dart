import 'package:meta/meta.dart';

enum PomodoroPhase {
  idle,
  focus,
  shortBreak,
  longBreak;

  String get wire => switch (this) {
        idle => 'idle',
        focus => 'focus',
        shortBreak => 'short_break',
        longBreak => 'long_break',
      };

  static PomodoroPhase parse(String? value) =>
      switch (value?.toLowerCase().trim()) {
        'focus' => focus,
        'short_break' => shortBreak,
        'long_break' => longBreak,
        _ => idle,
      };
}

@immutable
class PomodoroState {
  final PomodoroPhase phase;
  final int remainingMs;
  final int cycle;
  final int totalCycles;
  final bool isRunning;

  const PomodoroState({
    required this.phase,
    required this.remainingMs,
    required this.cycle,
    required this.totalCycles,
    required this.isRunning,
  });

  factory PomodoroState.initial({
    int focusDurationMinutes = 25,
    int totalCycles = 4,
  }) =>
      PomodoroState(
        phase: PomodoroPhase.idle,
        remainingMs: focusDurationMinutes * 60 * 1000,
        cycle: 1,
        totalCycles: totalCycles,
        isRunning: false,
      );

  factory PomodoroState.fromJson(Map<String, dynamic> json) => PomodoroState(
        phase: PomodoroPhase.parse(json['phase'] as String?),
        remainingMs: (json['remaining_ms'] as num?)?.toInt() ?? 0,
        cycle: (json['cycle'] as num?)?.toInt() ?? 1,
        totalCycles: (json['total_cycles'] as num?)?.toInt() ?? 4,
        isRunning: (json['is_running'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'phase': phase.wire,
        'remaining_ms': remainingMs,
        'cycle': cycle,
        'total_cycles': totalCycles,
        'is_running': isRunning,
      };

  PomodoroState copyWith({
    PomodoroPhase? phase,
    int? remainingMs,
    int? cycle,
    int? totalCycles,
    bool? isRunning,
  }) =>
      PomodoroState(
        phase: phase ?? this.phase,
        remainingMs: remainingMs ?? this.remainingMs,
        cycle: cycle ?? this.cycle,
        totalCycles: totalCycles ?? this.totalCycles,
        isRunning: isRunning ?? this.isRunning,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PomodoroState &&
          other.phase == phase &&
          other.remainingMs == remainingMs &&
          other.cycle == cycle &&
          other.totalCycles == totalCycles &&
          other.isRunning == isRunning;

  @override
  int get hashCode =>
      Object.hash(phase, remainingMs, cycle, totalCycles, isRunning);

  @override
  String toString() =>
      'PomodoroState(${phase.wire}, remaining: ${remainingMs}ms, cycle: $cycle/$totalCycles, running: $isRunning)';
}

