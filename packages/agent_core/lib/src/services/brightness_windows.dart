import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../util/windows_binaries.dart';
import 'brightness_controller.dart';

/// Controle de brilho no Windows via `hub_audio_helper.exe` (DDC/CI dxva2.dll).
///
/// Mantém todas as chamadas Win32 isoladas no processo externo do helper.
class WindowsBrightnessController implements BrightnessController {
  final _changes = StreamController<void>.broadcast();
  final List<DisplayInfo> _displays = [];
  String? _helperPath;
  bool _available = false;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  bool get isAvailable => _available;

  @override
  List<DisplayInfo> get displays => List.unmodifiable(_displays);

  static List<DisplayInfo> parseDisplaysJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final result = <DisplayInfo>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final supported = item['supported'] == true;
        if (!supported) continue;
        final number = (item['number'] as num?)?.toInt();
        if (number == null || number <= 0) continue;
        final model = (item['model'] as String?)?.trim() ?? 'Monitor $number';
        result.add(DisplayInfo(
          number: number,
          bus: 'ddc',
          connector: 'monitor_$number',
          serial: '',
          model: model,
        ));
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  static int? parseBrightnessJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['value'] is num) {
        return (decoded['value'] as num).round().clamp(0, 100);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _resolveTarget(String match) {
    final trimmed = match.trim();
    if (trimmed.isEmpty) return 'all';
    final asNum = int.tryParse(trimmed);
    if (asNum != null && asNum > 0) return '$asNum';

    final lower = trimmed.toLowerCase();
    for (final d in _displays) {
      if (d.connector.toLowerCase() == lower ||
          d.model.toLowerCase().contains(lower)) {
        return '${d.number}';
      }
    }
    return 'all';
  }

  @override
  Future<void> start() async {
    _helperPath = WindowsBinaries.resolveHelperPath();
    if (_helperPath == null) {
      _available = false;
      return;
    }
    try {
      final r = await Process.run(
        _helperPath!,
        ['list-displays'],
        runInShell: false,
      ).timeout(const Duration(seconds: 4));
      if (r.exitCode == 0) {
        _displays
          ..clear()
          ..addAll(parseDisplaysJson((r.stdout as String).trim()));
        _available = _displays.isNotEmpty;
      }
    } catch (_) {
      _available = false;
    }
  }

  @override
  Future<void> set(int value) async {
    if (!_available || _helperPath == null) return;
    final v = value.clamp(0, 100);
    try {
      await Process.run(
        _helperPath!,
        ['set-brightness', 'all', '$v'],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));
      if (!_changes.isClosed) _changes.add(null);
    } catch (_) {}
  }

  @override
  Future<void> setForDisplay(String match, int value) async {
    if (!_available || _helperPath == null) return;
    final v = value.clamp(0, 100);
    final target = _resolveTarget(match);
    try {
      await Process.run(
        _helperPath!,
        ['set-brightness', target, '$v'],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));
      if (!_changes.isClosed) _changes.add(null);
    } catch (_) {}
  }

  @override
  Future<int?> readForDisplay(String match) async {
    if (!_available || _helperPath == null) return null;
    final target = _resolveTarget(match);
    final args = target == 'all' ? ['get-brightness'] : ['get-brightness', target];
    try {
      final r = await Process.run(
        _helperPath!,
        args,
        runInShell: false,
      ).timeout(const Duration(seconds: 3));
      if (r.exitCode == 0) {
        return parseBrightnessJson((r.stdout as String).trim());
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> dispose() async {
    await _changes.close();
  }
}
