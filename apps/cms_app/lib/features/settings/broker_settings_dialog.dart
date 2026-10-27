import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../system/agent_config.dart';
import '../../system/autostart_controller.dart';
import '../../system/voicemeeter_service.dart';

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
  late final TextEditingController _voiceMeeterPathController;
  late final TextEditingController _voiceMeeterConfigXmlController;

  bool? _autostartEnabled;
  bool _mirrorNotifications = true;
  bool _autoStartVoiceMeeter = false;
  bool _isVoiceMeeterRunning = false;
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
    _autoStartVoiceMeeter = config.autoStartVoiceMeeter;
    _voiceMeeterPathController =
        TextEditingController(text: config.voiceMeeterPath ?? '');
    _voiceMeeterConfigXmlController =
        TextEditingController(text: config.voiceMeeterConfigXml ?? '');

    _loadAutostart();
    _loadDevices();
    _loadVoiceMeeter();
  }

  Future<void> _loadVoiceMeeter() async {
    if (!Platform.isWindows) return;
    final running = await VoiceMeeterService.isRunning();
    if (mounted) {
      setState(() => _isVoiceMeeterRunning = running);
    }
  }

  Future<void> _loadDevices() async {
    final runtime = ref.read(agentRuntimeProvider);
    final list = await (runtime.sound?.listDevices() ??
        Future.value(<AudioOutputDevice>[]));
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
    _voiceMeeterPathController.dispose();
    _voiceMeeterConfigXmlController.dispose();
    super.dispose();
  }

  Future<void> _save({required bool restart}) async {
    final config = ref.read(agentConfigProvider);
    final updated = AgentConfig(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 1883,
      deviceId: _deviceIdController.text.trim(),
      soundOutputDevice: _selectedSoundDevice,
      mirrorNotifications: _mirrorNotifications,
      soundVolume: config.soundVolume,
      autoStartVoiceMeeter: _autoStartVoiceMeeter,
      voiceMeeterPath: _voiceMeeterPathController.text.trim().isEmpty
          ? null
          : _voiceMeeterPathController.text.trim(),
      voiceMeeterConfigXml: _voiceMeeterConfigXmlController.text.trim().isEmpty
          ? null
          : _voiceMeeterConfigXmlController.text.trim(),
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
              subtitle: const Text('Envia notificações do sistema para o tablet via MQTT'),
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
                      _devices.any((d) =>
                          d.id == _selectedSoundDevice ||
                          d.name == _selectedSoundDevice))
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
            if (Platform.isWindows) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'VoiceMeeter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isVoiceMeeterRunning ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isVoiceMeeterRunning ? 'Executando' : 'Parado',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isVoiceMeeterRunning
                              ? Colors.green
                              : Colors.white54,
                        ),
                      ),
                      if (!_isVoiceMeeterRunning) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final ok = await VoiceMeeterService.launch(
                              customPath:
                                  _voiceMeeterPathController.text.trim().isEmpty
                                      ? null
                                      : _voiceMeeterPathController.text.trim(),
                              configXml: _voiceMeeterConfigXmlController.text
                                      .trim()
                                      .isEmpty
                                  ? null
                                  : _voiceMeeterConfigXmlController.text.trim(),
                            );
                            if (mounted) {
                              _loadVoiceMeeter();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'VoiceMeeter iniciado!'
                                      : 'Falha ao iniciar VoiceMeeter.'),
                                ),
                              );
                            }
                          },
                          child: const Text('Iniciar Agora'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Iniciar VoiceMeeter com o sistema'),
                subtitle: const Text(
                    'Abre o VoiceMeeter minimizado na bandeja ao ligar o PC'),
                value: _autoStartVoiceMeeter,
                onChanged: (val) => setState(() => _autoStartVoiceMeeter = val),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _voiceMeeterConfigXmlController,
                decoration: const InputDecoration(
                  labelText: 'Preset XML do VoiceMeeter (opcional)',
                  hintText: r'C:\presets\meu_voicemeeter.xml',
                ),
              ),
            ],
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
