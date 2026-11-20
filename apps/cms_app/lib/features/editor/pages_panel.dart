import 'package:agent_core/agent_core.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/cms_theme.dart';
import 'editor_controller.dart';
import 'tile_card.dart';

class PagesPanel extends ConsumerWidget {
  const PagesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(editorControllerProvider);
    final layout = state.layout;

    final pagesKeys =
        layout.pages.keys.where((k) => k != Layout.homePage).toList();
    if (layout.pages.containsKey(Layout.homePage)) {
      pagesKeys.insert(0, Layout.homePage);
    }

    final issues = layout.validate();
    final orphanPages = issues
        .where(
            (i) => i.level == IssueLevel.warning && i.message.contains('orfa'))
        .map((i) => i.pageId)
        .toSet();

    return Material(
      color: const Color(0xFF1E1E2E),
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Páginas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: pagesKeys.length,
                itemBuilder: (context, index) {
                  final pageId = pagesKeys[index];
                  final isSelected = state.currentPage == pageId;
                  final isOrphan = orphanPages.contains(pageId);
                  final tileCount = layout.tilesOf(pageId).length;

                  return DragTarget<TileDragPayload>(
                    onWillAcceptWithDetails: (d) => d.data.fromPage != pageId,
                    onAcceptWithDetails: (d) {
                      ref.read(editorControllerProvider.notifier).moveTile(
                            d.data.fromPage,
                            d.data.tileId,
                            pageId,
                          );
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovered = candidateData.isNotEmpty;

                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isHovered
                                ? Color(layout.theme.accentColor)
                                : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.only(left: 14, right: 6),
                          leading: Icon(
                              pageId == Layout.homePage
                                  ? Icons.home_rounded
                                  : Icons.folder_outlined,
                              size: 18,
                              color: isSelected
                                  ? Color(layout.theme.accentColor)
                                  : Colors.white54),
                          title: Text(pageId,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isOrphan)
                                const Tooltip(
                                  message:
                                      'Página órfã (nenhuma pasta aponta para ela)',
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 4.0),
                                    child: Icon(Icons.warning_amber,
                                        size: 15, color: Colors.orange),
                                  ),
                                ),
                              Text('$tileCount',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white38)),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    size: 16, color: Colors.white38),
                                padding: EdgeInsets.zero,
                                tooltip: 'Ações da página',
                                onSelected: (action) {
                                  if (action == 'rename') {
                                    _showRenamePageDialog(
                                        context, ref, pageId, layout);
                                  } else if (action == 'duplicate') {
                                    _showDuplicatePageDialog(
                                        context, ref, pageId, layout);
                                  } else if (action == 'auto_switch') {
                                    _showPageTriggersDialog(
                                        context, ref, pageId);
                                  } else if (action == 'delete') {
                                    _confirmDeletePage(context, ref, pageId);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'auto_switch',
                                    child: Row(
                                      children: [
                                        Icon(Icons.auto_awesome_outlined,
                                            size: 16, color: CmsTheme.accent),
                                        SizedBox(width: 8),
                                        Text('Vincular apps (Auto-Switch)'),
                                      ],
                                    ),
                                  ),
                                  if (pageId != Layout.homePage)
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 16),
                                          SizedBox(width: 8),
                                          Text('Renomear'),
                                        ],
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'duplicate',
                                    child: Row(
                                      children: [
                                        Icon(Icons.content_copy, size: 16),
                                        SizedBox(width: 8),
                                        Text('Duplicar'),
                                      ],
                                    ),
                                  ),
                                  if (pageId != Layout.homePage)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline,
                                              size: 16, color: CmsTheme.red),
                                          SizedBox(width: 8),
                                          Text('Excluir',
                                              style: TextStyle(
                                                  color: CmsTheme.red)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          selected: isSelected,
                          selectedTileColor: Color(layout.theme.accentColor)
                              .withValues(alpha: 0.14),
                          onTap: () {
                            ref
                                .read(editorControllerProvider.notifier)
                                .selectPage(pageId);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nova página'),
                onPressed: () => _showNewPageDialog(context, ref),
              ),
            ),
            const Divider(height: 32),
            _ThemeConfigurator(theme: layout.theme),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewPageDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Página'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'ex: luzes_sala'),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Nome obrigatório';
              }
              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v)) {
                return 'Apenas letras minúsculas, números e _';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                ref
                    .read(editorControllerProvider.notifier)
                    .addPage(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showRenamePageDialog(
    BuildContext context,
    WidgetRef ref,
    String oldId,
    Layout layout,
  ) async {
    final controller = TextEditingController(text: oldId);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Renomear "$oldId"'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Novo nome da página'),
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return 'Nome obrigatório';
              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(text)) {
                return 'Apenas letras minúsculas, números e _';
              }
              if (text != oldId && layout.pages.containsKey(text)) {
                return 'Já existe uma página com este nome';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                ref
                    .read(editorControllerProvider.notifier)
                    .renamePage(oldId, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Renomear'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showDuplicatePageDialog(
    BuildContext context,
    WidgetRef ref,
    String sourceId,
    Layout layout,
  ) async {
    var suggested = '${sourceId}_copy';
    var n = 2;
    while (layout.pages.containsKey(suggested)) {
      suggested = '${sourceId}_copy_$n';
      n++;
    }
    final controller = TextEditingController(text: suggested);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Duplicar "$sourceId"'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome da cópia'),
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return 'Nome obrigatório';
              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(text)) {
                return 'Apenas letras minúsculas, números e _';
              }
              if (layout.pages.containsKey(text)) {
                return 'Já existe uma página com este nome';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                ref
                    .read(editorControllerProvider.notifier)
                    .duplicatePage(sourceId, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _confirmDeletePage(
    BuildContext context,
    WidgetRef ref,
    String pageId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir página "$pageId"?'),
        content: const Text(
          'Todos os widgets desta página e pastas apontando para ela serão removidos.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CmsTheme.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(editorControllerProvider.notifier).removePage(pageId);
    }
  }

  Future<void> _showPageTriggersDialog(
    BuildContext context,
    WidgetRef ref,
    String pageId,
  ) async {
    final bridge = ref.read(agentBridgeProvider);
    final currentTriggers = bridge.pageRules[pageId] ?? const [];
    final ctrl = TextEditingController(text: currentTriggers.join(', '));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Auto-Switch: "$pageId"'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quando um destes apps estiver em foco no PC, o tablet abrirá automaticamente esta página:',
                style: TextStyle(fontSize: 12.5, color: CmsTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Processos (separados por vírgula)',
                  hintText: 'ex: code, cursor, firefox, obs64',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Deixe vazio para desativar o Auto-Switch nesta página.',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final list = ctrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await bridge.setPageTriggers(pageId, list);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(list.isEmpty
                ? 'Auto-Switch removido de "$pageId"'
                : 'Auto-Switch de "$pageId" atualizado (${list.join(", ")})'),
          ),
        );
      }
    }
    ctrl.dispose();
  }
}

class _ThemeConfigurator extends ConsumerWidget {
  final HubTheme theme;

  const _ThemeConfigurator({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tema do Tablet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: CmsTheme.tabletPresets.map((preset) {
              final isActive = preset.theme == theme;
              return Tooltip(
                message: preset.name,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => ref
                      .read(editorControllerProvider.notifier)
                      .updateTheme(preset.theme),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                      color: Color(preset.theme.bgColor),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? Color(preset.theme.accentColor)
                            : Colors.white24,
                        width: isActive ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color(preset.theme.cardColor),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color(preset.theme.accentColor),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Swatch(
                label: 'Fundo',
                color: Color(theme.bgColor),
                onPicked: (c) => ref
                    .read(editorControllerProvider.notifier)
                    .updateTheme(HubTheme(
                      bgColor: c.toARGB32(),
                      cardColor: theme.cardColor,
                      accentColor: theme.accentColor,
                    )),
              ),
              _Swatch(
                label: 'Card',
                color: Color(theme.cardColor),
                onPicked: (c) => ref
                    .read(editorControllerProvider.notifier)
                    .updateTheme(HubTheme(
                      bgColor: theme.bgColor,
                      cardColor: c.toARGB32(),
                      accentColor: theme.accentColor,
                    )),
              ),
              _Swatch(
                label: 'Accent',
                color: Color(theme.accentColor),
                onPicked: (c) => ref
                    .read(editorControllerProvider.notifier)
                    .updateTheme(HubTheme(
                      bgColor: theme.bgColor,
                      cardColor: theme.cardColor,
                      accentColor: c.toARGB32(),
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onPicked;

  const _Swatch(
      {required this.label, required this.color, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            Color? picked = await showDialog<Color>(
              context: context,
              builder: (ctx) {
                Color temp = color;
                return AlertDialog(
                  title: Text('Escolha: $label'),
                  content: SingleChildScrollView(
                    child: ColorPicker(
                      color: color,
                      onColorChanged: (c) => temp = c,
                      pickersEnabled: const {ColorPickerType.wheel: true},
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, temp),
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
            if (picked != null) {
              onPicked(picked);
            }
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }
}
