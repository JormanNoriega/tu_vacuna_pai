import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_admin_web/connection/admin_api.dart';
import 'package:tu_vacuna_admin_web/connection/admin_session.dart';
import 'package:tu_vacuna_admin_web/dashboard/history_view.dart';

class _Auth implements AuthGateway {
  @override
  Future<SessionToken> signIn(String email, String password) async =>
      SessionToken('token', DateTime.now().add(const Duration(hours: 1)));

  @override
  Future<void> signOut() async {}
}

AdminSession _session() => AdminSession(
  _Auth(),
  AdminApi(
    Uri.parse('https://example.test/api/v1'),
    client: MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/me')) {
        return http.Response(
          '{"id":"u","fullName":"Ana","roles":["ADMIN_INSTITUTION"],'
          '"permissions":["ATTENTION_READ","PATIENT_READ"],'
          '"institution":{"id":"ips","name":"Centro"}}',
          200,
        );
      }
      if (path.endsWith('/attention-history')) {
        return http.Response('{"items":[],"hasNext":false}', 200);
      }
      if (path.endsWith('/patients')) {
        expect(request.url.queryParameters, {
          'documentType': 'CC',
          'documentNumber': '12345',
        });
        return http.Response(
          '[{"id":"p-1","firstName":"Ana","lastName":"Pérez",'
          '"documentType":"CC","documentNumber":"12345",'
          '"birthDate":"2010-01-02","sex":"F","status":"ACTIVE",'
          '"vaccinationCardType":"PAI"}]',
          200,
        );
      }
      if (path.endsWith('/attentions')) {
        expect(request.url.queryParameters['patientId'], 'p-1');
        return http.Response(
          '[{"id":"a-1","consecutive":22,"attentionDate":"2026-03-01",'
          '"status":"COMPLETED","doses":[{"vaccineNameSnapshot":"BCG",'
          '"doseLabelSnapshot":"Única","lotNumber":"LOTE-1",'
          '"status":"APPLIED"}]}]',
          200,
        );
      }
      if (path.endsWith('/reports/registro-diario/summary')) {
        return http.Response(
          '{"patientsCount":2,"dosesCount":4,"vaccineTypesCount":3}',
          200,
        );
      }
      return http.Response('No encontrado', 404);
    }),
  ),
);

void main() {
  testWidgets('expediente busca pacientes y muestra sus atenciones reales', (
    tester,
  ) async {
    final session = _session();
    addTearDown(() async {
      await session.signOut();
      session.dispose();
    });
    await session.signIn('ana@example.test', 'secret');

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryView(session: session, initialTab: 'expediente'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Búsqueda y expediente clínico'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12345');
    await tester.tap(find.text('Buscar paciente'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Pérez'), findsWidgets);

    await tester.tap(find.text('Ana Pérez').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Atención 22'), findsOneWidget);
    await tester.tap(find.textContaining('Atención 22'));
    await tester.pumpAndSettle();
    expect(find.text('BCG'), findsOneWidget);
    expect(find.textContaining('LOTE-1'), findsOneWidget);
  });

  testWidgets('pestaña de reportes presenta totales de Spring', (tester) async {
    final session = _session();
    addTearDown(() async {
      await session.signOut();
      session.dispose();
    });
    await session.signIn('ana@example.test', 'secret');
    await tester.pumpWidget(MaterialApp(home: HistoryView(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reportes PAI'));
    await tester.pumpAndSettle();
    expect(find.text('Centro de reportes PAI'), findsOneWidget);
    expect(find.text('Pacientes con dosis'), findsOneWidget);
    expect(find.text('Dosis registradas'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Generar y descargar'), findsOneWidget);
  });
}
