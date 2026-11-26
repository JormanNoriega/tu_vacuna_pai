import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/features/inventory/data/inventory_event_client.dart';

class _Session extends SessionManager {
  _Session() : super(const FlutterSecureStorage());

  @override
  Future<SessionData?> loadSession() async => SessionData(
    accessToken: 'test-token',
    refreshToken: '',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    lastOnlineValidation: DateTime.now(),
  );
}

class _Client extends http.BaseClient {
  final bytes = StreamController<List<int>>();
  final connected = Completer<http.BaseRequest>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    connected.complete(request);
    return http.StreamedResponse(bytes.stream, 200);
  }
}

class _RejectedClient extends http.BaseClient {
  _RejectedClient(this.status);
  final int status;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), status);
}

void main() {
  test('avisa cuando se rechaza la suscripción por permisos', () async {
    final client = InventoryEventClient(
      baseUrl: 'https://example.test/api/v1',
      sessionManager: _Session(),
      institutionId: 'hospital',
      createClient: () => _RejectedClient(403),
    );
    final status = client.statuses.first;
    client.start();
    expect(await status, InventoryConnectionStatus.unauthorized);
    client.dispose();
  });

  test('renueva una vez tras 401 y comunica la reconexión', () async {
    var attempts = 0;
    var renewals = 0;
    final success = _Client();
    final client = InventoryEventClient(
      baseUrl: 'https://example.test/api/v1',
      sessionManager: _Session(),
      institutionId: 'hospital',
      retryDelay: Duration.zero,
      renewSession: () async { renewals++; },
      createClient: () => attempts++ == 0 ? _RejectedClient(401) : success,
    );
    final statuses = <InventoryConnectionStatus>[];
    final sub = client.statuses.listen(statuses.add);
    client.start();
    await success.connected.future;
    success.bytes.add(utf8.encode('event: ready\ndata: ok\n\n'));
    await client.statuses.firstWhere((s) => s == InventoryConnectionStatus.connected);
    expect(renewals, 1);
    expect(statuses, [InventoryConnectionStatus.unavailable, InventoryConnectionStatus.connected]);
    await sub.cancel();
    client.dispose();
    await success.bytes.close();
  });

  test('recibe un evento SSE y autentica sin poner el token en la URL', () async {
    final httpClient = _Client();
    final client = InventoryEventClient(
      baseUrl: 'https://example.test/api/v1',
      sessionManager: _Session(),
      institutionId: 'hospital',
      createClient: () => httpClient,
    );
    final received = client.events.first;
    client.start();
    final request = await httpClient.connected.future;
    expect(request.headers['Authorization'], 'Bearer test-token');
    expect(request.url.toString(), 'https://example.test/api/v1/institutions/hospital/inventory/events');
    httpClient.bytes.add(utf8.encode(
      'event: ready\ndata: ok\n\nevent: inventory-change\n'
      'data: {"type":"DELIVERY_CREATED","assignmentId":"123"}\n\n',
    ));
    expect(await received, containsPair('assignmentId', '123'));
    client.dispose();
    await httpClient.bytes.close();
  });
}
