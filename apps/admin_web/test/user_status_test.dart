import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_admin_web/connection/admin_api.dart';

void main() {
  test('envía cambio de estado y exige confirmación del servidor', () async {
    final api = AdminApi(Uri.parse('https://example.test/api/v1'),
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/users/u/status');
        expect(request.headers['Authorization'], 'Bearer token');
        expect(jsonDecode(request.body), {'status': 'INACTIVE'});
        return http.Response('{"id":"u","status":"INACTIVE"}', 200);
      }));
    addTearDown(api.close);
    final result = await api.updateUserStatus('token', userId: 'u', status: 'INACTIVE');
    expect(result['status'], 'INACTIVE');
  });

  test('rechaza una respuesta que no confirma el estado', () async {
    final api = AdminApi(Uri.parse('https://example.test/api/v1'),
      client: MockClient((_) async => http.Response('{"id":"u","status":"ACTIVE"}', 200)));
    addTearDown(api.close);
    await expectLater(api.updateUserStatus('token', userId: 'u', status: 'INACTIVE'),
      throwsA(isA<AdminApiException>()));
  });
}
