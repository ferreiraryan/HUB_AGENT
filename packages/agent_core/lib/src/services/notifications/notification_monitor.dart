import 'dart:async';

import '../../models/agent_event.dart';

abstract interface class NotificationMonitor {
  Stream<AgentEvent> get notifications;
  bool get isAvailable;

  Future<void> start();
  Future<void> dispose();
}
