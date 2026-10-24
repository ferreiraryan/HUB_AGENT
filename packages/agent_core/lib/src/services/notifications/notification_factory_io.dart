import 'dart:io';

import 'linux_notification_monitor.dart';
import 'notification_monitor.dart';
import 'unsupported_notification_monitor.dart';
import 'windows_notification_monitor.dart';

NotificationMonitor createDefaultNotificationMonitor({Set<String>? ignoredApps}) {
  if (Platform.isLinux) {
    return LinuxNotificationMonitor(ignoredApps: ignoredApps);
  }
  if (Platform.isWindows) {
    return WindowsNotificationMonitor(ignoredApps: ignoredApps);
  }
  return UnsupportedNotificationMonitor();
}
