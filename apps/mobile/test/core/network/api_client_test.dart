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
              .having((e) => e.message, 'message', contains('desactivado')),
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

    test(
      'convierte errores de red en ApiException con mensaje amigable',
      () async {
        final mockClient = MockClient((_) async {
          throw http.ClientException(
            'Connection timed out',
            Uri.parse('http://localhost:8080/api/v1/me'),
          );
        });

        final api = ApiClient(
          baseUrl: 'http://localhost:8080/api/v1',
          httpClient: mockClient,
        );

        expect(
          () => api.fetchMe('token-123'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', isNull)
                .having(
                  (e) => e.message,
                  'message',
                  contains('No se pudo conectar con el servidor'),
                ),
          ),
        );
      },
    );

    test(
      'lanza ApiException si el servidor no responde dentro del timeout',
      () async {
        final mockClient = MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return http.Response('{}', 200);
        });

        final api = ApiClient(
          baseUrl: 'http://localhost:8080/api/v1',
          httpClient: mockClient,
          timeout: const Duration(milliseconds: 100),
        );

        expect(
          () => api.fetchMe('token-123'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              isNull,
            ),
          ),
        );
      },
    );
  });

  group('ApiClient.institutions', () {
    test('crea una institucion y parsea la respuesta', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/institutions');
        expect(request.headers['Authorization'], 'Bearer token-123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code'], 'HOSP-A');
        expect(body['name'], 'Hospital A');
        expect(body.containsKey('offlineWindowHours'), isFalse);
        return http.Response(
          jsonEncode({
            'id': 'inst-1',
            'code': 'HOSP-A',
            'name': 'Hospital A',
            'status': 'ACTIVE',
            'offlineWindowHours': 72,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final json = await api.createInstitution(
        'token-123',
        code: 'HOSP-A',
        name: 'Hospital A',
      );

      expect(json['id'], 'inst-1');
      expect(json['status'], 'ACTIVE');
    });

    test('lista instituciones', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'id': 'inst-1',
              'code': 'HOSP-A',
              'name': 'Hospital A',
              'status': 'ACTIVE',
              'offlineWindowHours': 72,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final list = await api.listInstitutions('token-123');

      expect(list, hasLength(1));
      expect(list.first['code'], 'HOSP-A');
    });

    test('propaga el mensaje de conflicto al crear institucion', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'INSTITUTION_CODE_ALREADY_EXISTS',
            'message': 'Ya existe una institucion con el codigo HOSP-A.',
          }),
          409,
          headers: {'content-type': 'application/json'},
        ),
      );

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      expect(
        () => api.createInstitution(
          'token-123',
          code: 'HOSP-A',
          name: 'Hospital A',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message', contains('codigo')),
        ),
      );
    });
  });

  group('ApiClient.institutionAdmins', () {
    test('crea un admin enviando la contrasena solo en el request', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/users/institution-admins');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'admin@hosp-a.com');
        expect(body['temporaryPassword'], 'Secreto123!');
        expect(body['institutionId'], 'inst-1');
        expect(body['operationId'], 'operation-1');
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'email': 'admin@hosp-a.com',
            'fullName': 'Admin A',
            'institutionId': 'inst-1',
            'roles': ['ADMIN_INSTITUTION'],
            'status': 'ACTIVE',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final json = await api.createInstitutionAdmin(
        'token-123',
        email: 'admin@hosp-a.com',
        fullName: 'Admin A',
        institutionId: 'inst-1',
        temporaryPassword: 'Secreto123!',
        operationId: 'operation-1',
      );

      expect(json['roles'], ['ADMIN_INSTITUTION']);
    });

    test('consulta usuarios de una institucion con query param', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/users');
        expect(request.url.queryParameters['institutionId'], 'inst-1');
        return http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final list = await api.listUsersByInstitution(
        'token-123',
        institutionId: 'inst-1',
      );

      expect(list, isEmpty);
    });

    test('filtra por roles gestionables al listar usuarios', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/users');
        expect(request.url.queryParameters['institutionId'], 'inst-1');
        expect(request.url.queryParameters['roles'], 'VACCINATOR,READ_ONLY');
        return http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final list = await api.listUsersByInstitution(
        'token-123',
        institutionId: 'inst-1',
        roles: const ['VACCINATOR', 'READ_ONLY'],
      );

      expect(list, isEmpty);
    });
  });

  group('ApiClient.vaccinators', () {
    test('crea un vacunador sin institutionId en el body', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/users/vaccinators');
        expect(request.headers['Authorization'], 'Bearer token-123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'vacunador@hosp-a.com');
        expect(body['fullName'], 'Ana Vacunadora');
        expect(body['temporaryPassword'], 'Secreto123!');
        // El scope institucional se resuelve en el servidor, nunca se envia.
        expect(body.containsKey('institutionId'), isFalse);
        // Clave de idempotencia para reintentos seguros.
        expect(body['operationId'], 'operation-1');
        // Perfil ampliado viaja crudo; el backend normaliza y valida.
        expect(body['documentType'], 'CC');
        expect(body['documentNumber'], '12.345.678');
        expect(body['professionCode'], 'ENFERMERO');
        expect(body['phone'], '3001234567');
        // Campos opcionales ausentes se omiten del body.
        expect(body.containsKey('gender'), isFalse);
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'email': 'vacunador@hosp-a.com',
            'fullName': 'Ana Vacunadora',
            'institutionId': 'inst-1',
            'roles': ['VACCINATOR'],
            'status': 'ACTIVE',
            'documentType': 'CC',
            'documentNumber': '12345678',
            'phone': '3001234567',
            'professionCode': 'ENFERMERO',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final json = await api.createVaccinator(
        'token-123',
        email: 'vacunador@hosp-a.com',
        fullName: 'Ana Vacunadora',
        temporaryPassword: 'Secreto123!',
        operationId: 'operation-1',
        documentType: 'CC',
        documentNumber: '12.345.678',
        phone: '3001234567',
        professionCode: 'ENFERMERO',
      );

      expect(json['roles'], ['VACCINATOR']);
      expect(json['institutionId'], 'inst-1');
      expect(json['documentNumber'], '12345678');
    });

    test('propaga el mensaje de permiso denegado al crear vacunador', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'PERMISSION_DENIED',
            'message': 'No tienes permiso para crear vacunadores.',
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      expect(
        () => api.createVaccinator(
          'token-123',
          email: 'vacunador@hosp-a.com',
          fullName: 'Ana Vacunadora',
          temporaryPassword: 'Secreto123!',
          operationId: 'operation-1',
          documentType: 'CC',
          documentNumber: '12345678',
          professionCode: 'ENFERMERO',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', contains('permiso')),
        ),
      );
    });
  });

  group('ApiClient.userUpdates', () {
    test('actualiza el estado del usuario con PUT', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/users/vac-1/status');
        expect(request.headers['Authorization'], 'Bearer token-123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['status'], 'INACTIVE');
        return http.Response(
          jsonEncode({
            'id': 'vac-1',
            'email': 'vacunador@hosp-a.com',
            'fullName': 'Ana Vacunadora',
            'institutionId': 'inst-1',
            'roles': ['VACCINATOR'],
            'status': 'INACTIVE',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final json = await api.updateUserStatus(
        'token-123',
        userId: 'vac-1',
        status: 'INACTIVE',
      );

      expect(json['status'], 'INACTIVE');
    });

    test('reemplaza los roles del usuario con PUT', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/users/vac-1/roles');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['roles'], ['READ_ONLY']);
        return http.Response(
          jsonEncode({
            'id': 'vac-1',
            'email': 'vacunador@hosp-a.com',
            'fullName': 'Ana Vacunadora',
            'institutionId': 'inst-1',
            'roles': ['READ_ONLY'],
            'status': 'ACTIVE',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final json = await api.updateUserRoles(
        'token-123',
        userId: 'vac-1',
        roles: const ['READ_ONLY'],
      );

      expect(json['roles'], ['READ_ONLY']);
    });

    test('propaga error de scope al actualizar usuario', () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'SCOPE_VIOLATION',
            'message': 'No tienes permiso para administrar usuarios de otra institucion.',
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      expect(
        () => api.updateUserStatus(
          'token-123',
          userId: 'vac-1',
          status: 'INACTIVE',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.message,
                'message',
                contains('otra institucion'),
              ),
        ),
      );
    });
  });

  group('ApiClient.institutionConfig', () {
    test('actualiza la ventana offline con PUT', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/institutions/inst-1/config');
        expect(request.headers['Authorization'], 'Bearer token-123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['offlineWindowHours'], 24);
        return http.Response(
          jsonEncode({
            'id': 'inst-1',
            'code': 'HOSP-A',
            'name': 'Hospital A',
            'status': 'ACTIVE',
            'offlineWindowHours': 24,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final json = await api.updateInstitutionConfig(
        'token-123',
        institutionId: 'inst-1',
        offlineWindowHours: 24,
      );

      expect(json['offlineWindowHours'], 24);
    });
  });

  group('ApiClient.availableInstitutionVaccines', () {
    test('lista vacunas globales disponibles para la institucion', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/institutions/inst-1/vaccines/available');
        expect(request.headers['Authorization'], 'Bearer token-123');
        return http.Response(
          jsonEncode([
            {
              'id': 'v2',
              'name': 'Vacuna B',
              'code': 'VAC-2',
              'category': 'PAI',
              'maxDoses': 3,
              'active': true,
              'version': 0,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        httpClient: mockClient,
      );

      final list = await api.listAvailableInstitutionVaccines(
        'token-123',
        'inst-1',
      );

      expect(list, hasLength(1));
      expect(list.first['code'], 'VAC-2');
    });
  });
}
