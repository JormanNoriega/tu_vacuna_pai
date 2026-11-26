import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/features/geography/geography_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'test-token'});
  });

  test(
    'demostración usa solo datos sintéticos, incluso al actualizar',
    () async {
      var requests = 0;
      final controller = GeographyController(
        api: ApiClient(
          baseUrl: 'https://example.test/api/v1',
          httpClient: MockClient((_) async {
            requests++;
            return http.Response('{}', 500);
          }),
        ),
        sessionManager: SessionManager(const FlutterSecureStorage()),
        synthetic: true,
      );
      await controller.load(7);
      final count = controller.data!.cells.first.count;
      await controller.load(90, refresh: true);
      expect(controller.data!.cells.first.count, greaterThan(count));
      expect(requests, 0);
      expect(controller.error, isNull);
    },
  );

  test('informa si el servicio geográfico no está disponible', () async {
    final controller = GeographyController(
      api: ApiClient(
        baseUrl: 'https://example.test/api/v1',
        httpClient: MockClient((_) async => http.Response('{}', 404)),
      ),
      sessionManager: SessionManager(const FlutterSecureStorage()),
    );
    await controller.load(30);
    expect(
      controller.error,
      'El servicio geográfico no está disponible en este entorno.',
    );
  });

  test(
    'reutiliza datos en memoria por periodo y actualizar consulta de nuevo',
    () async {
      final requests = <Uri>[];
      final api = ApiClient(
        baseUrl: 'https://example.test/api/v1',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response(
            jsonEncode({
              'generatedAt': '2026-11-25T00:00:00Z',
              'cells': [
                {'latitude': 4.6, 'longitude': -74.1, 'count': 5},
              ],
            }),
            200,
          );
        }),
      );
      final controller = GeographyController(
        api: api,
        sessionManager: SessionManager(const FlutterSecureStorage()),
      );
      await controller.load(30);
      expect(controller.data!.cells.single.count, 5);
      await controller.load(30);
      expect(requests, hasLength(1));
      await controller.load(7);
      expect(requests.last.queryParameters['days'], '7');
      await controller.load(30, refresh: true);
      expect(requests, hasLength(3));
      controller.clearSession();
      expect(controller.data, isNull);
      await controller.load(30);
      expect(requests, hasLength(4));
    },
  );

  test(
    'una respuesta anterior al cierre de sesión no repuebla la caché',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final controller = GeographyController(
        api: ApiClient(
          baseUrl: 'https://example.test/api/v1',
          httpClient: MockClient((_) {
            started.complete();
            return response.future;
          }),
        ),
        sessionManager: SessionManager(const FlutterSecureStorage()),
      );
      final pending = controller.load(30);
      await started.future;
      controller.clearSession();
      response.complete(
        http.Response('{"generatedAt":"2026-11-25T00:00:00Z","cells":[]}', 200),
      );
      await pending;
      expect(controller.data, isNull);
      expect(controller.loading, isFalse);
    },
  );
}
