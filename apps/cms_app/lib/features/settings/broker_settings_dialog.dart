import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../system/agent_config.dart';
import '../../system/autostart_controller.dart';

Future<void> showBrokerSettingsDialog(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _BrokerSettingsDialog(),
  );
}

class _BrokerSettingsDialog extends ConsumerStatefulWidget {
  const _BrokerSettingsDialog();

  @override
  ConsumerState<_BrokerSettingsDialog> createState() =>
      _BrokerSettingsDialogState();
}

class _BrokerSettingsDialogState extends ConsumerState<_BrokerSettingsDialog> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _deviceIdController;

  bool? _autostartEnabled;
  bool _mirrorNotifications = true;
  List<AudioOutputDevice> _devices = [];
  String? _selectedSoundDevice;

  @override
  void initState() {
    super.initState();
    final config = ref.read(agentConfigProvider);
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
    _deviceIdController = TextEditingController(text: config.deviceId);
    _selectedSoundDevice = config.soundOutputDevice;
    _mirrorNotifications = config.mirrorNotifications;

    _loadAutostart();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final runtime = ref.read(agentRuntimeProvider);
    final list = await (runtime.sound?.listDevices() ?? Future.value(<AudioOutputDevice>[]));
    if (mounted) {
      setState(() => _devices = list);
    }
  }

  Future<void> _loadAutostart() async {
    try {
      final v = await AutostartController.isEnabled();
      if (mounted) setState(() => _autostartEnabled = v);
    } catch (_) {
      if (mounted) setState(() => _autostartEnabled = false);
    }
  }

  Future<void> _toggleAutostart(bool value) async {
    setState(() => _autostartEnabled = value);
    try {
      if (value) {
        await AutostartController.enable();
      } else {
        await AutostartController.disable();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'Autostart ativado' : 'Autostart desativado'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _autostartEnabled = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _save({required bool restart}) async {
    // AgentConfig é imutável: criar um novo com os valores editados.
    final updated = AgentConfig(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 1883,
      deviceId: _deviceIdController.text.trim(),
      soundOutputDevice: _selectedSoundDevice,
      mirrorNotifications: _mirrorNotifications,
    );

    await updated.save();

    if (!mounted) return;

    Navigator.of(context).pop();

    if (restart) {
      final runtime = ref.read(agentRuntimeProvider);
      await runtime.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações salvas. Reinicie o CMS para aplicar.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurações do Agente'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(labelText: 'Host (IP ou domínio)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Porta'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(labelText: 'Device ID'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Iniciar com o sistema'),
              subtitle: const Text('O agente abre escondido no boot'),
              value: _autostartEnabled ?? false,
              onChanged: _autostartEnabled == null ? null : _toggleAutostart,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Espelhar notificações do PC'),
              subtitle: const Text('Envia notificações do sistema (D-Bus) para o tablet via MQTT'),
              value: _mirrorNotifications,
              onChanged: (val) => setState(() => _mirrorNotifications = val),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 32),
            const Text(
              'Sound Pad (Dispositivo de Saída)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: (_selectedSoundDevice != null &&
                      _devices.any((d) => d.id == _selectedSoundDevice || d.name == _selectedSoundDevice))
                  ? _selectedSoundDevice
                  : null,
              decoration: const InputDecoration(
                labelText: 'Saída de áudio do microfone/pad',
                hintText: 'Dispositivo Padrão do Sistema',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Dispositivo Padrão do Sistema'),
                ),
                ..._devices.map(
                  (d) => DropdownMenuItem<String>(
                    value: d.name,
                    child: Text(
                      d.isDefault ? '${d.name} (Padrão)' : d.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedSoundDevice = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => _save(restart: false),
          child: const Text('Salvar'),
        ),
        FilledButton(
          onPressed: () => _save(restart: true),
          child: const Text('Salvar e reiniciar'),
        ),
      ],
    );
  }
}