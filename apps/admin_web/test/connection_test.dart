import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_admin_web/connection/admin_api.dart';
import 'package:tu_vacuna_admin_web/connection/admin_config.dart';

void main() {
  test('exige configuración explícita y transporte seguro', () {
    AdminConfig config(String api, String key) => AdminConfig.fromValues(
      supabaseUrl: 'https://example.supabase.co',
      publishableKey: key,
      apiBaseUrl: api,
    );
    expect(
      () => config('http://example.com', 'sb_publishable_public'),
      throwsFormatException,
    );
    expect(
      () => config('https://example.com', 'sb_secret_private'),
      throwsFormatException,
    );
    expect(() => AdminConfig.fromEnvironment(), throwsFormatException);
    expect(
      config(
        'http://localhost:8080/api/v1',
        'sb_publishable_public',
      ).apiBaseUrl.host,
      'localhost',
    );
  });

  test('consulta perfil con bearer y ruta de API', () async {
    final api = AdminApi(
      Uri.parse('https://api.example.test/api/v1/'),
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://api.example.test/api/v1/me');
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response('{"id":"user"}', 200);
      }),
    );
    addTearDown(api.close);
    expect(await api.fetchMe('token'), {'id': 'user'});
  });

  test('no confunde errores HTTP ni respuestas inválidas con éxito', () async {
    for (final response in [
      http.Response('{}', 401),
      http.Response('[]', 200),
    ]) {
      final api = AdminApi(
        Uri.parse('https://api.example.test'),
        client: MockClient((_) async => response),
      );
      await expectLater(
        api.fetchMe('token'),
        throwsA(isA<AdminApiException>()),
      );
      api.close();
    }
  });

  test('informa timeout y no envía token vacío', () async {
    var calls = 0;
    final api = AdminApi(
      Uri.parse('https://api.example.test'),
      timeout: Duration.zero,
      client: MockClient((_) {
        calls++;
        return Completer<http.Response>().future;
      }),
    );
    addTearDown(api.close);
    await expectLater(api.fetchMe(''), throwsA(isA<AdminApiException>()));
    expect(calls, 0);
    await expectLater(api.fetchMe('token'), throwsA(isA<AdminApiException>()));
  });

  test('rechaza errores y formato inválido en el catálogo', () async {
    for (final response in [
      http.Response('[]', 403),
      http.Response('{}', 200),
    ]) {
      final api = AdminApi(
        Uri.parse('https://api.example.test/api/v1'),
        client: MockClient((_) async => response),
      );
      await expectLater(
        api.fetchCatalog('token', institutionId: 'ips'),
        throwsA(isA<AdminApiException>()),
      );
      api.close();
    }
  });
}
