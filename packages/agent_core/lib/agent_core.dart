/// Nucleo do Hub Agent.
///
/// Dart puro: hospedado tanto pelo app Flutter (CMS) quanto por um daemon
/// compilado com `dart compile exe`. Nada aqui conhece widgets.
library agent_core;

export 'src/agent_runtime.dart';
export 'src/models/agent_event.dart';
export 'src/models/audio_output_device.dart';
export 'src/models/audio_state.dart';
export 'src/models/battery_state.dart';
export 'src/models/hub_theme.dart';
export 'src/models/layout.dart';
export 'src/models/media_state.dart';
export 'src/models/pomodoro_state.dart';
export 'src/models/screensaver_config.dart';
export 'src/models/sound_playback_state.dart';
export 'src/models/tile.dart';
export 'src/models/todo_state.dart';
export 'src/models/weather_state.dart';
export 'src/services/images/image_item.dart';
export 'src/services/images/image_library_repository.dart';
export 'src/services/sound/sound_controller.dart';
export 'src/services/sound/sound_library_repository.dart';
export 'src/services/audio/audio_controller.dart';
export 'src/services/audio/linux_audio_controller.dart';
export 'src/services/audio/windows_audio_controller.dart';
export 'src/services/brightness_controller.dart';
export 'src/services/brightness_windows.dart';
export 'src/services/battery/battery_service.dart';
export 'src/services/clipboard/clipboard_service.dart';
export 'src/services/osd/osd_service.dart';
export 'src/services/stats/stats_provider_windows.dart';
export 'src/services/window/active_window_monitor.dart';
export 'src/services/window/page_rules_repository.dart';
export 'src/services/command_dispatcher.dart';
export 'src/services/key_sender.dart';
export 'src/services/key_sender_linux.dart' show LinuxKeySender, LinuxKeyBackend;
export 'src/services/key_sender_windows.dart' show WindowsKeySender;
export 'src/services/layout_repository.dart';
export 'src/services/media_factory.dart' show createDefaultMediaService;
export 'src/services/media_service.dart';
export 'src/services/media_windows.dart' show WindowsMediaService;
export 'src/services/mqtt_service.dart';
export 'src/services/notifications/notification_monitor.dart';
export 'src/services/notifications/unsupported_notification_monitor.dart';
export 'src/services/notifications/linux_notification_monitor.dart';
export 'src/services/notifications/notification_factory_stub.dart'
    if (dart.library.io) 'src/services/notifications/notification_factory_io.dart';
export 'src/services/pomodoro/pomodoro_service.dart';
export 'src/services/screensaver/screensaver_repository.dart';
export 'src/services/todo/todo_repository.dart';
export 'src/services/todo/todo_service.dart';
export 'src/services/weather/weather_service.dart';
export 'src/util/hex_color.dart';
export 'src/util/windows_binaries.dart';
