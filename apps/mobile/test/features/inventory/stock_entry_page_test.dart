import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/inventory_controller.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/stock_entry_page.dart';

class FakeController extends InventoryController {
  FakeController()
    : super(
        sessionManager: SessionManager(const FlutterSecureStorage()),
        api: ApiClient(baseUrl: 'http://localhost'),
      );
  String? resource;
  Map<String, dynamic>? body;
  @override
  Future<bool> post(
    String institution,
    String resource,
    Map<String, dynamic> body,
  ) async {
    this.resource = resource;
    this.body = body;
    return true;
  }
}

void main() {
  testWidgets('registra una entrada para un lote existente', (tester) async {
    final controller = FakeController();
    await tester.pumpWidget(
      MaterialApp(
        home: StockEntryPage(
          controller: controller,
          institutionId: 'institucion',
          vaccineId: 'vacuna',
          vaccineName: 'Vacuna',
          lots: const [
            {
              'id': 'lote',
              'lotNumber': 'ABC',
              'manufacturer': 'F',
              'expiresOn': '2028-01-01',
            },
          ],
        ),
      ),
    );
    await tester.tap(find.text('Registrar lote nuevo'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ABC').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Frascos completos recibidos'),
      '5',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo o soporte'),
      'Conteo físico',
    );
    await tester.ensureVisible(find.text('Registrar entrada'));
    await tester.tap(find.text('Registrar entrada'));
    await tester.pumpAndSettle();
    expect(controller.resource, 'entries');
    expect(controller.body!['lotId'], 'lote');
    expect(controller.body!['vials'], 5);
  });
}
