import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_admin_web/connection/admin_api.dart';
import 'package:tu_vacuna_admin_web/connection/admin_session.dart';
import 'package:tu_vacuna_admin_web/main.dart';

class _Auth implements AuthGateway {
  @override
  Future<SessionToken> signIn(String email, String password) async =>
      SessionToken('token', DateTime.now().add(const Duration(hours: 1)));

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('personal consulta la institución y pagina sin habilitar escrituras',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final session = AdminSession(
      _Auth(),
      AdminApi(
        Uri.parse('https://example.test/api/v1'),
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/me')) {
            return http.Response(jsonEncode({
              'id': 'u',
              'fullName': 'Ana',
              'roles': ['ADMIN_INSTITUTION'],
              'permissions': ['USER_MANAGE'],
              'institution': {'id': 'ips', 'name': 'Centro'},
            }), 200);
          }
          if (request.url.path.endsWith('/metrics/summary')) {
            return http.Response('{"patientsAttended":0,"dosesApplied":0}', 200);
          }
          return http.Response(jsonEncode(List.generate(11, (index) => {
            'id': '$index',
            'email': 'persona$index@example.test',
            'fullName': 'Persona $index',
            'institutionId': 'ips',
            'roles': ['VACCINATOR'],
            'status': 'ACTIVE',
          })), 200);
        }),
      ),
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(AdminWebApp(session: session));
    await session.signIn('email', 'password');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.admin_panel_settings_outlined));
    await tester.pumpAndSettle();
    final request = requests.last;
    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/users');
    expect(request.url.queryParameters['institutionId'], 'ips');
    expect(request.url.queryParameters['roles'], 'VACCINATOR,READ_ONLY');
    expect(request.headers['Authorization'], 'Bearer token');
    expect(find.text('Persona 0'), findsOneWidget);
    expect(find.text('Página 1 de 2'), findsOneWidget);
    final create = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Registrar Nuevo Vacunador'),
    );
    expect(create.onPressed, isNull);
    await session.signOut();
    await tester.pump();
    expect(find.text('Persona 0'), findsNothing);
  });

  test('sin permiso no se consulta personal', () async {
    var calls = 0;
    final session = AdminSession(
      _Auth(),
      AdminApi(Uri.parse('https://example.test/api/v1'),
          client: MockClient((request) async {
        calls++;
        return http.Response('{"id":"u","fullName":"Ana","roles":["ADMIN_INSTITUTION"],'
            '"permissions":[],"institution":{"id":"ips"}}', 200);
      })),
    );
    addTearDown(session.dispose);
    await session.signIn('email', 'password');
    expect(() => session.loadUsers(), throwsA(isA<AdminApiException>()));
    expect(calls, 1);
  });
}
