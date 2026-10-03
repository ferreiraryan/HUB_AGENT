import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

class MonitorInfo {
  final int number;
  final String connector;
  final String serial;
  final String model;

  String get label => '$connector ($model)';

  const MonitorInfo({
    required this.number,
    required this.connector,
    required this.serial,
    required this.model,
  });
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

    final displays = <MonitorInfo>[];
    final lines = (r.stdout as String).split('\n');

    int? number;
    String? conn, serial, model;

    void flush() {
      if (number != null && conn != null) {
        displays.add(MonitorInfo(
          number: number,
          connector: conn,
          serial: serial ?? '',
          model: model ?? '',
        ));
      }
    }

    for (final line in lines) {
      if (line.startsWith('Display ')) {
        flush();
        number = null;
        conn = null;
        serial = null;
        model = null;
        final match = RegExp(r'Display\s+(\d+)').firstMatch(line);
        if (match != null) number = int.tryParse(match.group(1)!);
      } else {
        if (line.contains('DRM connector:')) {
          conn = line.split(':')[1].trim();
        } else if (line.contains('Serial number:')) {
          serial = line.split(':')[1].trim();
        } else if (line.contains('Model:')) {
          model = line.split(':')[1].trim();
        }
      }
    }
    flush();

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
