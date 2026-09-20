/// Nucleo do Hub Agent.
///
/// Dart puro: hospedado tanto pelo app Flutter (CMS) quanto por um daemon
/// compilado com `dart compile exe`. Nada aqui conhece widgets.
library agent_core;

export 'src/agent_runtime.dart';
export 'src/models/audio_state.dart';
export 'src/models/hub_theme.dart';
export 'src/models/layout.dart';
export 'src/models/media_state.dart';
export 'src/models/tile.dart';
export 'src/services/audio/audio_controller.dart';
export 'src/services/audio/linux_audio_controller.dart';
export 'src/services/command_dispatcher.dart';
export 'src/services/layout_repository.dart';
export 'src/services/media_service.dart';
export 'src/services/mqtt_service.dart';
export 'src/util/hex_color.dart';
