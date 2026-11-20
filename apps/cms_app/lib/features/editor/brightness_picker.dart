import 'dart:async';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';

typedef MonitorInfo = DisplayInfo;

extension MonitorInfoLabel on DisplayInfo {
  String get label => connector.isNotEmpty ? '$connector ($model)' : model;
}

DateTime? _lastFetch;
List<MonitorInfo> _cachedMonitors = [];

Future<List<MonitorInfo>> detectMonitors() async {
  if (_lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < const Duration(seconds: 30)) {
    return _cachedMonitors;
  }

  if (!Platform.isLinux) return [];

  try {
    final r = await Process.run('ddcutil', ['detect'])
        .timeout(const Duration(seconds: 5));
    if (r.exitCode != 0) return [];

    final displays = LinuxBrightnessController.parseDdcutilDetect(r.stdout as String);
    _cachedMonitors = displays;
    _lastFetch = DateTime.now();
    return displays;
  } catch (_) {
    return [];
  }
}

class MonitorDropdown extends StatefulWidget {
  final String? currentMatch;
  final ValueChanged<String> onChanged;

  const MonitorDropdown({
    super.key,
    required this.currentMatch,
    required this.onChanged,
  });

  @override
  State<MonitorDropdown> createState() => _MonitorDropdownState();
}

class _MonitorDropdownState extends State<MonitorDropdown> {
  bool _isLoading = true;
  List<MonitorInfo> _monitors = [];
  late String _selectedValue;
  late TextEditingController _manualController;

  static const String valAll = '';
  static const String valManual = '__manual__';

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController(text: widget.currentMatch ?? '');
    _selectedValue = valAll;
    _load();
  }

  @override
  void didUpdateWidget(covariant MonitorDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMatch != widget.currentMatch) {
      _syncSelection(widget.currentMatch);
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await detectMonitors();
    if (mounted) {
      setState(() {
        _monitors = list;
        _isLoading = false;
        _syncSelection(widget.currentMatch);
      });
    }
  }

  void _syncSelection(String? match) {
    final m = (match ?? '').trim();
    if (m.isEmpty) {
      _selectedValue = valAll;
      _manualController.text = '';
    } else if (_monitors.any((mon) => mon.connector == m)) {
      _selectedValue = m;
      _manualController.text = '';
    } else {
      _selectedValue = valManual;
      _manualController.text = m;
    }
  }

  void _handleDropdownChange(String? value) {
    if (value == null) return;
    setState(() => _selectedValue = value);

    if (value == valManual) {
      // Deixa o manual em branco para ele preencher, ou envia o existente
      widget.onChanged(_manualController.text);
    } else {
      widget.onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Detectando monitores...',
                style: TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: _selectedValue,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Alvo (Monitor)',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
              value: valAll,
              child: Text('Todos os monitores'),
            ),
            ..._monitors.map((m) => DropdownMenuItem(
                  value: m.connector,
                  child: Text(m.label, overflow: TextOverflow.ellipsis),
                )),
            const DropdownMenuItem(
              value: valManual,
              child: Text('Outro (digitar manual)'),
            ),
          ],
          onChanged: _handleDropdownChange,
        ),
        if (_selectedValue == valManual) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _manualController,
            decoration: const InputDecoration(
              labelText: 'Match manual (connector ou serial)',
              hintText: 'ex: card1-HDMI-A-1 ou serial...',
              border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (value) {
              widget.onChanged(value.trim());
            },
          ),
        ]
      ],
    );
  }
}
