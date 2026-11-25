import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_admin_web/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_admin_web/connection/admin_api.dart';
import 'package:tu_vacuna_admin_web/connection/admin_session.dart';

class _Auth implements AuthGateway {
  @override
  Future<SessionToken> signIn(String email, String password) async =>
      SessionToken('token', DateTime.now().add(const Duration(hours: 1)));
  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('la base web informa que aún no está disponible', (tester) async {
    await tester.pumpWidget(const AdminWebApp());

    expect(find.text('Aplicación en preparación'), findsOneWidget);
    expect(find.textContaining('No permite iniciar sesión'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('permite validar sesión sin habilitar módulos', (tester) async {
    final session = AdminSession(
      _Auth(),
      AdminApi(
        Uri.parse('https://example.test'),
        client: MockClient(
          (_) async => http.Response(
            '{"id":"u","fullName":"Ana","roles":["SUPER_ADMIN"],"permissions":[],"institution":{"id":"i"}}',
            200,
          ),
        ),
      ),
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(AdminWebApp(session: session));
    await tester.enterText(find.byType(TextField).first, 'a@example.test');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido, Ana'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
  });
}
