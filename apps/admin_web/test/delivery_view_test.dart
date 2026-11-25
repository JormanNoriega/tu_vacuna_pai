import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_admin_web/connection/admin_api.dart';
import 'package:tu_vacuna_admin_web/connection/admin_session.dart';
import 'package:tu_vacuna_admin_web/dashboard/delivery_view.dart';

class _Auth implements AuthGateway {
  @override
  Future<SessionToken> signIn(String email, String password) async =>
      SessionToken('token', DateTime.now().add(const Duration(hours: 1)));

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets(
    'entregas muestra registros de API y permite filtrar sin escrituras',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      final session = AdminSession(
        _Auth(),
        AdminApi(
          Uri.parse('https://example.test/api/v1'),
          client: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.endsWith('/me')) {
              return http.Response(
                '{"id":"u","fullName":"Ana","roles":["ADMIN_INSTITUTION"],'
                '"permissions":["INVENTORY_READ"],'
                '"institution":{"id":"ips","name":"Centro"}}',
                200,
              );
            }
            return http.Response(
              '[{"id":"a","vaccineName":"BCG","lotNumber":"LOTE-1",'
              '"vialCount":3,"status":"DISPATCHED"},'
              '{"id":"b","vaccineName":"Influenza","lotNumber":"LOTE-2",'
              '"vialCount":5,"status":"RECEIVED"}]',
              200,
            );
          }),
        ),
      );
      addTearDown(session.dispose);
      await session.signIn('ana@example.test', 'password');

      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryView(
            session: session,
            section: 'entregas',
            onSelect: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(paths, contains('/api/v1/institutions/ips/inventory/assignments'));
      expect(find.text('BCG'), findsWidgets);
      expect(find.text('Influenza'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'BCG');
      await tester.pumpAndSettle();
      expect(find.text('BCG'), findsWidgets);
      expect(find.text('Influenza'), findsNothing);
      expect(find.textContaining('solo lectura'), findsOneWidget);
      await session.signOut();
    },
  );
}
