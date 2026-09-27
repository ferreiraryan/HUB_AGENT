import 'dart:convert';
import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_controller.dart';

Future<void> showImportLayoutDialog(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ImportLayoutDialog(ref: ref),
  );
}

class _ValidationResult {
  final bool ok;
  final String mensagem;
  final List<LayoutIssue> erros;
  final List<LayoutIssue> avisos;
  final Layout? layout;

  const _ValidationResult({
    required this.ok,
    required this.mensagem,
    this.erros = const [],
    this.avisos = const [],
    this.layout,
  });
}

class _ImportLayoutDialog extends StatefulWidget {
  final WidgetRef ref;

  const _ImportLayoutDialog({required this.ref});

  @override
  State<_ImportLayoutDialog> createState() => _ImportLayoutDialogState();
}

class _ImportLayoutDialogState extends State<_ImportLayoutDialog> {
  late TextEditingController _controller;
  bool _preserveBindings = false;
  _ValidationResult? _validation;
  bool _podeAplicar = false;

  @override
  void initState() {
    super.initState();
    final state = widget.ref.read(editorControllerProvider);
    final json =
        const JsonEncoder.withIndent('  ').convert(state.layout.toDiskJson());
    _controller = TextEditingController(text: json);
    _validar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _colarDoClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _controller.text = data!.text!;
      _validar();
    }
  }

  void _validar() {
    try {
      final decoded = jsonDecode(_controller.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('O JSON root deve ser um objeto');
      }

      final layout = Layout.fromJson(decoded);
      final issues = layout.validate();
      final erros = issues.where((i) => i.level == IssueLevel.error).toList();
      final avisos =
          issues.where((i) => i.level == IssueLevel.warning).toList();

      setState(() {
        if (erros.isNotEmpty) {
          _validation = _ValidationResult(
            ok: false,
            mensagem:
                'Layout tem ${erros.length} erro(s). Corrija antes de aplicar.',
            erros: erros,
            avisos: avisos,
          );
          _podeAplicar = false;
        } else {
          final nPages = layout.pages.length;
          final nTiles = layout.pages.values.expand((l) => l).length;
          final avisoStr =
              avisos.isNotEmpty ? " (${avisos.length} aviso(s))" : "";

          _validation = _ValidationResult(
            ok: true,
            mensagem: 'JSON válido. $nPages páginas, $nTiles tiles.$avisoStr',
            avisos: avisos,
            layout: layout,
          );
          _podeAplicar = true;
        }
      });
    } catch (e) {
      setState(() {
        _validation = _ValidationResult(
          ok: false,
          mensagem: e is FormatException
              ? 'JSON inválido: ${e.message}'
              : 'Layout inválido: $e',
        );
        _podeAplicar = false;
      });
    }
  }

  void _aplicar() {
    if (_validation?.layout == null) return;
    final notifier = widget.ref.read(editorControllerProvider.notifier);
    notifier.substituirLayout(
      _validation!.layout!,
      preserveBindings: _preserveBindings,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Layout importado'),
    ));
  }

  Widget _buildValidationStatus() {
    final val = _validation;
    if (val == null) return const SizedBox.shrink();

    if (val.ok) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(val.mensagem,
                      style: const TextStyle(color: Colors.green))),
            ],
          ),
          if (val.avisos.isNotEmpty)
            ExpansionTile(
              title: Text('${val.avisos.length} aviso(s)',
                  style: const TextStyle(color: Colors.orange)),
              children: val.avisos
                  .map((e) => ListTile(
                        leading:
                            const Icon(Icons.warning, color: Colors.orange),
                        title: Text(e.message,
                            style: const TextStyle(fontSize: 11)),
                        subtitle: e.tileId != null
                            ? Text('tile: ${e.tileId}',
                                style: const TextStyle(fontSize: 10))
                            : null,
                        dense: true,
                      ))
                  .toList(),
            ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(val.mensagem,
                      style: const TextStyle(color: Colors.red))),
            ],
          ),
          if (val.erros.isNotEmpty)
            ExpansionTile(
              title: Text('${val.erros.length} erro(s)',
                  style: const TextStyle(color: Colors.red)),
              children: val.erros
                  .map((e) => ListTile(
                        leading: const Icon(Icons.error, color: Colors.red),
                        title: Text(e.message,
                            style: const TextStyle(fontSize: 11)),
                        subtitle: e.tileId != null
                            ? Text('tile: ${e.tileId}',
                                style: const TextStyle(fontSize: 10))
                            : null,
                        dense: true,
                      ))
                  .toList(),
            ),
          if (val.avisos.isNotEmpty)
            ExpansionTile(
              title: Text('${val.avisos.length} aviso(s)',
                  style: const TextStyle(color: Colors.orange)),
              children: val.avisos
                  .map((e) => ListTile(
                        leading:
                            const Icon(Icons.warning, color: Colors.orange),
                        title: Text(e.message,
                            style: const TextStyle(fontSize: 11)),
                        subtitle: e.tileId != null
                            ? Text('tile: ${e.tileId}',
                                style: const TextStyle(fontSize: 10))
                            : null,
                        dense: true,
                      ))
                  .toList(),
            ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Importar Layout',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cole um JSON de layout. Pré-preenchido com o atual.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  fillColor: Colors.black26,
                  filled: true,
                ),
                onChanged: (_) => _validar(),
              ),
            ),
            const SizedBox(height: 12),
            if (_validation != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: _buildValidationStatus(),
                ),
              ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _preserveBindings,
              onChanged: (v) => setState(() => _preserveBindings = v ?? false),
              title:
                  const Text('Preservar comandos de shortcuts com id em comum'),
              subtitle: const Text(
                  'Útil quando o JSON novo tem os mesmos ids (play_pause, lock...), '
                  'mas você não quer perder os comandos já configurados.'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Colar do clipboard'),
                  onPressed: _colarDoClipboard,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Validar'),
                  onPressed: _validar,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Aplicar'),
                  onPressed: _podeAplicar ? _aplicar : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
