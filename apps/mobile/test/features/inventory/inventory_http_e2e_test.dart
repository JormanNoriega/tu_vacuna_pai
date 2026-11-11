import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/inventory_controller.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/inventory_page.dart';

class TestSession extends SessionManager {
  TestSession() : super(const FlutterSecureStorage());
  String token =
      Platform.environment['INVENTORY_E2E_ADMIN_TOKEN'] ?? 'test-admin';
  @override
  Future<SessionData?> loadSession() async => SessionData(
    accessToken: token,
    refreshToken: '',
    expiresAt: DateTime(2099),
    lastOnlineValidation: DateTime.now(),
  );
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 600; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  fail(
    'No apareció: $finder. Textos: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().toList()}',
  );
}

void main() {
  final url = Platform.environment['INVENTORY_E2E_URL'];
  final institution =
      Platform.environment['INVENTORY_E2E_INSTITUTION'] ??
      '11111111-1111-4111-8111-111111111111';
  final vaccineName =
      Platform.environment['INVENTORY_E2E_VACCINE_NAME'] ?? 'Vacuna prueba';
  testWidgets('inventario móvil contra API habilitada y base efímera', (
    tester,
  ) async {
    // La prueba de widgets reemplaza HTTP por defecto; este cliente usa solo el servidor local efímero.
    HttpOverrides.global = null;
    final session = TestSession();
    final client = IOClient(HttpClient());
    final controller = InventoryController(
      sessionManager: session,
      api: ApiClient(baseUrl: url!, httpClient: client),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          controller: controller,
          institutionId: institution,
          admin: true,
          online: true,
          canWrite: true,
        ),
      ),
    );
    await waitFor(tester, find.text('Aún no hay lotes registrados.'));
    await tester.tap(find.text('Crear lote'));
    await tester.pump();
    await waitFor(tester, find.text('Vacuna'));
    await tester.tap(find.text('Vacuna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(vaccineName).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fabricante'),
      'Prueba móvil',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Número de lote'),
      'E2E-1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dosis nominales por frasco'),
      '10',
    );
    await tester.ensureVisible(find.text('Seleccionar vencimiento'));
    await tester.tap(find.text('Seleccionar vencimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear lote'));
    await tester.tap(find.text('Crear lote'));
    await waitFor(tester, find.text('$vaccineName · E2E-1'));
    await waitFor(tester, find.byTooltip('Acciones del lote'));
    await tester.tap(find.byTooltip('Acciones del lote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar entrada'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Frascos completos'),
      '10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo o soporte'),
      'Conteo de prueba',
    );
    await tester.tap(find.text('Registrar'));
    await waitFor(tester, find.textContaining('10 frascos en depósito'));
    await tester.tap(find.byTooltip('Acciones del lote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregar frascos'));
    await tester.pump();
    await waitFor(tester, find.text('Vacunador'));
    await tester.tap(find.text('Jornada (opcional)'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Jornada prueba ·').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vacunador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vacunador prueba').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Frascos completos'),
      '3',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo o soporte'),
      'Entrega prueba',
    );
    await tester.ensureVisible(find.text('Registrar entrega'));
    await tester.tap(find.text('Registrar entrega'));
    await waitFor(tester, find.textContaining('7 frascos en depósito'));
    await tester.ensureVisible(find.text('Finalizar'));
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar').last);
    await waitFor(tester, find.textContaining('Finalizada'));
    session.token =
        Platform.environment['INVENTORY_E2E_VACCINATOR_TOKEN'] ??
        'test-vaccinator';
    await tester.pumpWidget(const SizedBox.shrink());
    controller.clearSession();
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          controller: controller,
          institutionId: institution,
          admin: false,
          online: true,
          canWrite: false,
        ),
      ),
    );
    await waitFor(tester, find.text('Recibir'));
    await tester.tap(find.text('Recibir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await waitFor(tester, find.textContaining('Recibida'));
    await tester.ensureVisible(find.text('Declarar'));
    await tester.tap(find.text('Declarar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tipo de registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devolución pendiente').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Frascos cerrados'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo o detalle'),
      'Sobrante contado',
    );
    await tester.ensureVisible(find.text('Registrar'));
    await tester.tap(find.text('Registrar'));
    await waitFor(
      tester,
      find.textContaining('Devolución pendiente de recepción'),
    );
    await tester.ensureVisible(find.text('Declarar'));
    await tester.tap(find.text('Declarar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tipo de registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pérdida o extravío').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Frascos cerrados'),
      '1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo o detalle'),
      'Novedad de prueba',
    );
    await tester.ensureVisible(find.text('Registrar'));
    await tester.tap(find.text('Registrar'));
    await waitFor(tester, find.textContaining('Pérdida declarada'));
    session.token =
        Platform.environment['INVENTORY_E2E_ADMIN_TOKEN'] ?? 'test-admin';
    await tester.pumpWidget(const SizedBox.shrink());
    controller.clearSession();
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          controller: controller,
          institutionId: institution,
          admin: true,
          online: true,
          canWrite: true,
        ),
      ),
    );
    await waitFor(tester, find.textContaining('7 frascos en depósito'));
    await tester.scrollUntilVisible(
      find.text('Revisar'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Destino tras revisión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reincorporar al depósito').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Resultado de la revisión'),
      'Revisión física de prueba',
    );
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(find.text('Confirmar recepción'));
    await tester.tap(find.text('Confirmar recepción'));
    await waitFor(tester, find.textContaining('9 frascos en depósito'));
    await tester.scrollUntilVisible(
      find.textContaining('Recibida y reincorporada'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Recibida y reincorporada'), findsOneWidget);
    client.close();
  }, skip: url == null);
}
