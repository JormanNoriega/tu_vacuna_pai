import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_admin_web/connection/admin_api.dart';

void main() {
  test('consulta inventario con institución y autorización', () async {
    final api = AdminApi(Uri.parse('https://example.test/api/v1'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/institutions/ips/inventory/assignments');
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response('[{"vaccineName":"BCG","vialCount":3}]', 200);
      }));
    addTearDown(api.close);
    final items = await api.fetchInventoryList('token',
      institutionId: 'ips', resource: 'assignments');
    expect(items.single['vialCount'], 3);
  });

  test('rechaza rutas no autorizadas y errores del servicio', () async {
    var calls = 0;
    final api = AdminApi(Uri.parse('https://example.test/api/v1'),
      client: MockClient((_) async {
        calls++;
        return http.Response('no disponible', 404);
      }));
    addTearDown(api.close);
    await expectLater(api.fetchInventoryList('token', institutionId: 'ips',
      resource: 'entries'), throwsA(isA<AdminApiException>()));
    expect(calls, 0);
    await expectLater(api.fetchInventoryList('token', institutionId: 'ips',
      resource: 'campaigns'), throwsA(isA<AdminApiException>()));
    expect(calls, 1);
  });
}
