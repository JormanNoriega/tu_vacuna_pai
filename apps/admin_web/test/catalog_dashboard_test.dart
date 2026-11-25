import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
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
  for (final global in [true, false]) {
    testWidgets(
      'catálogo ${global ? "global" : "institucional"} consulta Spring',
      (tester) async {
        final paths = <String>[];
        final session = AdminSession(
          _Auth(),
          AdminApi(
            Uri.parse('https://example.test/api/v1'),
            client: MockClient((request) async {
              paths.add(request.url.path);
              expect(request.headers['Authorization'], 'Bearer token');
              if (request.url.path.endsWith('/me')) {
                return http.Response(
                  global
                      ? '{"id":"u","fullName":"Ana","roles":["SUPER_ADMIN"],"permissions":["CATALOG_GLOBAL_READ","INVENTORY_READ"],"institution":{"id":"ips"}}'
                      : '{"id":"u","fullName":"Ana","roles":["ADMIN_INSTITUTION"],"permissions":["CATALOG_CONFIG_READ","INVENTORY_READ"],"institution":{"id":"ips"}}',
                  200,
                );
              }
              if (request.url.path.endsWith('/metrics/summary')) {
                return http.Response(
                  '{"patientsAttended":1,"dosesApplied":2}',
                  200,
                );
              }
              if (request.url.path.endsWith('/inventory/lots')) {
                return http.Response(
                  '[{"id":"lot","vaccineName":"BCG","manufacturer":"PAI",'
                  '"lotNumber":"LOTE-2026","expiresOn":"2027-01-01",'
                  '"availableVials":7}]',
                  200,
                );
              }
              return http.Response(
                global
                    ? '[{"name":"BCG","code":"BCG","active":true}]'
                    : '[{"name":"BCG","code":"BCG","enabled":false}]',
                200,
              );
            }),
          ),
        );
        addTearDown(session.dispose);
        await tester.pumpWidget(AdminWebApp(session: session));
        await session.signIn('email', 'password');
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.inventory_2_outlined));
        await tester.pumpAndSettle();
        expect(
          paths,
          contains(
            global
                ? '/api/v1/catalogs/vaccines'
                : '/api/v1/institutions/ips/vaccines',
          ),
        );
        expect(find.text('BCG'), findsWidgets);
        expect(find.text('LOTE-2026'), findsOneWidget);
        expect(find.text('7 frascos disponibles'), findsOneWidget);
        expect(find.text(global ? 'Activa' : 'Inactiva'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'no existe');
        await tester.pumpAndSettle();
        expect(find.text('No hay vacunas para mostrar.'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        final statusFilter = find.text(global ? 'Inactivas' : 'Activas').last;
        await tester.ensureVisible(statusFilter);
        await tester.tap(statusFilter);
        await tester.pumpAndSettle();
        expect(find.text('No hay vacunas para mostrar.'), findsOneWidget);
        await session.signOut();
        await tester.pump();
      },
    );
  }
}
