import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../system/agent_config.dart';

Future<void> showBrokerSettingsDialog(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _BrokerSettingsDialog(ref: ref),
  );
}

class _TestStatus {
  final bool isTesting;
  final bool? ok;
  final String? message;

  const _TestStatus({this.isTesting = false, this.ok, this.message});

  factory _TestStatus.testing() => const _TestStatus(isTesting: true);
  factory _TestStatus.ok(String msg) => _TestStatus(ok: true, message: msg);
  factory _TestStatus.erro(String msg) => _TestStatus(ok: false, message: msg);
}

class _BrokerSettingsDialog extends StatefulWidget {
  final WidgetRef ref;

  const _BrokerSettingsDialog({required this.ref});

  @override
  State<_BrokerSettingsDialog> createState() => _BrokerSettingsDialogState();
}

class _BrokerSettingsDialogState extends State<_BrokerSettingsDialog> {
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _deviceIdCtrl;

  _TestStatus? _status;
  bool _podeSalvar = false;

  @override
  void initState() {
    super.initState();
    final config = widget.ref.read(agentConfigProvider);
    _hostCtrl = TextEditingController(text: config.host);
    _portCtrl = TextEditingController(text: config.port.toString());
    _deviceIdCtrl = TextEditingController(text: config.deviceId);

    _hostCtrl.addListener(_validar);
    _portCtrl.addListener(_validar);
    _deviceIdCtrl.addListener(_validar);
    _validar();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _deviceIdCtrl.dispose();
    super.dispose();
  }

  void _validar() {
    final host = _hostCtrl.text.trim();
    final portRaw = _portCtrl.text.trim();
    final devId = _deviceIdCtrl.text.trim();

    bool valid = true;

    if (host.isEmpty) valid = false;

    final port = int.tryParse(portRaw);
    if (port == null || port < 1 || port > 65535) valid = false;

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(devId)) valid = false;

    if (valid != _podeSalvar) {
      setState(() => _podeSalvar = valid);
    }
  }

  Future<void> _testar() async {
    if (!_podeSalvar) return;
    setState(() => _status = _TestStatus.testing());

    final testConfig = AgentConfig(
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      deviceId: '__cms_test__${DateTime.now().millisecondsSinceEpoch}',
    );

    final testClient = MqttService(
      host: testConfig.host,
      port: testConfig.port,
      deviceId: testConfig.deviceId,
    );

    try {
      await testClient.connect().timeout(const Duration(seconds: 5));
      if (testClient.isConnected) {
        if (mounted)
          setState(() => _status = _TestStatus.ok('Conectado com sucesso'));
      } else {
        if (mounted)
          setState(() => _status =
              _TestStatus.erro('Conectou mas estado não é connected'));
      }
    } catch (e) {
      if (mounted) setState(() => _status = _TestStatus.erro('Falha: $e'));
    } finally {
      await testClient.dispose();
    }
  }

  Future<void> _salvar(bool reiniciar) async {
    final novoConfig = AgentConfig(
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      deviceId: _deviceIdCtrl.text.trim(),
    );

    await novoConfig.save();

    if (!mounted) return;
    Navigator.pop(context);

    if (reiniciar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reiniciando...')),
      );
      Future.delayed(const Duration(milliseconds: 500), () => exit(0));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Configuração salva. Reinicie o CMS para aplicar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTesting = _status?.isTesting ?? false;

    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Configurações do Broker',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            TextField(
              controller: _hostCtrl,
              enabled: !isTesting,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: 'ex: 192.168.1.100 ou localhost',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portCtrl,
              enabled: !isTesting,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Porta',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deviceIdCtrl,
              enabled: !isTesting,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                helperText: 'Apenas letras minúsculas, números e _',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_status != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    if (_status!.isTesting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_status!.ok == true)
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 18)
                    else
                      const Icon(Icons.error, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status!.isTesting
                            ? 'Testando conexão...'
                            : _status!.message!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _status!.ok == true
                              ? Colors.green
                              : (_status!.isTesting
                                  ? Colors.white
                                  : Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: isTesting ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Testar conexão'),
                  onPressed: !_podeSalvar || isTesting ? null : _testar,
                ),
                FilledButton(
                  onPressed:
                      !_podeSalvar || isTesting ? null : () => _salvar(false),
                  child: const Text('Salvar'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.restart_alt),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('Salvar e reiniciar'),
                  onPressed:
                      !_podeSalvar || isTesting ? null : () => _salvar(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
