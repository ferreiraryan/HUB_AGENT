import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'editor_controller.dart';
import 'inspector_panel.dart';
import 'pages_panel.dart';
import 'preview_panel.dart';

class EditorPage extends ConsumerWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider);
    final extLayout = state.externalLayout;

    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (extLayout != null)
            MaterialBanner(
              backgroundColor: Colors.blueGrey.shade900,
              content: const Text(
                'Layout externo recebido (modificado fora do CMS).',
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => ref
                      .read(editorControllerProvider.notifier)
                      .discardExternal(),
                  child: const Text('Descartar',
                      style: TextStyle(color: Colors.redAccent)),
                ),
                FilledButton(
                  onPressed: () => ref
                      .read(editorControllerProvider.notifier)
                      .acceptExternal(),
                  child: const Text('Manter'),
                ),
              ],
            ),
          const _TopBar(),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          const Expanded(
            child: Row(
              children: [
                PagesPanel(),
                VerticalDivider(width: 1, thickness: 1, color: Colors.white10),
                Expanded(child: PreviewPanel()),
                VerticalDivider(width: 1, thickness: 1, color: Colors.white10),
                InspectorPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(agentRuntimeProvider);
    final deviceName =
        ref.watch(editorControllerProvider.select((s) => s.layout.deviceName));
    final canUndo = ref
        .watch(editorControllerProvider.select((s) => s.undoStack.isNotEmpty));
    final canRedo = ref
        .watch(editorControllerProvider.select((s) => s.redoStack.isNotEmpty));

    return Container(
      height: 48,
      color: const Color(0xFF1E1E2E),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          StreamBuilder<AgentConnectionState>(
            stream: runtime.connectionState,
            initialData: AgentConnectionState.disconnected,
            builder: (context, snapshot) {
              final state = snapshot.data!;
              final color = state == AgentConnectionState.connected
                  ? Colors.green
                  : Colors.red;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: color),
                  const SizedBox(width: 8),
                  Text(state.name.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              );
            },
          ),
          const SizedBox(width: 24),
          const Icon(Icons.tablet_mac, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text(deviceName, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.undo, size: 18),
            onPressed: canUndo
                ? () => ref.read(editorControllerProvider.notifier).undo()
                : null,
            tooltip: 'Desfazer',
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 18),
            onPressed: canRedo
                ? () => ref.read(editorControllerProvider.notifier).redo()
                : null,
            tooltip: 'Refazer',
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            icon: const Icon(Icons.publish, size: 16),
            label: const Text('Publicar agora'),
            onPressed: () {
              ref.read(editorControllerProvider.notifier).flush();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Publicado'), duration: Duration(seconds: 2)),
              );
            },
          ),
        ],
      ),
    );
  }
}
