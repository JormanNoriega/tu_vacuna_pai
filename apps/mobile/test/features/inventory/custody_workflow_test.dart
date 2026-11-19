import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/custody_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/custody_workflow_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/custody_record_page.dart';

import 'inventory_page_test.dart' show FakeInventoryController;

const assignment = {
  'id': 'a',
  'vaccineName': 'Vacuna',
  'lotNumber': 'L1',
  'vialCount': 5,
  'receivedVials': 5,
  'status': 'RECEIVED',
};

class Controller extends FakeInventoryController {
  Map<String, dynamic>? result = {
    'assignmentId': 'a',
    'recordingEnabled': true,
    'receivedVials': 5,
    'dispatchedVials': 5,
    'resolvedVials': 0,
    'transferStatus': 'RECEIVED',
    'declaredEventVials': 0,
    'pendingReturnVials': 0,
    'registeredLinkedDoses': 0,
    'cancelledLinkedDoses': 0,
    'counts': <Map<String, dynamic>>[],
    'clinicalDoses': <Map<String, dynamic>>[],
    'basis': 'b',
    'custodyState': 'COUNT_REQUIRED',
  };
  int reads = 0;
  bool? mine;
  @override
  Future<Map<String, dynamic>?> loadCustodyWorkflow(
    String institution,
    String id, {
    required bool admin,
  }) async {
    reads++;
    mine = !admin;
    return result;
  }
}

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'vacunador documenta conteo y descartes, sin cierre administrativo',
    (tester) async {
      final c = Controller();
      await tester.pumpWidget(
        MaterialApp(
          home: CustodyWorkflowPage(
            controller: c,
            institutionId: 'i',
            assignment: assignment,
            admin: false,
            canWrite: false,
            online: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.mine, isTrue);
      expect(find.text('Revisar y finalizar transferencia'), findsNothing);
      await tap(tester, 'Registrar conteo y descartes');
      final values = {
        'Frascos cerrados que conservas': '3',
        'Frascos abiertos que conservas': '1',
        'Frascos agotados acumulados': '1',
        'Frascos descartados acumulados': '0',
        'Dosis descartadas acumuladas': '2',
      };
      for (final f in values.entries) {
        final finder = find.widgetWithText(TextFormField, f.key);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, f.value);
      }
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Evidencia y observaciones'),
        'Conteo físico revisado',
      );
      await tap(tester, 'Guardar evidencia');
      expect(c.postedResource, 'my-assignments/a/custody-counts');
      expect(c.postedBodies.single['closedVials'], 3);
      expect(c.postedBodies.single['discardedDoses'], 2);
      expect(c.reads, 2);
    },
  );
  testWidgets(
    'solo lectura no ofrece finalizaciones ni aceptación de revisión',
    (tester) async {
      final c = Controller();
      await tester.pumpWidget(
        MaterialApp(
          home: CustodyWorkflowPage(
            controller: c,
            institutionId: 'i',
            assignment: assignment,
            admin: true,
            canWrite: false,
            online: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.mine, isFalse);
      expect(find.text('Revisar y finalizar transferencia'), findsNothing);
      expect(find.text('Registrar conteo y descartes'), findsNothing);
      expect(find.text('Registrar revisión administrativa'), findsNothing);
    },
  );
  testWidgets(
    'no habilitado no presenta cifras de custodia ficticias ni escrituras',
    (tester) async {
      final c = Controller()
        ..result = {
          'assignmentId': 'a',
          'recordingEnabled': false,
          'counts': [],
          'clinicalDoses': [],
        };
      await tester.pumpWidget(
        MaterialApp(
          home: CustodyWorkflowPage(
            controller: c,
            institutionId: 'i',
            assignment: assignment,
            admin: true,
            canWrite: true,
            online: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Registro de custodia pendiente de habilitación'),
        findsOneWidget,
      );
      expect(find.text('Registrar conteo y descartes'), findsNothing);
      expect(find.textContaining('0 frascos recibidos'), findsNothing);
    },
  );
  testWidgets('sin red no consulta; una respuesta ajena no muestra evidencia', (
    tester,
  ) async {
    final c = Controller();
    Widget page(bool online) => MaterialApp(
      home: CustodyWorkflowPage(
        controller: c,
        institutionId: 'i',
        assignment: assignment,
        admin: true,
        canWrite: true,
        online: online,
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    expect(c.reads, 0);
    c.result = {...c.result!, 'assignmentId': 'otra'};
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('respuesta de custodia está incompleta'),
      findsOneWidget,
    );
    expect(find.text('Revisar y finalizar transferencia'), findsNothing);
  });
  testWidgets(
    'evidencia fallida reintenta mismos datos y UUID sin duplicar intención',
    (tester) async {
      final c = Controller()..shouldFail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: CustodyRecordPage(
            controller: c,
            institutionId: 'i',
            resource: 'assignments/a/transfer-finalizations',
            title: 'Finalizar',
            explanation: 'Revisión del traslado',
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Evidencia y observaciones'),
        'Soporte revisado',
      );
      await tap(tester, 'Guardar evidencia');
      expect(c.postedBodies, hasLength(1));
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse,
      );
      c.shouldFail = false;
      await tap(tester, 'Reintentar mismo registro');
      expect(c.postedBodies, hasLength(2));
      expect(c.postedBodies[0], c.postedBodies[1]);
    },
  );
  testWidgets('bandeja por jornada no mezcla entregas de otra actividad', (
    tester,
  ) async {
    final c = Controller();
    await tester.pumpWidget(
      MaterialApp(
        home: CustodyPage(
          controller: c,
          institutionId: 'i',
          campaignId: 'otra',
          admin: true,
          canWrite: true,
          online: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No hay entregas para este ámbito'),
      findsOneWidget,
    );
    expect(find.text('Vacuna · Lote L1'), findsNothing);
  });
}
