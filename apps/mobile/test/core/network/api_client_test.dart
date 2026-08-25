import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/core/network/api_exception.dart';

void main() {
  group('ApiClient.fetchMe', () {
    test('envia el Bearer token y parsea el perfil', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/me');
        expect(request.headers['Authorization'], 'Bearer token-123');
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'email': 'vacunador@test.com',
            'fullName': 'Ana Vacunadora',
            'institution': {
              'id': 'inst-1',
              'code': 'INST-1',
              'name': 'Institucion 1',
            },
            'roles': ['VACCINATOR'],
            'permissions': ['PATIENT_READ', 'ATTENTION_CREATE'],
            'offlineWindowHours': 72,
            'lastOnlineValidation': '2026-08-25T03:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final me = await api.fetchMe('token-123');

      expect(me.id, 'user-1');
      expect(me.fullName, 'Ana Vacunadora');
      expect(me.institution.name, 'Institucion 1');
      expect(me.roles, ['VACCINATOR']);
      expect(me.permissions, containsAll(['PATIENT_READ', 'ATTENTION_CREATE']));
      expect(me.offlineWindowHours, 72);
    });

    test('lanza ApiException con el mensaje del servidor', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'USER_NOT_ACTIVE',
            'message': 'El usuario esta desactivado.',
          }),
          401,
        ),
      );

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      expect(
        () => api.fetchMe('token-123'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.message,
                'message',
                contains('desactivado'),
              ),
        ),
      );
    });

    test('lanza ApiException generica si el cuerpo no es JSON', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Internal Server Error', 500),
      );

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      expect(
        () => api.fetchMe('token-123'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}