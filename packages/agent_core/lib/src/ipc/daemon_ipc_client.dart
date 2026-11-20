import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/support_paths.dart';
import 'daemon_ipc_protocol.dart';

/// Cliente HTTP + WebSocket em Dart puro para comunicação do `cms_app` com o
/// `hub_agent_daemon` sobre loopback autenticado.
class DaemonIpcClient {
  final DaemonEndpointInfo endpoint;
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2);

  WebSocket? _ws;
  StreamSubscription<dynamic>? _wsSub;
  final _eventsCtl = StreamController<Map<String, dynamic>>.broadcast();
  bool _disposed = false;

  DaemonIpcClient(this.endpoint);

  Stream<Map<String, dynamic>> get events => _eventsCtl.stream;
  bool get isWebSocketConnected => _ws != null;

  /// Tenta descobrir um daemon saudável já em execução.
  static Future<DaemonIpcClient?> discoverHealthy(Directory supportDir) async {
    final info = await DaemonEndpointInfo.read(supportDir);
    if (info == null) return null;
    final client = DaemonIpcClient(info);
    final alive = await client.ping();
    if (alive) return client;
    await client.dispose();
    return null;
  }

  /// Garante que o `hub_agent_daemon` esteja rodando; se não estiver e o binário
  /// irmão existir, inicia-o em segundo plano (`detached`) e aguarda ficar pronto.
  static Future<DaemonIpcClient?> ensureConnected(
    Directory supportDir, {
    String? daemonBinaryPath,
    Duration waitTimeout = const Duration(seconds: 4),
  }) async {
    final existing = await discoverHealthy(supportDir);
    if (existing != null) return existing;

    final bin =
        daemonBinaryPath ?? SupportPaths.resolveSiblingBinary('hub_agent_daemon');
    if (bin == null) return null;

    try {
      await Process.start(
        bin,
        ['--data-dir', supportDir.path],
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
    } catch (e) {
      stderr.writeln('DaemonIpcClient: falha ao iniciar $bin: $e');
      return null;
    }

    final deadline = DateTime.now().add(waitTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final client = await discoverHealthy(supportDir);
      if (client != null) return client;
    }
    return null;
  }

  Future<bool> ping() async {
    try {
      final res = await get('/v1/health', timeout: const Duration(milliseconds: 800));
      return res?['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> connectEvents() async {
    if (_disposed || _ws != null) return;
    final uri = Uri(
      scheme: 'ws',
      host: '127.0.0.1',
      port: endpoint.port,
      path: '/v1/events',
      queryParameters: {'token': endpoint.token},
    );
    try {
      _ws = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 3));
      _wsSub = _ws!.listen(
        (raw) {
          if (raw is! String) return;
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map && !_eventsCtl.isClosed) {
              _eventsCtl.add(decoded.cast<String, dynamic>());
            }
          } catch (_) {}
        },
        onDone: () {
          _ws = null;
        },
        onError: (_) {
          _ws = null;
        },
      );
    } catch (e) {
      stderr.writeln('DaemonIpcClient WS falhou: $e');
      _ws = null;
    }
  }

  Future<Map<String, dynamic>?> get(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 3),
  }) =>
      _send('GET', path, query: query, timeout: timeout);

  Future<Map<String, dynamic>?> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _send('POST', path, body: body, query: query, timeout: timeout);

  Future<Map<String, dynamic>?> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _send('PUT', path, body: body, query: query, timeout: timeout);

  Future<Map<String, dynamic>?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_disposed) return null;
    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: endpoint.port,
      path: path,
      queryParameters: query,
    );
    try {
      final req = await _http.openUrl(method, uri).timeout(timeout);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${endpoint.token}');
      req.headers.contentType = ContentType.json;
      if (body != null) {
        req.write(jsonEncode(body));
      }
      final res = await req.close().timeout(timeout);
      final text = await utf8.decoder.bind(res).join().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      if (text.trim().isEmpty) return const {'ok': true};
      final decoded = jsonDecode(text);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
    _http.close(force: true);
    await _eventsCtl.close();
  }
}
