import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/agent_event.dart';
import 'notification_monitor.dart';

/// Monitor de notificações para Linux que escuta chamadas D-Bus `Notify`
/// no barramento de sessão através do `dbus-monitor`.
class LinuxNotificationMonitor implements NotificationMonitor {
  final _controller = StreamController<AgentEvent>.broadcast();
  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  bool _isAvailable = false;
  bool _disposed = false;

  /// Nomes de aplicativos que não devem ser espelhados (ruído ou loops).
  final Set<String> ignoredApps;

  LinuxNotificationMonitor({
    Set<String>? ignoredApps,
  }) : ignoredApps = ignoredApps ?? {'hub_agent', 'cms_app'};

  @override
  Stream<AgentEvent> get notifications => _controller.stream;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<void> start() async {
    if (_disposed || _process != null) return;

    try {
      final proc = await Process.start(
        'dbus-monitor',
        [
          '--session',
          "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
        ],
      );

      _process = proc;
      _isAvailable = true;

      final parser = DbusNotifyParser(
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
              _isAvailable = false;
            },
            onDone: () {
              _isAvailable = false;
            },
          );
    } catch (_) {
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

/// Representa os dados brutos de uma notificação capturada do D-Bus.
class DbusNotificationRaw {
  final String appName;
  final String summary;
  final String body;
  final int urgency; // 0 = low, 1 = normal, 2 = critical

  const DbusNotificationRaw({
    required this.appName,
    required this.summary,
    required this.body,
    this.urgency = 1,
  });

  AgentEvent? toAgentEvent({Set<String> ignoredApps = const {}}) {
    final cleanApp = appName.trim();
    if (cleanApp.isNotEmpty && ignoredApps.contains(cleanApp.toLowerCase())) {
      return null;
    }

    final cleanSummary = summary.trim();
    final cleanBody = body.trim();

    // Formata o texto conforme o padrão acordado:
    // [AppName] Title: Body
    final buffer = StringBuffer();
    if (cleanApp.isNotEmpty) {
      buffer.write('[$cleanApp] ');
    }

    if (cleanSummary.isNotEmpty && cleanBody.isNotEmpty) {
      buffer.write('$cleanSummary: $cleanBody');
    } else if (cleanSummary.isNotEmpty) {
      buffer.write(cleanSummary);
    } else if (cleanBody.isNotEmpty) {
      buffer.write(cleanBody);
    }

    final message = buffer.toString().trim();
    if (message.isEmpty) return null;

    final kind = switch (urgency) {
      2 => AgentEventKind.warning,
      _ => AgentEventKind.info,
    };

    final durationMs = switch (urgency) {
      2 => 5000,
      0 => 3000,
      _ => 4000,
    };

    return AgentEvent(
      kind: kind,
      message: message,
      durationMs: durationMs,
    );
  }
}

/// Parser de streaming para saída do `dbus-monitor` escutando chamadas `Notify`.
class DbusNotifyParser {
  final void Function(DbusNotificationRaw notification) onNotification;

  int _step = 0; // 0 = aguardando Notify, 1 = appName, 2 = icon, 3 = summary, 4 = body, 5 = hints
  final List<String> _currentLines = [];
  String _appName = '';
  String _summary = '';
  String _body = '';
  int _urgency = 1;
  bool _readingUrgencyVariant = false;

  DbusNotifyParser({required this.onNotification});

  void processLine(String line) {
    final trimmed = line.trim();

    // Início de uma nova chamada method_call Notify
    if (trimmed.contains("member=Notify") && trimmed.startsWith("method call")) {
      _flushNotification();
      _reset();
      _step = 1; // Próximo campo string é app_name
      return;
    }

    if (_step == 0) return;

    if (_step == 1) {
      // Procurando app_name
      if (trimmed.startsWith('uint32 ')) {
        // app_name finalizou (pode ter sido vazio ou multiline)
        _appName = _extractStringContent();
        _currentLines.clear();
        _step = 2; // Agora procurando icon
        return;
      }
      _currentLines.add(line);
      return;
    }

    if (_step == 2) {
      // Procurando app_icon
      if (trimmed.startsWith('string "') && _currentLines.isNotEmpty) {
        // Encontramos o início do summary, então o icon acabou
        _currentLines.clear();
        _currentLines.add(line);
        _step = 3; // Lendo summary
        return;
      }
      _currentLines.add(line);
      return;
    }

    if (_step == 3) {
      // Procurando summary
      if (trimmed.startsWith('string "') && _currentLines.isNotEmpty) {
        // Encontramos o início do body, então o summary acabou
        _summary = _extractStringContent();
        _currentLines.clear();
        _currentLines.add(line);
        _step = 4; // Lendo body
        return;
      }
      _currentLines.add(line);
      return;
    }

    if (_step == 4) {
      // Procurando body
      if (trimmed.startsWith('array [') || trimmed.startsWith('uint32 ') || trimmed.startsWith('int32 ')) {
        // Fim do body
        _body = _extractStringContent();
        _currentLines.clear();
        _step = 5; // Lendo hints / resto
        return;
      }
      _currentLines.add(line);
      return;
    }

    if (_step == 5) {
      // Procurando urgência nos hints
      if (trimmed == 'string "urgency"') {
        _readingUrgencyVariant = true;
        return;
      }

      if (_readingUrgencyVariant && trimmed.contains('byte ')) {
        final parts = trimmed.split('byte ');
        if (parts.length > 1) {
          final val = int.tryParse(parts[1].trim());
          if (val != null) {
            _urgency = val;
          }
        }
        _readingUrgencyVariant = false;
        return;
      }

      // int32 no final da chamada fecha a notificação
      if (trimmed.startsWith('int32 ')) {
        _flushNotification();
        _reset();
        return;
      }
    }
  }

  void _flushNotification() {
    if (_step >= 4) {
      if (_step == 4 && _body.isEmpty) {
        _body = _extractStringContent();
      }
      if (_appName.isNotEmpty || _summary.isNotEmpty || _body.isNotEmpty) {
        onNotification(DbusNotificationRaw(
          appName: _appName,
          summary: _summary,
          body: _body,
          urgency: _urgency,
        ));
      }
    }
  }

  void _reset() {
    _step = 0;
    _currentLines.clear();
    _appName = '';
    _summary = '';
    _body = '';
    _urgency = 1;
    _readingUrgencyVariant = false;
  }

  String _extractStringContent() {
    if (_currentLines.isEmpty) return '';
    final joined = _currentLines.join('\n');
    final firstQuote = joined.indexOf('"');
    if (firstQuote == -1) return '';
    final lastQuote = joined.lastIndexOf('"');
    if (lastQuote <= firstQuote) {
      return joined.substring(firstQuote + 1).trim();
    }
    return joined.substring(firstQuote + 1, lastQuote).trim();
  }
}
