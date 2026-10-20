import 'dart:io';

import 'linux_notification_monitor.dart';
import 'notification_monitor.dart';
import 'unsupported_notification_monitor.dart';

NotificationMonitor createDefaultNotificationMonitor({Set<String>? ignoredApps}) {
  if (Platform.isLinux) {
    return LinuxNotificationMonitor(ignoredApps: ignoredApps);
  }
  return UnsupportedNotificationMonitor();
}
