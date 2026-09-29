import 'dart:io';
import 'audio_controller.dart';
import 'linux_audio_controller.dart';
import 'windows_audio_controller.dart';

AudioController createDefaultAudioController() {
  if (Platform.isLinux) return LinuxAudioController();
  if (Platform.isWindows) return WindowsAudioController();
  return UnsupportedAudioController();
}
