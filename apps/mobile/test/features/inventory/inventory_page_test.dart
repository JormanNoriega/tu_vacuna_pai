import 'dart:async';

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
import 'package:tu_vacuna_pai/features/inventory/presentation/difference_resolution_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/depot_regularization_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/pending_follow_ups_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/historical_custody_review_page.dart';

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
  Future<void> loadVaccinators(String institution) =>
      loadFormOptions(institution, isLot: false);

  @override
  Future<void> loadLots(String institution) async {
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
    clearError();
  }

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
        'vaccinatorId': 'vacunador-1',
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

class _ResolutionController extends FakeInventoryController {
  @override
  Future<void> execute(Future<void> Function(String token) action) async {}
}

class _FollowUpController extends FakeInventoryController {
  List<Map<String, dynamic>>? result = [];
  int requests = 0;

  @override
  Future<List<Map<String, dynamic>>?> loadPendingFollowUps(
    String institution,
  ) async {
    requests++;
    if (result == null) setError('No se pudo consultar el seguimiento.');
    return result;
  }
}

class _DelayedFollowUpController extends _FollowUpController {
  final pending = Completer<List<Map<String, dynamic>>?>();

  @override
  Future<List<Map<String, dynamic>>?> loadPendingFollowUps(String institution) {
    requests++;
    return pending.future;
  }
}

class _HistoricalController extends FakeInventoryController {
  int requests = 0;
  Map<String, dynamic>? data;

  @override
  Future<Map<String, dynamic>?> loadHistoricalCustodyReview(
    String institution,
    String assignmentId,
  ) async {
    requests++;
    if (data == null) setError('No se pudo consultar el historial.');
    return data;
  }
}

class _DelayedHistoricalController extends _HistoricalController {
  final pending = Completer<Map<String, dynamic>?>();

  @override
  Future<Map<String, dynamic>?> loadHistoricalCustodyReview(
    String institution,
    String assignmentId,
  ) {
    requests++;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'historial no muestra respuesta tardía después de perder permiso',
    (tester) async {
      final controller = _DelayedHistoricalController();
      Widget page(bool canRead) => MaterialApp(
        home: HistoricalCustodyReviewPage(
          controller: controller,
          institutionId: 'i',
          assignmentId: 'entrega-1',
          online: true,
          canRead: canRead,
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.pump();
      expect(find.text('Consultando historial…'), findsOneWidget);
      await tester.pumpWidget(page(false));
      controller.pending.complete({
        'assignmentId': 'entrega-1',
        'receipts': [],
        'events': [],
        'reviewReasons': [],
      });
      await tester.pumpAndSettle();
      expect(
        find.text('No tienes permiso para esta consulta.'),
        findsOneWidget,
      );
      expect(find.text('Entrega: entrega-1'), findsNothing);
    },
  );

  testWidgets('historial muestra referencias originales sin generar saldo', (
    tester,
  ) async {
    final controller = _HistoricalController()
      ..data = {
        'assignmentId': 'entrega-1',
        'lotId': 'lote-1',
        'custodianId': 'vacunador-1',
        'assignmentOnlyReceiptEvidence': false,
        'reviewReasons': ['RECEIPT_TOTAL_MISMATCH'],
        'receipts': [
          {
            'id': 'recibo-1',
            'lotId': 'lote-1',
            'vials': 3,
            'receivedBy': 'vacunador-1',
            'receivedAt': '2026-01-01T12:00:00Z',
            'differenceNote': 'Faltante',
          },
        ],
        'events': [
          {
            'id': 'evento-1',
            'lotId': 'lote-1',
            'vialCount': 1,
            'status': 'RETURN_PENDING',
            'reportedBy': 'vacunador-1',
            'reportedAt': '2026-01-02T12:00:00Z',
            'reportNote': 'Conteo',
          },
        ],
      };
    await tester.pumpWidget(
      MaterialApp(
        home: HistoricalCustodyReviewPage(
          controller: controller,
          institutionId: 'i',
          assignmentId: 'entrega-1',
          online: true,
          canRead: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Datos que requieren revisión'), findsOneWidget);
    expect(
      find.text('• Las cantidades de recepción no coinciden.'),
      findsOneWidget,
    );
    expect(find.text('Referencia: recibo-1'), findsOneWidget);
    expect(find.text('Recibido por (ID): vacunador-1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Referencia: evento-1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Devolución pendiente de recepción'), findsOneWidget);
    expect(find.text('Referencia: evento-1'), findsOneWidget);
    expect(find.text('Motivo: Conteo'), findsOneWidget);
    expect(find.textContaining('no calcula saldo'), findsOneWidget);
    expect(controller.postedBodies, isEmpty);
  });

  testWidgets(
    'historial aclara evidencia antigua y rechaza respuesta incompleta',
    (tester) async {
      final controller = _HistoricalController()
        ..data = {
          'assignmentId': 'entrega-1',
          'lotId': 'l',
          'custodianId': 'v',
          'assignmentOnlyReceiptEvidence': true,
          'reviewReasons': [],
          'receipts': [],
          'events': [],
        };
      await tester.pumpWidget(
        MaterialApp(
          home: HistoricalCustodyReviewPage(
            controller: controller,
            institutionId: 'i',
            assignmentId: 'entrega-1',
            online: true,
            canRead: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('sin registro individual de recepción'),
        findsOneWidget,
      );
      expect(
        find.text('No hay registros individuales de recepción.'),
        findsOneWidget,
      );
      controller.data = {
        'assignmentId': 'otra-entrega',
        'receipts': [],
        'events': [],
        'reviewReasons': [],
      };
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('respuesta del historial está incompleta'),
        findsOneWidget,
      );
      expect(
        find.textContaining('sin registro individual de recepción'),
        findsNothing,
      );
    },
  );

  testWidgets('historial no consulta sin permiso ni conexión', (tester) async {
    final controller = _HistoricalController();
    Widget page({required bool online, required bool canRead}) => MaterialApp(
      home: HistoricalCustodyReviewPage(
        controller: controller,
        institutionId: 'i',
        assignmentId: 'entrega-1',
        online: online,
        canRead: canRead,
      ),
    );
    await tester.pumpWidget(page(online: false, canRead: true));
    await tester.pumpAndSettle();
    expect(find.text('Esta consulta requiere conexión.'), findsOneWidget);
    await tester.pumpWidget(page(online: true, canRead: false));
    await tester.pumpAndSettle();
    expect(find.text('No tienes permiso para esta consulta.'), findsOneWidget);
    expect(controller.requests, 0);
  });

  testWidgets(
    'administrador abre historial desde entrega sin quitar revisión de diferencias',
    (tester) async {
      final controller = _HistoricalController()
        ..data = {
          'assignmentId': 'entrega-1',
          'lotId': 'l',
          'custodianId': 'v',
          'assignmentOnlyReceiptEvidence': false,
          'reviewReasons': [],
          'receipts': [],
          'events': [],
        };
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
      controller.assignments.first.addAll({
        'status': 'PARTIALLY_RECEIVED',
        'receivedVials': 2,
        'resolvedVials': 0,
      });
      controller.notifyListeners();
      await tester.pump();
      await tester.tap(find.text('Ana Pérez · Vacuna'));
      await tester.pumpAndSettle();
      expect(find.text('Revisar diferencia'), findsOneWidget);
      await tester.ensureVisible(find.text('Ver historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver historial'));
      await tester.pumpAndSettle();
      expect(find.text('Historial de la entrega'), findsOneWidget);
      expect(controller.requests, 1);
      expect(controller.postedBodies, isEmpty);
    },
  );

  testWidgets('seguimiento no muestra datos tardíos tras perder conexión', (
    tester,
  ) async {
    final controller = _DelayedFollowUpController();
    Widget page(bool online) => MaterialApp(
      home: PendingFollowUpsPage(
        controller: controller,
        institutionId: 'i',
        online: online,
        canRead: true,
      ),
    );
    await tester.pumpWidget(page(true));
    await tester.pump();
    expect(find.text('Consultando pendientes…'), findsOneWidget);
    await tester.pumpWidget(page(false));
    controller.pending.complete([
      {
        'kind': 'RETURN_PENDING',
        'vaccineName': 'Vacuna tardía',
        'lotNumber': 'L',
        'pendingVials': 1,
      },
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Esta consulta requiere conexión.'), findsOneWidget);
    expect(find.textContaining('Vacuna tardía'), findsNothing);
  });

  testWidgets(
    'seguimiento separa devoluciones y correcciones sin mostrar saldos',
    (tester) async {
      final controller = _FollowUpController()
        ..result = [
          {
            'kind': 'RETURN_PENDING',
            'vaccineName': 'Vacuna A',
            'lotNumber': 'L1',
            'pendingVials': 3,
            'note': 'Conteo',
            'assignmentId': 'entrega-a',
          },
          {
            'kind': 'DISPATCH_CORRECTION',
            'vaccineName': 'Vacuna B',
            'lotNumber': 'L2',
            'pendingVials': 2,
            'note': 'Acta',
            'assignmentId': 'entrega-b',
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: PendingFollowUpsPage(
            controller: controller,
            institutionId: 'i',
            online: true,
            canRead: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Devoluciones pendientes'), findsOneWidget);
      expect(
        find.text('3 frascos pendientes de recepción en depósito'),
        findsOneWidget,
      );
      expect(find.text('Correcciones sin regularizar'), findsOneWidget);
      expect(find.text('2 frascos sin regularizar'), findsOneWidget);
      expect(find.textContaining('no son saldos disponibles'), findsOneWidget);
      expect(find.textContaining('no se presume pérdida'), findsOneWidget);
      expect(controller.postedBodies, isEmpty);
    },
  );

  testWidgets('seguimiento distingue vacío, error, permiso y desconexión', (
    tester,
  ) async {
    final controller = _FollowUpController();
    Widget page({bool online = true, bool canRead = true}) => MaterialApp(
      home: PendingFollowUpsPage(
        controller: controller,
        institutionId: 'i',
        online: online,
        canRead: canRead,
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('No hay pendientes en esta consulta.'), findsOneWidget);
    controller.result = null;
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo consultar el seguimiento.'), findsOneWidget);
    expect(find.text('No hay pendientes en esta consulta.'), findsNothing);
    controller.result = [];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No hay pendientes en esta consulta.'), findsOneWidget);
    final calls = controller.requests;
    await tester.pumpWidget(page(online: false));
    await tester.pumpAndSettle();
    expect(find.text('Esta consulta requiere conexión.'), findsOneWidget);
    expect(controller.requests, calls);
    await tester.pumpWidget(page(canRead: false));
    await tester.pumpAndSettle();
    expect(find.text('No tienes permiso para esta consulta.'), findsOneWidget);
    expect(controller.requests, calls);
  });

  testWidgets('solo administrador ve acceso a seguimiento', (tester) async {
    final controller = _FollowUpController();
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
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    expect(find.text('Ver seguimiento pendiente'), findsOneWidget);
    await tester.tap(find.text('Ver seguimiento pendiente'));
    await tester.pumpAndSettle();
    expect(find.text('Seguimiento pendiente'), findsOneWidget);
    expect(controller.requests, 1);
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
    expect(find.text('Ver seguimiento pendiente'), findsNothing);
  });

  testWidgets('regularización exige conteo, aptitud y conserva el ID', (
    tester,
  ) async {
    final controller = _ResolutionController()..shouldFail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: DepotRegularizationPage(
          controller: controller,
          institutionId: 'i',
          canWrite: true,
          resolution: {
            'id': 'correccion',
            'vialCount': 2,
            'regularizedVials': 0,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Frascos contados'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Evidencia del conteo y revisión'),
      'Acta y conteo',
    );
    await tester.ensureVisible(find.text('Confirmar permanencia'));
    await tester.tap(find.text('Confirmar permanencia'));
    await tester.pump();
    expect(controller.postedBodies, isEmpty);
    expect(
      find.text('Confirma el conteo y la aptitud antes de continuar.'),
      findsOneWidget,
    );
    ScaffoldMessenger.of(tester.element(find.byType(DepotRegularizationPage)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Confirmar permanencia'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Reintentar misma operación'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reintentar misma operación'));
    await tester.pumpAndSettle();
    expect(controller.postedBodies, hasLength(2));
    expect(controller.postedBodies[1], controller.postedBodies[0]);
    expect(controller.postedBodies[0]['physicalAndSuitable'], isTrue);
  });

  testWidgets('resolución exige evidencia y conserva identidad al reintentar', (
    tester,
  ) async {
    final controller = _ResolutionController()..shouldFail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: DifferenceResolutionPage(
          controller: controller,
          institutionId: 'i',
          canWrite: true,
          assignment: {
            'id': 'a',
            'vaccineName': 'Vacuna',
            'lotNumber': 'L1',
            'vialCount': 10,
            'receivedVials': 8,
            'resolvedVials': 0,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('no devuelve frascos'), findsOneWidget);
    await tester.tap(find.text('Resolución documentada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corrección de despacho').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Frascos a resolver'),
      '2',
    );
    await tester.ensureVisible(find.text('Registrar resolución'));
    await tester.tap(find.text('Registrar resolución'));
    await tester.pumpAndSettle();
    expect(find.text('Describe el motivo y la evidencia.'), findsOneWidget);
    expect(controller.postedBodies, isEmpty);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo y evidencia'),
      'Acta de despacho',
    );
    await tester.ensureVisible(find.text('Registrar resolución'));
    await tester.tap(find.text('Registrar resolución'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Reintentar misma operación'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reintentar misma operación'));
    await tester.pumpAndSettle();
    expect(controller.postedBodies, hasLength(2));
    expect(controller.postedBodies[1], controller.postedBodies[0]);
    expect(controller.postedBodies[0]['kind'], 'DISPATCH_CORRECTION');
  });

  testWidgets('separar jornadas conserva entregas y el informe', (
    tester,
  ) async {
    final controller = FakeInventoryController();
    controller.campaigns = [
      {
        'name': 'Brigada',
        'location': 'Centro',
        'startsOn': '2028-01-01',
        'endsOn': '2028-01-02',
        'status': 'ACTIVE',
      },
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryPage(
          controller: controller,
          institutionId: 'i',
          admin: true,
          online: true,
          canWrite: true,
          embedded: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nueva entrega'), findsOneWidget);
    expect(find.text('Lotes con saldo en depósito'), findsNothing);
    expect(find.text('Brigada'), findsNothing);
    await tester.tap(find.text('Jornadas'));
    await tester.pumpAndSettle();
    expect(find.text('Brigada'), findsOneWidget);
    expect(find.text('Lotes con saldo en depósito'), findsNothing);
    await tester.tap(find.text('Entregas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    expect(find.text('Generar informe CSV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      find.widgetWithText(TextFormField, 'Nombre de la jornada (opcional)'),
      'Jornada',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lugar'),
      'Centro',
    );
    await tester.ensureVisible(find.text('Guardar y elegir vacunadores'));
    await tester.tap(find.text('Guardar y elegir vacunadores'));
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
    expect(find.textContaining('Enviados: 3'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Frascos recibidos ahora'),
      '3',
    );
    await tester.tap(find.text('Confirmar recepción'));
    await tester.pumpAndSettle();
    expect(controller.postedResource, 'assignments/entrega-1/receipts');
    expect(controller.postedBody!['vials'], 3);
    expect(controller.postedBody!['id'], isNotEmpty);
  });

  testWidgets(
    'recepción parcial exige observación y reintenta con el mismo ID',
    (tester) async {
      final controller = FakeInventoryController()..shouldFail = true;
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
      await tester.tap(find.text('Recibir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Frascos recibidos ahora'),
        '2',
      );
      await tester.tap(find.text('Confirmar recepción'));
      await tester.pumpAndSettle();
      expect(find.text('Describe la diferencia.'), findsOneWidget);
      expect(controller.postedBodies, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Observación de la diferencia'),
        'Faltó un frasco',
      );
      await tester.tap(find.text('Confirmar recepción'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Reintentar misma operación'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Reintentar misma operación'));
      await tester.pumpAndSettle();
      expect(controller.postedBodies, hasLength(2));
      expect(controller.postedBodies[1], controller.postedBodies[0]);
    },
  );

  testWidgets('el administrador empieza una entrega por el vacunador', (
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
    expect(find.text('Lotes con saldo en depósito'), findsNothing);
    await tester.tap(find.text('Nueva entrega'));
    await tester.pumpAndSettle();
    expect(find.text('Vacunador'), findsOneWidget);
    expect(find.text('¿Quién recibe?'), findsOneWidget);
    expect(find.text('¿Qué vacunas le entregas?'), findsOneWidget);
    expect(find.text('Jornada (opcional)'), findsNothing);
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
      expect(find.text('Entregar'), findsNothing);
      expect(find.text('Nueva entrega'), findsNothing);
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
    await tester.scrollUntilVisible(
      find.text('Reintentar misma operación'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reintentar misma operación'));
    await tester.pumpAndSettle();
    expect(controller.postedResource, 'assignments');
    expect(controller.postedBodies, hasLength(2));
    expect(controller.postedBodies[1], controller.postedBodies[0]);
    expect(controller.postedBody!['vaccinatorId'], 'vacunador-1');
    expect(controller.postedBody!['vials'], 3);
  });
}
