import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../agent_runtime.dart';
import '../config/agent_config.dart';
import '../models/layout.dart';
import '../models/screensaver_config.dart';
import '../services/mqtt_service.dart';
import 'daemon_ipc_protocol.dart';

/// Servidor IPC loopback (`127.0.0.1` + Bearer Token) embutido no `hub_agent_daemon`.
///
/// Permite que o `cms_app` Flutter abra sob demanda como cliente fino de UI,
/// sem duplicar conexões MQTT nem serviços de hardware, e encerre (`exit(0)`)
/// ao fechar a janela devolvendo 100% da RAM gráfica ao SO.
class DaemonIpcServer {
  final AgentRuntime runtime;
  final Directory supportDir;
  final AgentConfig Function() getConfig;
  final Future<void> Function(AgentConfig updated, {required bool reconnect})
      onUpdateConfig;
  final Future<GlobalHotkeyStatus> Function(String combo)? onUpdateHotkey;
  final String Function()? getHotkeyCombo;
  final GlobalHotkeyStatus Function()? getHotkeyStatus;
  final Future<void> Function()? onShutdownRequested;

  HttpServer? _server;
  String? _token;
  final Set<WebSocket> _wsClients = {};
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _disposed = false;

  DaemonIpcServer({
    required this.runtime,
    required this.supportDir,
    required this.getConfig,
    required this.onUpdateConfig,
    this.onUpdateHotkey,
    this.getHotkeyCombo,
    this.getHotkeyStatus,
    this.onShutdownRequested,
  });

  int? get port => _server?.port;
  String? get token => _token;
  bool get hasUiClient => _wsClients.isNotEmpty;

  Future<DaemonEndpointInfo> start() async {
    _token = DaemonEndpointInfo.generateToken();
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleHttpRequest);

    _subs
      ..add(runtime.connectionState.listen((s) {
        broadcastEvent('connection_state', {'state': s.name});
      }))
      ..add(runtime.layoutChanges.listen((l) {
        broadcastEvent('layout_changed', {'layout': l.toDiskJson()});
      }))
      ..add(runtime.appVolumeChanges.listen((apps) {
        broadcastEvent('audio_apps', {
          'apps': apps.map((a) => a.toJson()).toList(),
        });
      }))
      ..add(runtime.weather.updates.listen((w) {
        broadcastEvent('weather_updated', {'weather': w.toJson()});
      }))
      ..add(runtime.pageRules.changes.listen((rules) {
        broadcastEvent('page_rules_changed', {'rules': rules});
      }));

    if (runtime.sound != null) {
      _subs.add(runtime.sound!.stateChanges.listen((st) {
        broadcastEvent('sound_state', {'state': st.toJson()});
      }));
    }

    final info = DaemonEndpointInfo(
      pid: pid,
      port: _server!.port,
      token: _token!,
    );
    await info.writeAtomic(supportDir);
    return info;
  }

  void broadcastEvent(String event, [Map<String, dynamic>? data]) {
    if (_wsClients.isEmpty || _disposed) return;
    final payload = jsonEncode({
      'event': event,
      if (data != null) ...data,
    });
    final dead = <WebSocket>[];
    for (final ws in _wsClients) {
      try {
        ws.add(payload);
      } catch (_) {
        dead.add(ws);
      }
    }
    _wsClients.removeAll(dead);
  }

  bool _isAuthorized(HttpRequest req) {
    final expected = _token;
    if (expected == null || expected.isEmpty) return false;
    final auth = req.headers.value(HttpHeaders.authorizationHeader);
    if (auth == 'Bearer $expected') return true;
    final queryToken = req.uri.queryParameters['token'];
    return queryToken == expected;
  }

  Future<void> _handleHttpRequest(HttpRequest req) async {
    if (!_isAuthorized(req)) {
      req.response.statusCode = HttpStatus.unauthorized;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'error': 'unauthorized'}));
      await req.response.close();
      return;
    }

    final path = req.uri.path;
    final method = req.method.toUpperCase();

    if (path == '/v1/events' && WebSocketTransformer.isUpgradeRequest(req)) {
      try {
        final ws = await WebSocketTransformer.upgrade(req);
        _wsClients.add(ws);
        ws.listen(
          (_) {},
          onDone: () => _wsClients.remove(ws),
          onError: (_) => _wsClients.remove(ws),
          cancelOnError: true,
        );
      } catch (_) {}
      return;
    }

    try {
      final result = await _route(method, path, req);
      req.response.statusCode = result.$1;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(result.$2));
    } catch (e) {
      req.response.statusCode = HttpStatus.internalServerError;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'ok': false, 'error': '$e'}));
    } finally {
      await req.response.close();
    }
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest req) async {
    final raw = await utf8.decoder.bind(req).join();
    if (raw.trim().isEmpty) return const {};
    final decoded = jsonDecode(raw);
    return decoded is Map ? decoded.cast<String, dynamic>() : const {};
  }

  Future<(int, Map<String, dynamic>)> _route(
    String method,
    String path,
    HttpRequest req,
  ) async {
    if (method == 'GET' && path == '/v1/health') {
      return (HttpStatus.ok, {'ok': true, 'pid': pid});
    }

    if (method == 'GET' && path == '/v1/state') {
      return (
        HttpStatus.ok,
        {
          'ok': true,
          'connection_state': runtime.mqtt.stateNotifier.value.name,
          'config': getConfig().toJson(),
          'layout': runtime.repository.isLoaded
              ? runtime.repository.current.toDiskJson()
              : null,
          'screensaver': runtime.screensaver.current.toJson(),
          'weather': runtime.weather.current?.toJson(),
          'page_rules': runtime.pageRules.current,
          'audio_apps': runtime.audio.apps.map((a) => a.toJson()).toList(),
          'sound_state': runtime.sound?.current.toJson(),
          'hotkey_combo': getHotkeyCombo?.call() ?? getConfig().searchHotkey,
          'hotkey_status':
              (getHotkeyStatus?.call() ?? GlobalHotkeyStatus.disabled).name,
        },
      );
    }

    if (method == 'PUT' && path == '/v1/layout') {
      final body = await _readJsonBody(req);
      final layoutJson = (body['layout'] is Map)
          ? (body['layout'] as Map).cast<String, dynamic>()
          : body;
      final layout = Layout.fromJson(layoutJson);
      final force = req.uri.queryParameters['force'] == 'true' ||
          body['force'] == true;
      runtime.repository.save(layout);
      if (force) {
        await runtime.repository.flush();
        runtime.mqtt.publishLayout(layout, force: true);
      }
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/layout/flush') {
      await runtime.repository.flush();
      if (runtime.repository.isLoaded) {
        runtime.mqtt.publishLayout(runtime.repository.current, force: true);
      }
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'PUT' && path == '/v1/screensaver') {
      final body = await _readJsonBody(req);
      final cfgMap = (body['config'] is Map)
          ? (body['config'] as Map).cast<String, dynamic>()
          : body;
      runtime.screensaver.update(ScreensaverConfig.fromJson(cfgMap));
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/screensaver/flush') {
      await runtime.screensaver.flush();
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/screensaver/preview') {
      await runtime.screensaver.flush();
      runtime.mqtt.publishScreensaverCommand('open');
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/weather/configure') {
      final body = await _readJsonBody(req);
      final city = body['city']?.toString() ?? '';
      final unit = body['unit']?.toString();
      final w = await runtime.weather.configure(city: city, unit: unit);
      return (HttpStatus.ok, {'ok': true, 'weather': w?.toJson()});
    }

    if (method == 'PUT' && path == '/v1/page-rules') {
      final body = await _readJsonBody(req);
      final pageId = body['page_id']?.toString() ?? '';
      final list = (body['processes'] is List)
          ? (body['processes'] as List).map((e) => e.toString()).toList()
          : const <String>[];
      if (pageId.isEmpty) {
        return (HttpStatus.badRequest, {'ok': false, 'error': 'missing page_id'});
      }
      await runtime.pageRules.setTriggersForPage(pageId, list);
      return (HttpStatus.ok, {'ok': true, 'rules': runtime.pageRules.current});
    }

    if (method == 'PUT' && path == '/v1/config') {
      final body = await _readJsonBody(req);
      final cfgMap = (body['config'] is Map)
          ? (body['config'] as Map).cast<String, dynamic>()
          : body;
      final reconnect = body['reconnect'] == true;
      final updated = AgentConfig.fromJson(cfgMap);
      await onUpdateConfig(updated, reconnect: reconnect);
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/mqtt/reconnect') {
      await runtime.reconnectMqtt();
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/actions/dispatch') {
      final body = await _readJsonBody(req);
      final action = body['action']?.toString() ?? '';
      if (action.isEmpty) {
        return (HttpStatus.badRequest, {'ok': false, 'error': 'missing action'});
      }
      await runtime.dispatcher.dispatch(AgentCommand(action, body));
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/actions/test-chain') {
      final body = await _readJsonBody(req);
      final rawCmds = body['cmds'];
      if (rawCmds is! List) {
        return (HttpStatus.badRequest, {'ok': false, 'error': 'missing cmds'});
      }
      final cmds = <List<String>>[
        for (final c in rawCmds)
          if (c is List) c.map((e) => e.toString()).toList(),
      ];
      final results = await runtime.dispatcher.testChain(cmds);
      return (
        HttpStatus.ok,
        {
          'ok': true,
          'results': results
              .map((r) => {
                    'started': r.started,
                    'exit_code': r.exitCode,
                    'stdout': r.stdout,
                    'stderr': r.stderr,
                    'error': r.error,
                  })
              .toList(),
        },
      );
    }

    if (method == 'POST' && path == '/v1/actions/send-keys') {
      final body = await _readJsonBody(req);
      final combo = body['combo']?.toString() ?? '';
      final ok = combo.isNotEmpty
          ? await runtime.dispatcher.keySender.send(combo)
          : false;
      return (HttpStatus.ok, {'ok': true, 'sent': ok});
    }

    if (method == 'POST' && path == '/v1/actions/exists') {
      final body = await _readJsonBody(req);
      final binary = body['binary']?.toString() ?? '';
      final found = binary.isNotEmpty
          ? await runtime.dispatcher.exists(binary)
          : false;
      return (HttpStatus.ok, {'ok': true, 'exists': found});
    }

    if (method == 'POST' && path == '/v1/audio/refresh') {
      await runtime.audio.refresh();
      return (
        HttpStatus.ok,
        {
          'ok': true,
          'apps': runtime.audio.apps.map((a) => a.toJson()).toList(),
        },
      );
    }

    if (method == 'POST' && path == '/v1/audio/app-volume') {
      final body = await _readJsonBody(req);
      final match = body['match']?.toString() ?? '';
      final value = (body['value'] as num?)?.toInt() ?? 50;
      if (match.isNotEmpty) {
        await runtime.audio.setAppVolumeByName(match, value);
      }
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'GET' && path == '/v1/sound/devices') {
      final list = await (runtime.sound?.listDevices() ?? Future.value(const []));
      return (
        HttpStatus.ok,
        {
          'ok': true,
          'devices': list
              .map((d) => {'id': d.id, 'name': d.name, 'is_default': d.isDefault})
              .toList(),
        },
      );
    }

    if (method == 'POST' && path == '/v1/sound/play') {
      final body = await _readJsonBody(req);
      final id = body['sound_id']?.toString() ?? '';
      final dev = body['target_device']?.toString();
      if (id.isNotEmpty) {
        await runtime.sound?.play(id, targetDevice: dev);
      }
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/sound/stop') {
      await runtime.sound?.stop();
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/sound/test') {
      final body = await _readJsonBody(req);
      final dev = body['target_device']?.toString();
      await runtime.sound?.playTestSound(targetDevice: dev);
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/sound/invalidate-cache') {
      runtime.dispatcher.invalidateSoundCache();
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'PUT' && path == '/v1/sound/device') {
      final body = await _readJsonBody(req);
      final dev = body['device']?.toString();
      runtime.sound?.targetDevice = (dev == null || dev.isEmpty) ? null : dev;
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/osd/config') {
      final body = await _readJsonBody(req);
      runtime.osd.setConfig(
        enabled: body['enabled'] as bool?,
        position: body['position'] as String?,
      );
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/osd/test') {
      final body = await _readJsonBody(req);
      final position = body['position']?.toString();
      runtime.osd.setConfig(enabled: true, position: position);
      await runtime.osd.showSlider(
        title: body['title']?.toString() ?? 'Hub Agent OSD',
        value: (body['value'] as num?)?.toInt() ?? 74,
        icon: body['icon']?.toString() ?? 'volume',
      );
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/todo/add') {
      final body = await _readJsonBody(req);
      final text = body['text']?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        await runtime.todo.addItem(text);
      }
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'POST' && path == '/v1/search/query') {
      final body = await _readJsonBody(req);
      runtime.publishSearchQuery(
        body['query']?.toString() ?? '',
        active: body['active'] as bool? ?? true,
        filter: body['filter']?.toString() ?? 'all',
        scope: body['scope']?.toString() ?? 'all',
      );
      return (HttpStatus.ok, {'ok': true});
    }

    if (method == 'PUT' && path == '/v1/hotkey') {
      final body = await _readJsonBody(req);
      final combo = body['combo']?.toString() ?? '';
      final status = onUpdateHotkey != null
          ? await onUpdateHotkey!(combo)
          : GlobalHotkeyStatus.unsupported;
      return (HttpStatus.ok, {'ok': true, 'status': status.name});
    }

    if (method == 'POST' && path == '/v1/ui/focus') {
      final delivered = hasUiClient;
      if (delivered) {
        broadcastEvent('focus');
      }
      return (HttpStatus.ok, {'ok': true, 'delivered': delivered});
    }

    if (method == 'POST' && path == '/v1/shutdown') {
      if (onShutdownRequested != null) {
        unawaited(Future<void>.delayed(
          const Duration(milliseconds: 50),
          onShutdownRequested!,
        ));
      }
      return (HttpStatus.ok, {'ok': true});
    }

    return (HttpStatus.notFound, {'ok': false, 'error': 'not_found'});
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    broadcastEvent('daemon_shutdown');
    for (final ws in List<WebSocket>.from(_wsClients)) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _wsClients.clear();
    await _server?.close(force: true);
    _server = null;
    await DaemonEndpointInfo.remove(supportDir);
  }
}
