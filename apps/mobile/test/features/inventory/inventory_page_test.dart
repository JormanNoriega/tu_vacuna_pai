import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/session_manager.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/inventory_controller.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/inventory_form_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/campaign_form_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/custody_event_form_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/inventory_page.dart';

class FakeInventoryController extends InventoryController {
  FakeInventoryController()
    : super(
        sessionManager: SessionManager(const FlutterSecureStorage()),
        api: ApiClient(baseUrl: 'http://localhost'),
      );
  int loads = 0;
  String? postedResource;
  Map<String, dynamic>? postedBody;
  final postedBodies = <Map<String, dynamic>>[];
  bool shouldFail = false;

  @override
  Future<void> loadFormOptions(
    String institution, {
    required bool isLot,
  }) async {
    vaccines = [
      {'vaccineId': 'vacuna-1', 'name': 'Pentavalente', 'enabled': true},
    ];
    vaccinators = [
      {
        'id': 'vacunador-1',
        'fullName': 'Ana Pérez',
        'status': 'ACTIVE',
        'roles': ['VACCINATOR'],
      },
    ];
    clearError();
    notifyListeners();
  }

  @override
  Future<void> load(String institution, {required bool admin}) async {
    loads++;
    if (admin) {
      lots = [
        {
          'id': 'lote-1',
          'vaccineName': 'Vacuna',
          'lotNumber': 'L1',
          'manufacturer': 'Fabricante',
          'expiresOn': '2028-01-01',
          'availableVials': 5,
        },
      ];
    }
    assignments = [
      {
        'id': 'entrega-1',
        'vaccineName': 'Vacuna',
        'lotNumber': 'L1',
        'vialCount': 3,
        'status': 'IN_TRANSIT',
      },
    ];
    notifyListeners();
  }

  @override
  Future<bool> post(
    String institution,
    String resource,
    Map<String, dynamic> body,
  ) async {
    postedResource = resource;
    postedBody = body;
    postedBodies.add(Map.of(body));
    if (shouldFail) {
      setError('No se pudo confirmar la operación.');
      return false;
    }
    return true;
  }
}

void main() {
  testWidgets(
    'una novedad permite declarar pérdida sin confirmar una devolución',
    (tester) async {
      final controller = FakeInventoryController();
      await tester.pumpWidget(
        MaterialApp(
          home: CustodyEventFormPage(
            controller: controller,
            institutionId: 'i',
            confirmation: false,
            record: {
              'id': 'entrega-1',
              'vaccineName': 'Vacuna',
              'lotNumber': 'L1',
              'vialCount': 3,
            },
          ),
        ),
      );
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
        'Extravío reportado',
      );
      await tester.ensureVisible(find.text('Registrar'));
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(controller.postedResource, 'custody-events');
      expect(controller.postedBody!['kind'], 'LOST');
      expect(controller.postedBody!.containsKey('disposition'), isFalse);
    },
  );
  testWidgets(
    'devolución exige conteo, motivo y conserva identidad al reintentar',
    (tester) async {
      final controller = FakeInventoryController()..shouldFail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: CustodyEventFormPage(
            controller: controller,
            institutionId: 'i',
            confirmation: false,
            record: {
              'id': 'entrega-1',
              'vaccineName': 'Vacuna',
              'lotNumber': 'L1',
              'vialCount': 3,
            },
          ),
        ),
      );
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
      await tester.pumpAndSettle();
      expect(controller.postedBody!['kind'], 'RETURN');
      expect(controller.postedBody!['vials'], 2);
      await tester.ensureVisible(find.text('Reintentar misma operación'));
      await tester.tap(find.text('Reintentar misma operación'));
      await tester.pumpAndSettle();
      expect(controller.postedBodies, hasLength(2));
      expect(controller.postedBodies[0], controller.postedBodies[1]);
    },
  );

  testWidgets('confirmación exige destino explícito y recepción física', (
    tester,
  ) async {
    final controller = FakeInventoryController();
    await tester.pumpWidget(
      MaterialApp(
        home: CustodyEventFormPage(
          controller: controller,
          institutionId: 'i',
          confirmation: true,
          record: {
            'id': 'evento-1',
            'vaccineName': 'Vacuna',
            'lotNumber': 'L1',
            'vialCount': 2,
          },
        ),
      ),
    );
    await tester.tap(find.text('Destino tras revisión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuarentena · no disponible').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Resultado de la revisión'),
      'Pendiente de revisión',
    );
    await tester.ensureVisible(find.text('Confirmar recepción'));
    await tester.tap(find.text('Confirmar recepción'));
    await tester.pump();
    expect(controller.postedBodies, isEmpty);
    expect(
      find.textContaining('Confirma primero la recepción física'),
      findsOneWidget,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Confirmar recepción'));
    await tester.pumpAndSettle();
    expect(controller.postedResource, 'custody-events/evento-1/confirm');
    expect(controller.postedBody!['disposition'], 'QUARANTINE');
  });
  testWidgets('una jornada requiere fechas antes de guardar', (tester) async {
    final controller = FakeInventoryController();
    await tester.pumpWidget(
      MaterialApp(
        home: CampaignFormPage(controller: controller, institutionId: 'i'),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de la jornada'),
      'Jornada',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lugar'),
      'Centro',
    );
    await tester.ensureVisible(find.text('Crear jornada'));
    await tester.tap(find.text('Crear jornada'));
    await tester.pump();
    expect(find.text('Selecciona las fechas de la jornada.'), findsOneWidget);
    expect(controller.postedBodies, isEmpty);
  });
  testWidgets('sin conexión no consulta ni ofrece recepción', (tester) async {
    final controller = FakeInventoryController();
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          controller: controller,
          institutionId: 'i',
          admin: false,
          canWrite: false,
          online: false,
        ),
      ),
    );
    expect(find.textContaining('requiere conexión'), findsOneWidget);
    expect(find.text('Recibir'), findsNothing);
    expect(controller.loads, 0);
  });

  testWidgets('vacunador confirma recepción completa de su entrega', (
    tester,
  ) async {
    final controller = FakeInventoryController();
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          controller: controller,
          institutionId: 'i',
          admin: false,
          canWrite: false,
          online: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vacuna · L1'), findsOneWidget);
    await tester.tap(find.text('Recibir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 frascos completos'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(controller.postedResource, 'assignments/entrega-1/receive');
    expect(controller.postedBody, {'vials': 3});
  });

  testWidgets('el administrador navega desde el lote a registrar una entrega', (
    tester,
  ) async {
    final controller = FakeInventoryController();
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          controller: controller,
          institutionId: 'i',
          admin: true,
          canWrite: true,
          online: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crear lote'), findsNothing);
    await tester.tap(find.byTooltip('Acciones del lote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregar frascos'));
    await tester.pumpAndSettle();
    expect(find.text('Vacunador'), findsOneWidget);
    expect(find.textContaining('La entrega queda en tránsito'), findsOneWidget);
  });

  testWidgets(
    'consulta sin permiso de escritura no muestra acciones logísticas',
    (tester) async {
      final controller = FakeInventoryController();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(
            controller: controller,
            institutionId: 'i',
            admin: true,
            canWrite: false,
            online: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Crear lote'), findsNothing);
      expect(find.byTooltip('Acciones del lote'), findsNothing);
    },
  );

  testWidgets('crea lote sin registrar existencias', (tester) async {
    final controller = FakeInventoryController();
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryFormPage(
          controller: controller,
          institutionId: 'i',
          isLot: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vacuna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pentavalente').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fabricante'),
      'Fabricante A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Número de lote'),
      'L01',
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
    await tester.pumpAndSettle();
    expect(controller.postedResource, 'lots');
    expect(controller.postedBody!['vaccineId'], 'vacuna-1');
    expect(controller.postedBody!['dosesPerVial'], 10);
    expect(controller.postedBody!.containsKey('vials'), isFalse);
  });

  testWidgets('entrega valida saldo y reintenta con el mismo identificador', (
    tester,
  ) async {
    final controller = FakeInventoryController()..shouldFail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryFormPage(
          controller: controller,
          institutionId: 'i',
          isLot: false,
          lot: {
            'id': 'lote-1',
            'vaccineName': 'Vacuna',
            'lotNumber': 'L1',
            'availableVials': 5,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vacunador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Pérez').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Frascos completos'),
      '6',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo o soporte'),
      'Entrega rutinaria',
    );
    await tester.ensureVisible(find.text('Registrar entrega'));
    await tester.tap(find.text('Registrar entrega'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Supera el saldo'), findsOneWidget);
    expect(controller.postedBodies, isEmpty);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Frascos completos'),
      '3',
    );
    await tester.tap(find.text('Registrar entrega'));
    await tester.pumpAndSettle();
    expect(find.textContaining('verifica el listado'), findsOneWidget);
    await tester.ensureVisible(find.text('Reintentar misma operación'));
    await tester.tap(find.text('Reintentar misma operación'));
    await tester.pumpAndSettle();
    expect(controller.postedResource, 'assignments');
    expect(controller.postedBodies, hasLength(2));
    expect(controller.postedBodies[1], controller.postedBodies[0]);
    expect(controller.postedBody!['vaccinatorId'], 'vacunador-1');
    expect(controller.postedBody!['vials'], 3);
  });
}
