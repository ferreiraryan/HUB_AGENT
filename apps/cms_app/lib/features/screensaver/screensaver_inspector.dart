import 'package:agent_core/agent_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/cms_theme.dart';
import '../editor/helpers/image_icon_helper.dart';
import '../editor/image_library_dialog.dart';
import 'screensaver_controller.dart';

class ScreensaverInspector extends ConsumerWidget {
  const ScreensaverInspector({super.key});

  Future<void> _pickImageForWidget(
    BuildContext context,
    WidgetRef ref,
    ScreensaverWidget widget, {
    required bool fromLibrary,
  }) async {
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
          maxDimension: 600,
        );
      }
    }
    if (dataUri != null && dataUri.isNotEmpty) {
      ref.read(screensaverControllerProvider.notifier).updateWidget(
            widget.id,
            (w) => w.copyWith(config: {...w.config, 'image_data': dataUri}),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(screensaverControllerProvider);
    final notifier = ref.read(screensaverControllerProvider.notifier);
    final w = editorState.selectedWidget;

    if (w == null) {
      return Container(
        width: 310,
        color: CmsTheme.base,
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text(
            'Clique em um widget no canvas para personalizar posição, estilo e opções.\n\nDica: arraste para mover e use a bolinha azul no canto inferior direito para redimensionar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.5),
          ),
        ),
      );
    }

    return SizedBox(
      width: 310,
      child: Material(
        color: CmsTheme.base,
        child: ListView(
          padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 17, color: CmsTheme.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Widget: ${w.type.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: CmsTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                tooltip: 'Duplicar',
                onPressed: () => notifier.duplicateWidget(w.id),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 17, color: CmsTheme.red),
                tooltip: 'Remover',
                onPressed: () => notifier.removeWidget(w.id),
              ),
            ],
          ),
          const Divider(height: 16, color: Colors.white12),

          // Posição e Tamanho
          const Text('Posição e Tamanho (%)',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: CmsTheme.textSecondary)),
          const SizedBox(height: 8),
          _sliderRow('X', w.x, 0, (100 - w.w).clamp(0, 100), (v) {
            notifier.updateWidget(w.id, (cur) => cur.copyWith(x: v),
                recordUndo: false);
          }),
          _sliderRow('Y', w.y, 0, (100 - w.h).clamp(0, 100), (v) {
            notifier.updateWidget(w.id, (cur) => cur.copyWith(y: v),
                recordUndo: false);
          }),
          _sliderRow('Largura', w.w, 10, 100, (v) {
            notifier.updateWidget(w.id, (cur) => cur.copyWith(w: v),
                recordUndo: false);
          }),
          _sliderRow('Altura', w.h, 10, 100, (v) {
            notifier.updateWidget(w.id, (cur) => cur.copyWith(h: v),
                recordUndo: false);
          }),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text('Centralizar H', style: TextStyle(fontSize: 11)),
                onPressed: () => notifier.updateWidget(
                  w.id,
                  (cur) => cur.copyWith(x: (100 - cur.w) / 2),
                ),
              ),
              ActionChip(
                label: const Text('Centralizar V', style: TextStyle(fontSize: 11)),
                onPressed: () => notifier.updateWidget(
                  w.id,
                  (cur) => cur.copyWith(y: (100 - cur.h) / 2),
                ),
              ),
              ActionChip(
                label: const Text('Frente', style: TextStyle(fontSize: 11)),
                onPressed: () => notifier.bringToFront(w.id),
              ),
              ActionChip(
                label: const Text('Trás', style: TextStyle(fontSize: 11)),
                onPressed: () => notifier.sendToBack(w.id),
              ),
            ],
          ),

          const Divider(height: 22, color: Colors.white12),

          // Estilo do Card
          const Text('Estilo e Aparência',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: CmsTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final style in const [
                ('glass', 'Glass'),
                ('solid', 'Sólido'),
                ('outline', 'Contorno'),
                ('minimal', 'Minimal'),
              ])
                ChoiceChip(
                  label: Text(style.$2, style: const TextStyle(fontSize: 11.5)),
                  selected: w.cardStyle == style.$1,
                  onSelected: (_) => notifier.updateWidget(
                    w.id,
                    (cur) => cur.copyWith(cardStyle: style.$1),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _sliderRow('Opacidade', w.opacity * 100, 20, 100, (v) {
            notifier.updateWidget(
              w.id,
              (cur) => cur.copyWith(opacity: v / 100.0),
              recordUndo: false,
            );
          }),
          _sliderRow('Escala', w.scale * 100, 65, 160, (v) {
            notifier.updateWidget(
              w.id,
              (cur) => cur.copyWith(scale: v / 100.0),
              recordUndo: false,
            );
          }),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Alinhamento:',
                  style: TextStyle(fontSize: 11.5, color: Colors.white70)),
              const Spacer(),
              for (final a in const [
                ('left', Icons.format_align_left, 'Esquerda'),
                ('center', Icons.format_align_center, 'Centro'),
                ('right', Icons.format_align_right, 'Direita'),
              ])
                IconButton(
                  icon: Icon(
                    a.$2,
                    size: 16,
                    color: w.align == a.$1 ? CmsTheme.blue : Colors.white54,
                  ),
                  tooltip: a.$3,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                  onPressed: () => notifier.updateWidget(
                    w.id,
                    (cur) => cur.copyWith(align: a.$1),
                  ),
                ),
            ],
          ),

          const Divider(height: 22, color: Colors.white12),

          // Opções específicas por tipo
          const Text('Opções do Widget',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: CmsTheme.textSecondary)),
          const SizedBox(height: 8),
          ..._buildSpecificOptions(context, ref, w, notifier),
        ],
      ),
      ),
    );
  }

  List<Widget> _buildSpecificOptions(
    BuildContext context,
    WidgetRef ref,
    ScreensaverWidget w,
    ScreensaverController notifier,
  ) {
    void setCfg(String key, dynamic value) {
      notifier.updateWidget(
        w.id,
        (cur) => cur.copyWith(config: {...cur.config, key: value}),
      );
    }

    switch (w.type) {
      case 'clock':
        final style = w.config['clock_style'] as String? ?? 'digital';
        return [
          Wrap(
            spacing: 6,
            children: [
              for (final s in const [
                ('digital', 'Digital'),
                ('minimal', 'Minimal'),
                ('split', 'Split'),
                ('analog', 'Analógico'),
              ])
                ChoiceChip(
                  label: Text(s.$2, style: const TextStyle(fontSize: 11.5)),
                  selected: style == s.$1,
                  onSelected: (_) => setCfg('clock_style', s.$1),
                ),
            ],
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar segundos', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_seconds'] as bool? ?? true,
            onChanged: (v) => setCfg('show_seconds', v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar data', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_date'] as bool? ?? true,
            onChanged: (v) => setCfg('show_date', v),
          ),
        ];

      case 'weather':
        return [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Previsão de 3 dias', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_forecast'] as bool? ?? true,
            onChanged: (v) => setCfg('show_forecast', v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Umidade', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_humidity'] as bool? ?? true,
            onChanged: (v) => setCfg('show_humidity', v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Sensação térmica', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_feels_like'] as bool? ?? true,
            onChanged: (v) => setCfg('show_feels_like', v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Vento (km/h)', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_wind'] as bool? ?? false,
            onChanged: (v) => setCfg('show_wind', v),
          ),
        ];

      case 'pc_stats':
        final layout = w.config['layout'] as String? ?? 'rings';
        return [
          Wrap(
            spacing: 6,
            children: [
              for (final l in const [
                ('rings', 'Anéis'),
                ('bars', 'Barras'),
                ('compact', 'Compacto'),
              ])
                ChoiceChip(
                  label: Text(l.$2, style: const TextStyle(fontSize: 11.5)),
                  selected: layout == l.$1,
                  onSelected: (_) => setCfg('layout', l.$1),
                ),
            ],
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('CPU', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_cpu'] as bool? ?? true,
            onChanged: (v) => setCfg('show_cpu', v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Memória RAM', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_ram'] as bool? ?? true,
            onChanged: (v) => setCfg('show_ram', v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Disco', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_disk'] as bool? ?? true,
            onChanged: (v) => setCfg('show_disk', v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Temperatura CPU', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_temp'] as bool? ?? true,
            onChanged: (v) => setCfg('show_temp', v),
          ),
        ];

      case 'media':
        return [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Controles (⏮ ⏯ ⏭) sem acordar',
                style: TextStyle(fontSize: 12.5)),
            value: w.config['show_controls'] as bool? ?? true,
            onChanged: (v) => setCfg('show_controls', v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Vinil giratório', style: TextStyle(fontSize: 12.5)),
            value: w.config['show_vinyl'] as bool? ?? true,
            onChanged: (v) => setCfg('show_vinyl', v),
          ),
        ];

      case 'image':
        final fit = w.config['fit'] as String? ?? 'cover';
        final anim = w.config['floating_anim'] as String? ?? 'float';
        final radius = (w.config['border_radius'] as num?)?.toDouble() ?? 16;
        return [
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.photo_library_outlined, size: 15),
                  label: const Text('Biblioteca', style: TextStyle(fontSize: 11.5)),
                  onPressed: () => _pickImageForWidget(context, ref, w,
                      fromLibrary: true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file, size: 15),
                  label: const Text('Arquivo', style: TextStyle(fontSize: 11.5)),
                  onPressed: () => _pickImageForWidget(context, ref, w,
                      fromLibrary: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Preencher (Cover)',
                    style: TextStyle(fontSize: 11)),
                selected: fit == 'cover',
                onSelected: (_) => setCfg('fit', 'cover'),
              ),
              ChoiceChip(
                label: const Text('Inteira (Contain)',
                    style: TextStyle(fontSize: 11)),
                selected: fit == 'contain',
                onSelected: (_) => setCfg('fit', 'contain'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Animação da imagem',
              style: TextStyle(fontSize: 11.5, color: Colors.white70)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final a in const [
                ('none', 'Fixa'),
                ('float', 'Flutuar'),
                ('pulse', 'Pulsar'),
              ])
                ChoiceChip(
                  label: Text(a.$2, style: const TextStyle(fontSize: 11)),
                  selected: anim == a.$1,
                  onSelected: (_) => setCfg('floating_anim', a.$1),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _sliderRow('Borda', radius, 0, 48, (v) => setCfg('border_radius', v.round())),
        ];

      case 'text':
        return [
          TextFormField(
            key: ValueKey('text_${w.id}'),
            initialValue: w.config['content'] as String? ?? '',
            decoration: const InputDecoration(
              labelText: 'Texto exibido',
              isDense: true,
            ),
            onChanged: (v) => setCfg('content', v),
          ),
          const SizedBox(height: 8),
          _sliderRow(
            'Fonte',
            (w.config['font_size'] as num?)?.toDouble() ?? 20,
            12,
            48,
            (v) => setCfg('font_size', v.round()),
          ),
        ];

      case 'todos':
        return [
          _sliderRow(
            'Máx. itens',
            (w.config['max_items'] as num?)?.toDouble() ?? 4,
            1,
            8,
            (v) => setCfg('max_items', v.round()),
          ),
        ];

      default:
        return [
          const Text(
            'Este widget atualiza automaticamente em tempo real via MQTT.',
            style: TextStyle(fontSize: 11.5, color: Colors.white54),
          ),
        ];
    }
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final safeMax = max <= min ? min + 1 : max;
    final clamped = value.clamp(min, safeMax);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
        ),
        Expanded(
          child: Slider(
            value: clamped,
            min: min,
            max: safeMax,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '${clamped.round()}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ),
      ],
    );
  }
}
