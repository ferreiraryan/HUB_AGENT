import 'notification_monitor.dart';
import 'unsupported_notification_monitor.dart';

NotificationMonitor createDefaultNotificationMonitor({Set<String>? ignoredApps}) =>
    UnsupportedNotificationMonitor();
