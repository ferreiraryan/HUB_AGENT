import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'system/agent_config.dart';

final agentConfigProvider = Provider<AgentConfig>(
  (ref) => throw StateError(
    'agentConfigProvider não foi sobrescrito no ProviderScope raiz.',
  ),
);

final agentRuntimeProvider = Provider<AgentRuntime>(
  (ref) => throw StateError(
    'agentRuntimeProvider não foi sobrescrito no ProviderScope raiz.',
  ),
);
