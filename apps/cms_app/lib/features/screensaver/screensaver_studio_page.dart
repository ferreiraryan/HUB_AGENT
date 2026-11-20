import 'package:agent_core/agent_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/cms_theme.dart';
import '../editor/helpers/image_icon_helper.dart';
import '../editor/image_library_dialog.dart';
import 'screensaver_canvas.dart';
import 'screensaver_controller.dart';
import 'screensaver_inspector.dart';

class ScreensaverStudioPage extends ConsumerStatefulWidget {
  const ScreensaverStudioPage({super.key});

  @override
  ConsumerState<ScreensaverStudioPage> createState() =>
      _ScreensaverStudioPageState();
}

class _ScreensaverStudioPageState extends ConsumerState<ScreensaverStudioPage> {
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(screensaverControllerProvider).config;
    _cityController = TextEditingController(text: cfg.weatherCity);
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickBackgroundImage({required bool fromLibrary}) async {
    String? dataUri;
    if (fromLibrary) {
      final item = await showImageLibraryDialog(
        context: context,
        ref: ref,
        selectMode: true,
      );
      dataUri = item?.dataUri;
    } else {
      final file = await openFile(
        acceptedTypeGroups: [ImageIconHelper.acceptedImageGroup],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        dataUri = await ImageIconHelper.processBannerImageBytes(
          bytes,
          maxDimension: 960,
        );
      }
    }
    if (dataUri != null && dataUri.isNotEmpty) {
      ref.read(screensaverControllerProvider.notifier).updateConfig(
            (c) => c.copyWith(
              backgroundStyle: 'image',
              backgroundImage: dataUri,
            ),
          );
    }
  }

  Future<void> _showAddWidgetDialog() async {
    const items = [
      ('clock', 'Relógio', 'Digital, Split, Minimal ou Analógico', Icons.schedule_rounded, CmsTheme.blue),
      ('weather', 'Clima & Temp.', 'Temperatura atual, umidade e 3 dias', Icons.wb_sunny_outlined, CmsTheme.peach),
      ('pc_stats', 'Status do PC', 'CPU, RAM, Disco e Temperatura', Icons.memory_rounded, Color(0xFFCBA6F7)),
      ('media', 'Mídia (Now Playing)', 'Faixa atual, vinil e controles', Icons.music_note_rounded, Color(0xFFF5C2E7)),
      ('image', 'Imagem / GIF', 'Foto, arte ou GIF animado flutuante', Icons.image_outlined, Color(0xFF94E2D5)),
      ('batteries', 'Baterias', 'Tablet, Notebook e Bluetooth', Icons.battery_charging_full, CmsTheme.green),
      ('network', 'Rede (Down/Up)', 'Velocidade ao vivo + sparkline', Icons.wifi_rounded, Color(0xFF94E2D5)),
      ('pomodoro', 'Pomodoro', 'Timer de foco e ciclos', Icons.timer_outlined, CmsTheme.red),
      ('todos', 'Tarefas', 'Lista das próximas pendências', Icons.checklist_rounded, Color(0xFFCBA6F7)),
      ('text', 'Texto Livre', 'Frase, nome ou mensagem', Icons.text_fields_rounded, CmsTheme.textSecondary),
    ];

    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Widget à Tela de Suspensão'),
        content: SizedBox(
          width: 520,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.8,
            children: [
              for (final item in items)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(ctx, item.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: CmsTheme.surface0,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: item.$5.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(item.$4, size: 18, color: item.$5),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                  color: CmsTheme.textPrimary,
                                ),
                              ),
                              Text(
                                item.$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );

    if (chosen != null) {
      ref.read(screensaverControllerProvider.notifier).addWidget(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(screensaverControllerProvider);
    final notifier = ref.read(screensaverControllerProvider.notifier);
    final config = editorState.config;

    return Scaffold(
      backgroundColor: CmsTheme.mantle,
      body: Column(
        children: [
          // Top bar do Ambient Studio
          Container(
            height: 52,
            color: CmsTheme.base,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 19),
                  tooltip: 'Voltar para o Editor de Dashboard',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.nights_stay_outlined,
                    size: 18, color: Color(0xFFCBA6F7)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ambient Studio — Tela de Suspensão',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: CmsTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  tooltip: 'Desfazer',
                  onPressed: editorState.undoStack.isNotEmpty
                      ? notifier.undo
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.redo_rounded, size: 18),
                  tooltip: 'Refazer',
                  onPressed: editorState.redoStack.isNotEmpty
                      ? notifier.redo
                      : null,
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Adicionar Widget'),
                  onPressed: _showAddWidgetDialog,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.grid_on_rounded,
                    size: 18,
                    color: editorState.showGrid
                        ? CmsTheme.blue
                        : Colors.white38,
                  ),
                  tooltip: 'Mostrar/ocultar grade',
                  onPressed: notifier.toggleGrid,
                ),
                IconButton(
                  icon: Icon(
                    Icons.straighten_rounded,
                    size: 18,
                    color: editorState.snapToGrid
                        ? CmsTheme.blue
                        : Colors.white38,
                  ),
                  tooltip: 'Alinhar à grade (Snap)',
                  onPressed: notifier.toggleSnap,
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.tablet_android_rounded, size: 16),
                  label: const Text('Testar no Tablet'),
                  onPressed: () async {
                    await notifier.publishAndPreviewOnTablet();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Tela de suspensão enviada e aberta no tablet!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Salvar'),
                  onPressed: () async {
                    await notifier.flush();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tela de suspensão salva e publicada.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Corpo em 3 colunas
          Expanded(
            child: Row(
              children: [
                // Esquerda: Presets, Fundo e Clima
                SizedBox(
                  width: 290,
                  child: Material(
                    color: CmsTheme.base,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                    children: [
                      const Text(
                        'PRESETS PRONTOS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: CmsTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final entry in ScreensaverPresets.all(
                            city: config.weatherCity,
                          ).entries)
                            ActionChip(
                              label: Text(entry.key,
                                  style: const TextStyle(fontSize: 11.5)),
                              onPressed: () =>
                                  notifier.applyPreset(entry.value),
                            ),
                        ],
                      ),

                      const Divider(height: 22, color: Colors.white12),

                      const Text(
                        'FUNDO ANIMADO',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: CmsTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final bg in const [
                            ('aurora', 'Aurora'),
                            ('oled_black', 'OLED Preto'),
                            ('starfield', 'Estrelas'),
                            ('particles', 'Partículas'),
                            ('mesh_glow', 'Mesh Glow'),
                            ('matrix_rain', 'Matrix'),
                            ('image', 'Imagem/GIF'),
                          ])
                            ChoiceChip(
                              label: Text(bg.$2,
                                  style: const TextStyle(fontSize: 11.5)),
                              selected: config.backgroundStyle == bg.$1,
                              onSelected: (_) => notifier.updateConfig(
                                (c) => c.copyWith(backgroundStyle: bg.$1),
                              ),
                            ),
                        ],
                      ),
                      if (config.backgroundStyle == 'image') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                icon: const Icon(Icons.photo_library_outlined,
                                    size: 15),
                                label: const Text('Biblioteca',
                                    style: TextStyle(fontSize: 11.5)),
                                onPressed: () =>
                                    _pickBackgroundImage(fromLibrary: true),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.upload_file, size: 15),
                                label: const Text('Arquivo',
                                    style: TextStyle(fontSize: 11.5)),
                                onPressed: () =>
                                    _pickBackgroundImage(fromLibrary: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('Escurecer',
                                style: TextStyle(
                                    fontSize: 11.5, color: Colors.white70)),
                            Expanded(
                              child: Slider(
                                value: config.backgroundDim,
                                min: 0.0,
                                max: 0.85,
                                onChanged: (v) => notifier.updateConfig(
                                  (c) => c.copyWith(backgroundDim: v),
                                ),
                              ),
                            ),
                            Text('${(config.backgroundDim * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white60)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Text('Cor de destaque',
                          style:
                              TextStyle(fontSize: 11.5, color: Colors.white70)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final hex in const [
                            '#cba6f7',
                            '#89b4fa',
                            '#94e2d5',
                            '#a6e3a1',
                            '#f5c2e7',
                            '#fab387',
                            '#f38ba8',
                          ])
                            GestureDetector(
                              onTap: () => notifier.updateConfig(
                                (c) => c.copyWith(accentColor: hex),
                              ),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: parseHexOrDefault(hex, const Color(0xFFCBA6F7)),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: config.accentColor.toLowerCase() ==
                                            hex
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Proteção OLED (Pixel Shift)',
                            style: TextStyle(fontSize: 12)),
                        value: config.burnInProtection,
                        onChanged: (v) => notifier.updateConfig(
                          (c) => c.copyWith(burnInProtection: v),
                        ),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mostrar "Toque para voltar"',
                            style: TextStyle(fontSize: 12)),
                        value: config.showWakeHint,
                        onChanged: (v) => notifier.updateConfig(
                          (c) => c.copyWith(showWakeHint: v),
                        ),
                      ),

                      const Divider(height: 22, color: Colors.white12),

                      const Text(
                        'CLIMA & TEMPERATURA',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: CmsTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'Cidade',
                                hintText: 'Ex: São Paulo',
                                isDense: true,
                              ),
                              onSubmitted: (v) =>
                                  notifier.refreshWeather(city: v),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            icon: editorState.loadingWeather
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 17),
                            tooltip: 'Buscar clima agora',
                            onPressed: editorState.loadingWeather
                                ? null
                                : () => notifier.refreshWeather(
                                      city: _cityController.text,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('°C'),
                            selected: config.weatherUnit == 'C',
                            onSelected: (_) =>
                                notifier.refreshWeather(unit: 'C'),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('°F'),
                            selected: config.weatherUnit == 'F',
                            onSelected: (_) =>
                                notifier.refreshWeather(unit: 'F'),
                          ),
                          const Spacer(),
                          if (editorState.weatherPreview != null)
                            Text(
                              '${editorState.weatherPreview!.temp.round()}°${editorState.weatherPreview!.unit}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: CmsTheme.peach,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  ),
                ),

                const VerticalDivider(width: 1, color: Colors.white12),

                // Centro: Canvas Drag & Drop
                const Expanded(
                  child: ScreensaverCanvas(),
                ),

                const VerticalDivider(width: 1, color: Colors.white12),

                // Direita: Inspetor do Widget
                const ScreensaverInspector(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
