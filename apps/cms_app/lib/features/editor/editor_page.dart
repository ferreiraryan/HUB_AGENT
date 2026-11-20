// apps/cms_app/lib/features/editor/editor_page.dart

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/cms_theme.dart';
import '../screensaver/screensaver_studio_page.dart';
import '../settings/broker_settings_dialog.dart';
import 'image_library_dialog.dart';
import 'sound_library_dialog.dart';
import 'editor_controller.dart';
import 'import_layout_dialog.dart';
import 'inspector_panel.dart';
import 'pages_panel.dart';
import 'preview_panel.dart';
import 'remote_search_controller.dart';
import 'remote_todo_controller.dart';

class EditorPage extends ConsumerWidget {
  const EditorPage({super.key});

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null) return false;
    return focus.context!.widget is EditableText ||
        focus.context!.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider);
    final extLayout = state.externalLayout;
    final notifier = ref.read(editorControllerProvider.notifier);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          if (!_isTextInputFocused()) notifier.undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
          if (!_isTextInputFocused()) notifier.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ,
            control: true, shift: true): () {
          if (!_isTextInputFocused()) notifier.redo();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          notifier.flush();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Layout publicado'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
          if (!_isTextInputFocused()) notifier.duplicateSelectedTile();
        },
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (_isTextInputFocused()) return;
          final sel = ref.read(editorControllerProvider).selectedTileId;
          if (sel != null) {
            final curPage = ref.read(editorControllerProvider).currentPage;
            notifier.removeTile(curPage, sel);
            notifier.selectTile(null);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          ref.read(remoteSearchControllerProvider.notifier).toggle();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          notifier.selectTile(null);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: CmsTheme.mantle,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (extLayout != null)
                MaterialBanner(
                  backgroundColor: CmsTheme.surface0,
                  content: const Text(
                    'Layout externo recebido (modificado fora do CMS).',
                    style: TextStyle(color: CmsTheme.textPrimary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => notifier.discardExternal(),
                      child: const Text('Descartar',
                          style: TextStyle(color: CmsTheme.red)),
                    ),
                    FilledButton(
                      onPressed: () => notifier.acceptExternal(),
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
                    VerticalDivider(
                        width: 1, thickness: 1, color: Colors.white10),
                    Expanded(child: PreviewPanel()),
                    VerticalDivider(
                        width: 1, thickness: 1, color: Colors.white10),
                    InspectorPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  Future<void> _editDeviceName(
      BuildContext context, WidgetRef ref, String current) async {
    final ctrl = TextEditingController(text: current);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome do Dispositivo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome exibido no tablet',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (updated != null && updated.trim().isNotEmpty) {
      ref.read(editorControllerProvider.notifier).updateDeviceName(updated);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceName =
        ref.watch(editorControllerProvider.select((s) => s.layout.deviceName));
    final isDirty =
        ref.watch(editorControllerProvider.select((s) => s.dirty));
    final canUndo = ref
        .watch(editorControllerProvider.select((s) => s.undoStack.isNotEmpty));
    final canRedo = ref
        .watch(editorControllerProvider.select((s) => s.redoStack.isNotEmpty));

    final connStateAsync = ref.watch(connectionStateProvider);
    final connState = connStateAsync.value ?? AgentConnectionState.disconnected;
    final (statusColor, statusLabel) = switch (connState) {
      AgentConnectionState.connected => (CmsTheme.green, 'Conectado'),
      AgentConnectionState.connecting => (CmsTheme.peach, 'Conectando'),
      AgentConnectionState.disconnected => (CmsTheme.red, 'Offline'),
    };

    return Container(
      height: 52,
      color: CmsTheme.base,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Tooltip(
            message: connState == AgentConnectionState.connected
                ? 'Conectado ao broker MQTT (clique para reconectar)'
                : 'Desconectado (clique para reconectar agora)',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                ref.read(agentRuntimeProvider).reconnectMqtt();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reconectando ao broker MQTT...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _editDeviceName(context, ref, deviceName),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tablet_mac,
                      size: 16, color: CmsTheme.textSecondary),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      deviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: CmsTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_outlined,
                      size: 13, color: Colors.white38),
                ],
              ),
            ),
          ),
          if (isDirty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: CmsTheme.peach.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: CmsTheme.peach.withValues(alpha: 0.35)),
              ),
              child: const Text(
                'Salvando…',
                style: TextStyle(
                    fontSize: 10.5,
                    color: CmsTheme.peach,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.undo_rounded, size: 18),
            onPressed: canUndo
                ? () => ref.read(editorControllerProvider.notifier).undo()
                : null,
            tooltip: 'Desfazer (Ctrl+Z)',
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded, size: 18),
            onPressed: canRedo
                ? () => ref.read(editorControllerProvider.notifier).redo()
                : null,
            tooltip: 'Refazer (Ctrl+Y)',
          ),
          Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white12),
          IconButton(
            icon: const Icon(Icons.nights_stay_outlined, size: 18),
            tooltip: 'Ambient Studio (Tela de Suspensão)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScreensaverStudioPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add_check_rounded, size: 19),
            tooltip: 'Adicionar Tarefa Rápida',
            onPressed: () =>
                ref.read(remoteTodoControllerProvider.notifier).open(),
          ),
          IconButton(
            icon: const Icon(Icons.library_music_outlined, size: 18),
            tooltip: 'Biblioteca de Sons',
            onPressed: () => showSoundLibraryDialog(context: context, ref: ref),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            tooltip: 'Biblioteca de Ícones / Imagens',
            onPressed: () => showImageLibraryDialog(context: context, ref: ref),
          ),
          IconButton(
            icon: const Icon(Icons.data_object_rounded, size: 18),
            tooltip: 'Importar / Editar JSON',
            onPressed: () => showImportLayoutDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18),
            tooltip: 'Configurações (Broker, Áudio e Sistema)',
            onPressed: () => showBrokerSettingsDialog(context, ref),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.publish_rounded, size: 16),
            label: const Text('Publicar'),
            onPressed: () {
              ref.read(editorControllerProvider.notifier).flush();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Layout publicado para o tablet'),
                    duration: Duration(seconds: 2)),
              );
            },
          ),
        ],
      ),
    );
  }
}
