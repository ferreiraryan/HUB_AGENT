// apps/cms_app/lib/providers.dart

import 'package:agent_core/agent_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'system/agent_bridge.dart';

final agentConfigProvider = Provider<AgentConfig>(
  (ref) => throw StateError(
    'agentConfigProvider não foi sobrescrito no ProviderScope raiz.',
  ),
);

/// Provider legado mantido para compatibilidade com testes de widget que
/// sobrescrevem `agentRuntimeProvider` diretamente.
final agentRuntimeProvider = Provider<AgentRuntime>(
  (ref) => throw StateError(
    'agentRuntimeProvider não está disponível em modo cliente daemon. Use agentBridgeProvider.',
  ),
);

/// Ponte principal usada por toda a UI do CMS.
///
/// Em produção (Fase 4), é sobrescrito por [DaemonAgentBridge]; em testes
/// legados ou modo `--standalone`, faz fallback automático encapsulando
/// [agentRuntimeProvider] em [InProcessAgentBridge].
final agentBridgeProvider = Provider<AgentBridge>((ref) {
  final runtime = ref.watch(agentRuntimeProvider);
  final config = ref.watch(agentConfigProvider);
  final bridge = InProcessAgentBridge(runtime: runtime, config: config);
  ref.onDispose(() {
    bridge.dispose();
  });
  return bridge;
});

final soundLibraryRepositoryProvider = Provider<SoundLibraryRepository>(
  (ref) => throw StateError(
    'soundLibraryRepositoryProvider não foi sobrescrito no ProviderScope raiz.',
  ),
);

final imageLibraryRepositoryProvider = Provider<ImageLibraryRepository>(
  (ref) => throw StateError(
    'imageLibraryRepositoryProvider não foi sobrescrito no ProviderScope raiz.',
  ),
);

final connectionStateProvider = StreamProvider<AgentConnectionState>((ref) {
  final bridge = ref.watch(agentBridgeProvider);
  return bridge.connectionState;
});

/// Quando o processo foi iniciado em modo dedicado `--spotlight=search` ou
/// `--spotlight=todo`, informa o tipo do spotlight para montar direto na frame 0.
final initialSpotlightProvider = Provider<String?>((ref) => null);
