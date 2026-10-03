import 'dart:io';

import 'media_service.dart';
import 'media_windows.dart';

MediaService createDefaultMediaService() {
  if (Platform.isWindows) return WindowsMediaService();
  return MediaService();
}