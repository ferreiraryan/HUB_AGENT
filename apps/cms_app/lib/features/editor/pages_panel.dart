import 'package:agent_core/agent_core.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Container(
      width: 240,
      color: const Color(0xFF1E1E2E),
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
                        leading: Icon(Icons.folder,
                            color: isSelected
                                ? Color(layout.theme.accentColor)
                                : Colors.white54),
                        title:
                            Text(pageId, style: const TextStyle(fontSize: 14)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOrphan)
                              const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.warning_amber,
                                    size: 16, color: Colors.orange),
                              ),
                            Text('($tileCount)',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white38)),
                          ],
                        ),
                        selected: isSelected,
                        selectedTileColor: Color(layout.theme.accentColor)
                            .withValues(alpha: 0.15),
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
