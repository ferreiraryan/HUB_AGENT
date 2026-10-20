import 'package:meta/meta.dart';

enum AgentEventKind {
  info,
  success,
  warning,
  error;

  static AgentEventKind fromString(String? value) {
    if (value == null) return AgentEventKind.info;
    return switch (value.toLowerCase().trim()) {
      'success' => AgentEventKind.success,
      'warning' => AgentEventKind.warning,
      'error' => AgentEventKind.error,
      _ => AgentEventKind.info,
    };
  }
}

/// Evento efêmero emitido pelo agente ou por integrações para feedback visual imediato no tablet.
@immutable
class AgentEvent {
  static const int defaultDurationMs = 3000;

  final AgentEventKind kind;
  final String message;
  final int durationMs;

  const AgentEvent({
    required this.kind,
    required this.message,
    this.durationMs = defaultDurationMs,
  });

  factory AgentEvent.info(String message, {int durationMs = defaultDurationMs}) =>
      AgentEvent(kind: AgentEventKind.info, message: message, durationMs: durationMs);

  factory AgentEvent.success(String message, {int durationMs = defaultDurationMs}) =>
      AgentEvent(kind: AgentEventKind.success, message: message, durationMs: durationMs);

  factory AgentEvent.warning(String message, {int durationMs = 4000}) =>
      AgentEvent(kind: AgentEventKind.warning, message: message, durationMs: durationMs);

  factory AgentEvent.error(String message, {int durationMs = 5000}) =>
      AgentEvent(kind: AgentEventKind.error, message: message, durationMs: durationMs);

  factory AgentEvent.fromJson(Map<String, dynamic> json) {
    final rawDuration = json['duration'];
    final duration = (rawDuration is num)
        ? rawDuration.round()
        : int.tryParse(rawDuration?.toString() ?? '') ?? defaultDurationMs;

    return AgentEvent(
      kind: AgentEventKind.fromString(json['kind']?.toString()),
      message: (json['message']?.toString() ?? '').trim(),
      durationMs: duration.clamp(500, 15000),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'message': message,
        'duration': durationMs,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentEvent &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          message == other.message &&
          durationMs == other.durationMs;

  @override
  int get hashCode => Object.hash(kind, message, durationMs);

  @override
  String toString() => 'AgentEvent($kind, "$message", ${durationMs}ms)';
}

