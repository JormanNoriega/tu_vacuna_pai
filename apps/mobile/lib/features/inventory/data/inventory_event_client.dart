import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/auth/session_manager.dart';

enum InventoryConnectionStatus { connected, unavailable, unauthorized }

/// Canal efímero: la fuente de verdad continúa siendo la API de inventario.
class InventoryEventClient {
  InventoryEventClient({
    required this.baseUrl,
    required this.sessionManager,
    required this.institutionId,
    this.renewSession,
    this.retryDelay = const Duration(seconds: 5),
    http.Client Function()? createClient,
  }) : _createClient = createClient ?? http.Client.new;

  final String baseUrl;
  final SessionManager sessionManager;
  final String institutionId;
  final Future<void> Function()? renewSession;
  final Duration retryDelay;
  final http.Client Function() _createClient;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _statuses = StreamController<InventoryConnectionStatus>.broadcast();
  http.Client? _client;
  Completer<void>? _abort;
  Timer? _retry;
  bool _closed = false;
  bool _refreshedAfterUnauthorized = false;
  InventoryConnectionStatus? _lastStatus;

  Stream<Map<String, dynamic>> get events => _events.stream;
  Stream<InventoryConnectionStatus> get statuses => _statuses.stream;

  void _setStatus(InventoryConnectionStatus value) {
    if (_closed || _lastStatus == value) return;
    _lastStatus = value;
    _statuses.add(value);
  }

  void start() => unawaited(_connect());

  Future<void> _connect() async {
    if (_closed) return;
    var retry = true;
    try {
      var session = await sessionManager.loadSession();
      if (_closed) return;
      if (session == null) {
        retry = false;
        _setStatus(InventoryConnectionStatus.unauthorized);
        return;
      }
      if (!session.expiresAt.isAfter(
            DateTime.now().add(const Duration(minutes: 1)),
          ) &&
          renewSession != null) {
        await renewSession!();
        session = await sessionManager.loadSession();
        if (session == null || _closed) return;
      }
      final client = _createClient();
      _client = client;
      final abort = Completer<void>();
      _abort = abort;
      final uri = Uri.parse(
        '$baseUrl/institutions/${Uri.encodeComponent(institutionId)}/inventory/events',
      );
      final request = http.AbortableRequest('GET', uri, abortTrigger: abort.future)
        ..headers['Authorization'] = 'Bearer ${session.accessToken}'
        ..headers['Accept'] = 'text/event-stream, application/json';
      final response = await client.send(request);
      if (_closed) return;
      if (response.statusCode == 401 &&
          renewSession != null && !_refreshedAfterUnauthorized) {
        _refreshedAfterUnauthorized = true;
        _setStatus(InventoryConnectionStatus.unavailable);
        await renewSession!();
        return;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        retry = false;
        _setStatus(InventoryConnectionStatus.unauthorized);
        return;
      }
      if (response.statusCode != 200) throw StateError('Canal no disponible');
      String? eventName;
      final data = <String>[];
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (_closed) break;
        if (line.isEmpty) {
          if (eventName == 'ready') {
            _refreshedAfterUnauthorized = false;
            _setStatus(InventoryConnectionStatus.connected);
          }
          if (eventName == 'inventory-change' && data.isNotEmpty) {
            final value = jsonDecode(data.join('\n'));
            if (value is Map<String, dynamic>) _events.add(value);
          }
          eventName = null;
          data.clear();
        } else if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data.add(line.substring(5).trimLeft());
        }
      }
      if (!_closed) _setStatus(InventoryConnectionStatus.unavailable);
    } catch (_) {
      _setStatus(InventoryConnectionStatus.unavailable);
    } finally {
      _client?.close();
      _client = null;
      _abort = null;
      if (!_closed && retry) {
        _retry = Timer(retryDelay, _connect);
      }
    }
  }

  void dispose() {
    _closed = true;
    _retry?.cancel();
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _client?.close();
    unawaited(_events.close());
    unawaited(_statuses.close());
  }
}
