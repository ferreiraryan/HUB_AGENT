import 'dart:async';

import '../../models/agent_event.dart';
import 'notification_monitor.dart';

class UnsupportedNotificationMonitor implements NotificationMonitor {
  @override
  Stream<AgentEvent> get notifications => const Stream.empty();

  @override
  bool get isAvailable => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() async {}
}
