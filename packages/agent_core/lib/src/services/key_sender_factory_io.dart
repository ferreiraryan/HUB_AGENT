import 'dart:io';

import 'key_sender.dart';
import 'key_sender_linux.dart';
import 'key_sender_windows.dart';

KeySender createDefaultKeySender() {
  if (Platform.isWindows) return WindowsKeySender();
  if (Platform.isLinux) return LinuxKeySender();
  return UnsupportedKeySender();
}
