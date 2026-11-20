import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../system/agent_config.dart';
import '../../system/autostart_controller.dart';
import '../../system/voicemeeter_service.dart';
import '../editor/key_combo_helper.dart';

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
  bool _osdEnabled = true;
  String _osdPosition = 'bottom_center';
  String _searchHotkey = 'alt+space';
  bool _isRecordingHotkey = false;
  GlobalHotkeyStatus? _hotkeyStatus;
  final FocusNode _hotkeyFocusNode = FocusNode();
  bool _autoStartVoiceMeeter = false;
  bool _isVoiceMeeterRunning = false;
  List<AudioOutputDevice> _devices = [];
  String? _selectedSoundDevice;

  bool _isPlayingTest = false;
  bool _isTestingTcp = false;
  String? _tcpTestResult;
  bool? _tcpTestOk;

  Future<void> _testTcpConnection() async {
    if (_isTestingTcp) return;
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 1883;
    if (host.isEmpty) {
      setState(() {
        _tcpTestOk = false;
        _tcpTestResult = 'Informe o IP ou domínio do broker.';
      });
      return;
    }

    setState(() {
      _isTestingTcp = true;
      _tcpTestResult = null;
      _tcpTestOk = null;
    });

    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      sw.stop();
      socket.destroy();
      if (mounted) {
        setState(() {
          _isTestingTcp = false;
          _tcpTestOk = true;
          _tcpTestResult = 'Broker acessível em ${sw.elapsedMilliseconds} ms';
        });
      }
    } catch (e) {
      sw.stop();
      if (mounted) {
        setState(() {
          _isTestingTcp = false;
          _tcpTestOk = false;
          _tcpTestResult = 'Falha ao conectar em $host:$port';
        });
      }
    }
  }

  AudioOutputDevice? _getDeviceByKeywords(List<String> keywords) {
    for (final d in _devices) {
      final name = d.name.toLowerCase();
      for (final kw in keywords) {
        if (name.contains(kw.toLowerCase())) return d;
      }
    }
    return null;
  }

  IconData _iconForDevice(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('voicemeeter')) return Icons.tune;
    if (lower.contains('fone') ||
        lower.contains('headphone') ||
        lower.contains('headset') ||
        lower.contains('auricular')) {
      return Icons.headphones;
    }
    if (lower.contains('alto-falante') ||
        lower.contains('speaker') ||
        lower.contains('caixa') ||
        lower.contains('realtek')) {
      return Icons.speaker;
    }
    return Icons.volume_up;
  }

  Future<void> _playTestSound() async {
    if (_isPlayingTest) return;
    setState(() => _isPlayingTest = true);
    final bridge = ref.read(agentBridgeProvider);
    try {
      await bridge.playTestSound(targetDevice: _selectedSoundDevice);
    } catch (_) {}
    if (mounted) {
      setState(() => _isPlayingTest = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final bridge = ref.read(agentBridgeProvider);
    final config = bridge.currentConfig;
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
    _deviceIdController = TextEditingController(text: config.deviceId);
    _selectedSoundDevice = config.soundOutputDevice;
    _mirrorNotifications = config.mirrorNotifications;
    _osdEnabled = config.osdEnabled;
    _osdPosition = config.osdPosition;
    _searchHotkey = bridge.hotkeyCombo;
    _hotkeyStatus = bridge.hotkeyStatus;
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
    final bridge = ref.read(agentBridgeProvider);
    final list = await bridge.listSoundDevices();
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
    _hotkeyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _applySearchHotkey(String combo) async {
    final normalized = KeyComboHelper.normalize(combo);
    setState(() {
      _searchHotkey = normalized;
      _isRecordingHotkey = false;
    });
    final status =
        await ref.read(agentBridgeProvider).updateHotkey(normalized);
    if (mounted) {
      setState(() => _hotkeyStatus = status);
    }
  }

  Future<void> _save({required bool reconnectNow}) async {
    final bridge = ref.read(agentBridgeProvider);
    final config = bridge.currentConfig;
    final newHost = _hostController.text.trim();
    final newPort = int.tryParse(_portController.text.trim()) ?? 1883;
    final newDeviceId = _deviceIdController.text.trim();

    final updated = AgentConfig(
      host: newHost,
      port: newPort,
      deviceId: newDeviceId,
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
      osdEnabled: _osdEnabled,
      osdPosition: _osdPosition,
      searchHotkey: _searchHotkey,
    );

    final brokerChanged = newHost != bridge.mqttHost ||
        newPort != bridge.mqttPort ||
        newDeviceId != bridge.mqttDeviceId;

    await bridge.saveConfigAndApply(
      updated,
      reconnectNow: reconnectNow || brokerChanged,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (reconnectNow || brokerChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações salvas e broker reconectado.'),
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
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      title: const Text('Configurações do Agente'),
      content: SizedBox(
        width: 520,
        height: 430,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.hub_outlined, size: 17), text: 'Conexão'),
                  Tab(icon: Icon(Icons.speaker_group_outlined, size: 17), text: 'Áudio'),
                  Tab(icon: Icon(Icons.tune_rounded, size: 17), text: 'Sistema'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    // ABA 1: CONEXÃO MQTT
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _hostController,
                            decoration: const InputDecoration(
                              labelText: 'Host do Broker (IP ou domínio)',
                              prefixIcon: Icon(Icons.dns_outlined, size: 18),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Porta TCP (padrão 1883)',
                              prefixIcon: Icon(Icons.numbers, size: 18),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _deviceIdController,
                            decoration: const InputDecoration(
                              labelText: 'Device ID',
                              prefixIcon: Icon(Icons.badge_outlined, size: 18),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    _isTestingTcp ? null : _testTcpConnection,
                                icon: _isTestingTcp
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.network_check, size: 16),
                                label: const Text('Testar conexão TCP'),
                              ),
                              const SizedBox(width: 12),
                              if (_tcpTestResult != null)
                                Expanded(
                                  child: Text(
                                    _tcpTestResult!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _tcpTestOk == true
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ABA 2: ÁUDIO & VOICEMEETER
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
            Row(
              children: [
                const Icon(Icons.speaker_group, size: 18, color: Colors.deepPurpleAccent),
                const SizedBox(width: 8),
                const Text(
                  'Comportamento de Saída de Áudio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Escolha onde os sons do Sound Pad e do Hub serão reproduzidos no PC (no padrão do Windows, no fone de ouvido, na caixa de som ou no VoiceMeeter).',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.laptop_chromebook, size: 14),
                  label: const Text('Padrão do Windows', style: TextStyle(fontSize: 12)),
                  selected: _selectedSoundDevice == null || _selectedSoundDevice == 'default',
                  onSelected: (sel) {
                    if (sel) {
                      setState(() => _selectedSoundDevice = null);
                      ref.read(agentBridgeProvider).setSoundTargetDevice(null);
                    }
                  },
                ),
                if (_getDeviceByKeywords(['voicemeeter input', 'voicemeeter']) != null)
                  ChoiceChip(
                    avatar: const Icon(Icons.tune, size: 14),
                    label: const Text('VoiceMeeter VAIO', style: TextStyle(fontSize: 12)),
                    selected: _selectedSoundDevice != null &&
                        _selectedSoundDevice!.toLowerCase().contains('voicemeeter'),
                    selectedColor: Colors.deepPurple.shade700,
                    onSelected: (sel) {
                      if (sel) {
                        final vm = _getDeviceByKeywords(['voicemeeter input', 'voicemeeter'])!;
                        setState(() => _selectedSoundDevice = vm.name);
                        ref.read(agentBridgeProvider).setSoundTargetDevice(vm.name);
                      }
                    },
                  ),
                if (_getDeviceByKeywords(['fone', 'headphone', 'headset', 'auricular']) != null)
                  ChoiceChip(
                    avatar: const Icon(Icons.headphones, size: 14),
                    label: const Text('Fone de Ouvido', style: TextStyle(fontSize: 12)),
                    selected: _selectedSoundDevice ==
                        _getDeviceByKeywords(['fone', 'headphone', 'headset', 'auricular'])!.name,
                    onSelected: (sel) {
                      if (sel) {
                        final fone = _getDeviceByKeywords(['fone', 'headphone', 'headset', 'auricular'])!;
                        setState(() => _selectedSoundDevice = fone.name);
                        ref.read(agentBridgeProvider).setSoundTargetDevice(fone.name);
                      }
                    },
                  ),
                if (_getDeviceByKeywords(['alto-falante', 'speaker', 'caixa', 'realtek']) != null)
                  ChoiceChip(
                    avatar: const Icon(Icons.speaker, size: 14),
                    label: const Text('Caixa de Som', style: TextStyle(fontSize: 12)),
                    selected: _selectedSoundDevice ==
                        _getDeviceByKeywords(['alto-falante', 'speaker', 'caixa', 'realtek'])!.name,
                    onSelected: (sel) {
                      if (sel) {
                        final spk = _getDeviceByKeywords(['alto-falante', 'speaker', 'caixa', 'realtek'])!;
                        setState(() => _selectedSoundDevice = spk.name);
                        ref.read(agentBridgeProvider).setSoundTargetDevice(spk.name);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: (_selectedSoundDevice != null &&
                            _devices.any((d) =>
                                d.id == _selectedSoundDevice ||
                                d.name == _selectedSoundDevice))
                        ? _selectedSoundDevice
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Dispositivo específico',
                      prefixIcon: Icon(Icons.output, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Row(
                          children: [
                            Icon(Icons.laptop_chromebook, size: 16, color: Colors.white54),
                            SizedBox(width: 8),
                            Text('Dispositivo Padrão do Sistema'),
                          ],
                        ),
                      ),
                      ..._devices.map(
                        (d) => DropdownMenuItem<String>(
                          value: d.name,
                          child: Row(
                            children: [
                              Icon(_iconForDevice(d.name), size: 16, color: Colors.white54),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  d.isDefault ? '${d.name} (Padrão)' : d.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedSoundDevice = val);
                      ref.read(agentBridgeProvider).setSoundTargetDevice(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _playTestSound,
                  icon: Icon(_isPlayingTest ? Icons.volume_up : Icons.play_arrow, size: 16),
                  label: Text(_isPlayingTest ? 'Tocando...' : 'Testar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_selectedSoundDevice != null &&
                _selectedSoundDevice!.toLowerCase().contains('voicemeeter'))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.4)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, size: 16, color: Colors.purpleAccent),
                        SizedBox(width: 8),
                        Text(
                          'Roteamento via VoiceMeeter Ativo',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purpleAccent),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Os sons do Hub entrarão no VoiceMeeter VAIO. Para ouvir ou transmitir, certifique-se de que no VoiceMeeter:\n'
                      '• [A1] esteja ligado para sair no seu Fone de Ouvido\n'
                      '• [A2] esteja ligado para sair na Caixa de Som\n'
                      '• [B1] esteja ligado para transmitir no Microfone do Discord/Jogos',
                      style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.white38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedSoundDevice == null
                            ? 'Sons serão reproduzidos no dispositivo de áudio padrão do Windows.'
                            : 'Sons serão reproduzidos diretamente em: $_selectedSoundDevice',
                        style: const TextStyle(fontSize: 11, color: Colors.white60),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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
                    // ABA 3: SISTEMA
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            title: const Text('Iniciar com o sistema'),
                            subtitle: const Text(
                                'O agente abre minimizado na bandeja ao ligar o PC'),
                            value: _autostartEnabled ?? false,
                            onChanged: _autostartEnabled == null
                                ? null
                                : _toggleAutostart,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(height: 20),
                          SwitchListTile(
                            title: const Text('Espelhar notificações do PC'),
                            subtitle: const Text(
                                'Envia notificações do sistema para o tablet via MQTT'),
                            value: _mirrorNotifications,
                            onChanged: (val) =>
                                setState(() => _mirrorNotifications = val),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(height: 20),
                          SwitchListTile(
                            title: const Text('HUD flutuante (OSD) no PC'),
                            subtitle: const Text(
                                'Mostra uma pílula translúcida ao alterar sliders, volume, brilho ou ações'),
                            value: _osdEnabled,
                            onChanged: (val) {
                              setState(() => _osdEnabled = val);
                              ref
                                  .read(agentBridgeProvider)
                                  .setOsdConfig(enabled: val);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_osdEnabled) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _osdPosition,
                                    decoration: const InputDecoration(
                                      labelText: 'Posição do HUD',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'bottom_center',
                                        child: Text('Inferior centro'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'top_center',
                                        child: Text('Superior centro (Island)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'top_right',
                                        child: Text('Superior direito'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(() => _osdPosition = val);
                                      ref
                                          .read(agentBridgeProvider)
                                          .setOsdConfig(position: val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    ref
                                        .read(agentBridgeProvider)
                                        .testOsd(position: _osdPosition);
                                  },
                                  icon: const Icon(Icons.visibility_outlined,
                                      size: 16),
                                  label: const Text('Testar HUD'),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 24),
                          const Text(
                            'Atalho global de busca rápida (Spotlight)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Abre a barra de busca do Hub Agent de qualquer tela (mesmo minimizado).',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white60),
                          ),
                          const SizedBox(height: 10),
                          Focus(
                            focusNode: _hotkeyFocusNode,
                            onKeyEvent: (node, event) {
                              if (!_isRecordingHotkey) {
                                return KeyEventResult.ignored;
                              }
                              if (event is! KeyDownEvent) {
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.escape) {
                                setState(() => _isRecordingHotkey = false);
                                return KeyEventResult.handled;
                              }
                              final combo = KeyComboHelper.fromKeyEvent(event);
                              if (combo == null || combo.isEmpty) {
                                return KeyEventResult.handled;
                              }
                              // Exige pelo menos 1 tecla não-modificadora
                              final parts = combo.split('+');
                              final hasNonMod = parts.any(
                                (p) => !KeyComboHelper.canonicalModifiers
                                    .contains(p),
                              );
                              if (!hasNonMod) {
                                return KeyEventResult.handled;
                              }
                              _applySearchHotkey(combo);
                              return KeyEventResult.handled;
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() => _isRecordingHotkey = true);
                                      _hotkeyFocusNode.requestFocus();
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isRecordingHotkey
                                            ? const Color(0xFF89B4FA)
                                                .withValues(alpha: 0.14)
                                            : const Color(0xFF181825),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _isRecordingHotkey
                                              ? const Color(0xFF89B4FA)
                                              : Colors.white24,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _isRecordingHotkey
                                                ? Icons.fiber_manual_record
                                                : Icons.keyboard_alt_outlined,
                                            size: 16,
                                            color: _isRecordingHotkey
                                                ? const Color(0xFF89B4FA)
                                                : Colors.white70,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _isRecordingHotkey
                                                ? 'Pressione o atalho desejado... (Esc cancela)'
                                                : (_searchHotkey.isEmpty
                                                    ? 'Desativado'
                                                    : KeyComboHelper
                                                        .formatDisplay(
                                                            _searchHotkey)),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _isRecordingHotkey
                                                  ? const Color(0xFF89B4FA)
                                                  : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: () {
                                    setState(() => _isRecordingHotkey =
                                        !_isRecordingHotkey);
                                    if (_isRecordingHotkey) {
                                      _hotkeyFocusNode.requestFocus();
                                    }
                                  },
                                  child: Text(
                                    _isRecordingHotkey ? 'Cancelar' : 'Gravar',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final preset in const [
                                ('alt+space', 'Alt + Space'),
                                ('ctrl+shift+space', 'Ctrl + Shift + Space'),
                                ('ctrl+alt+k', 'Ctrl + Alt + K'),
                                ('', 'Desativar'),
                              ])
                                ChoiceChip(
                                  label: Text(
                                    preset.$2,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  selected: _searchHotkey == preset.$1,
                                  onSelected: (_) =>
                                      _applySearchHotkey(preset.$1),
                                ),
                            ],
                          ),
                          if (_hotkeyStatus == GlobalHotkeyStatus.inUse)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Este atalho já está em uso por outro programa. Escolha outra combinação.',
                                style: TextStyle(
                                  color: Color(0xFFF38BA8),
                                  fontSize: 11.5,
                                ),
                              ),
                            )
                          else if (_hotkeyStatus == GlobalHotkeyStatus.ready &&
                              _searchHotkey.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Atalho global ativo.',
                                style: TextStyle(
                                  color: Color(0xFFA6E3A1),
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        OutlinedButton(
          onPressed: () => _save(reconnectNow: false),
          child: const Text('Salvar'),
        ),
        FilledButton(
          onPressed: () => _save(reconnectNow: true),
          child: const Text('Salvar e reconectar'),
        ),
      ],
    );
  }
}
