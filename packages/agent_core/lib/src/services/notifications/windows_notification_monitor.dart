// packages/agent_core/lib/src/services/notifications/windows_notification_monitor.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/agent_event.dart';
import '../../util/windows_binaries.dart';
import 'notification_monitor.dart';

/// Tipo de função para execução de processos em testes e runtime.
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  bool runInShell,
});

/// Representa os dados brutos de uma notificação capturada no Windows.
class WindowsNotificationRaw {
  final int id;
  final String appName;
  final String title;
  final String body;

  const WindowsNotificationRaw({
    required this.id,
    required this.appName,
    required this.title,
    required this.body,
  });

  factory WindowsNotificationRaw.fromJson(Map<String, dynamic> json) {
    return WindowsNotificationRaw(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      appName: (json['app']?.toString() ?? '').trim(),
      title: (json['title']?.toString() ?? '').trim(),
      body: (json['body']?.toString() ?? '').trim(),
    );
  }

  AgentEvent? toAgentEvent({Set<String> ignoredApps = const {}}) {
    final cleanApp = appName.trim();
    if (cleanApp.isNotEmpty && ignoredApps.contains(cleanApp.toLowerCase())) {
      return null;
    }

    final cleanTitle = title.trim();
    final cleanBody = body.trim();

    // Formata o texto: [AppName] Title: Body
    final buffer = StringBuffer();
    if (cleanApp.isNotEmpty) {
      buffer.write('[$cleanApp] ');
    }

    if (cleanTitle.isNotEmpty && cleanBody.isNotEmpty) {
      buffer.write('$cleanTitle: $cleanBody');
    } else if (cleanTitle.isNotEmpty) {
      buffer.write(cleanTitle);
    } else if (cleanBody.isNotEmpty) {
      buffer.write(cleanBody);
    }

    final message = buffer.toString().trim();
    if (message.isEmpty) return null;

    return AgentEvent(
      kind: AgentEventKind.info,
      message: message,
      durationMs: 4000,
    );
  }
}

/// Parser de linhas emitidas pelo helper de notificações do Windows.
class WindowsNotificationParser {
  final void Function(WindowsNotificationRaw notification) onNotification;

  WindowsNotificationParser({required this.onNotification});

  void processLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return;
    }

    try {
      final json = jsonDecode(trimmed);
      if (json is Map<String, dynamic>) {
        if (json.containsKey('status') && json['status'] == 'ready') {
          return;
        }
        if (json.containsKey('app') || json.containsKey('title') || json.containsKey('body')) {
          onNotification(WindowsNotificationRaw.fromJson(json));
        }
      }
    } catch (_) {
      // Ignora saídas que não sejam JSON válido
    }
  }
}

/// Monitor de notificações para Windows via `hub_audio_helper.exe watch-notifications`.
class WindowsNotificationMonitor implements NotificationMonitor {
  final _controller = StreamController<AgentEvent>.broadcast();
  final ProcessStarter _starter;
  final String? _helperPathOverride;

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  bool _isAvailable = false;
  bool _disposed = false;

  /// Nomes de aplicativos ignorados.
  final Set<String> ignoredApps;

  WindowsNotificationMonitor({
    Set<String>? ignoredApps,
    ProcessStarter? starter,
    String? helperPathOverride,
  })  : ignoredApps = ignoredApps ?? {'hub_agent', 'cms_app'},
        _starter = starter ?? Process.start,
        _helperPathOverride = helperPathOverride;

  @override
  Stream<AgentEvent> get notifications => _controller.stream;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<void> start() async {
    if (_disposed || _process != null) return;

    final helper = _helperPathOverride ?? WindowsBinaries.resolveHelperPath();
    if (helper == null) {
      stderr.writeln('windows_notification_monitor: hub_audio_helper.exe não encontrado');
      return;
    }

    try {
      final proc = await _starter(
        helper,
        ['watch-notifications'],
        runInShell: false,
      );

      _process = proc;
      _isAvailable = true;

      final parser = WindowsNotificationParser(
        onNotification: (notification) {
          final event = notification.toAgentEvent(ignoredApps: ignoredApps);
          if (event != null && !_controller.isClosed) {
            _controller.add(event);
          }
        },
      );

      _stdoutSub = proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            parser.processLine,
            onError: (e) {
              stderr.writeln('windows_notification_monitor stdout error: $e');
            },
            onDone: () {
              _isAvailable = false;
            },
          );
    } catch (e) {
      stderr.writeln('windows_notification_monitor failed to start helper: $e');
      _isAvailable = false;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _isAvailable = false;
    await _stdoutSub?.cancel();
    _process?.kill();
    _process = null;
    await _controller.close();
  }
}

