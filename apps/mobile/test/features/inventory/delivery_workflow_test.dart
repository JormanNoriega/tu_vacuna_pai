import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/campaign_detail_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/campaign_form_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/campaign_team_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/delivery_form_page.dart';
import 'package:tu_vacuna_pai/features/inventory/presentation/inventory_page.dart';

import 'inventory_page_test.dart' show FakeInventoryController;

const _campaign = {
  'id': 'j1',
  'name': 'Jornada Centro',
  'location': 'Centro',
  'startsOn': '2028-01-01',
  'endsOn': '2028-01-01',
  'status': 'ACTIVE',
};

class _WorkflowController extends FakeInventoryController {
  final team = <Map<String, dynamic>>[];
  int? failCall;
  bool failReads = false;
  int? failureStatus;

  @override
  Future<void> loadLots(String institution) async {
    await super.loadLots(institution);
    lots = [
      ...lots,
      {
        'id': 'lote-2',
        'vaccineName': 'Otra vacuna',
        'lotNumber': 'L2',
        'availableVials': 10,
        'expiresOn': '2028-02-01',
      },
      {
        'id': 'vencido',
        'vaccineName': 'Vencida',
        'lotNumber': 'V1',
        'availableVials': 10,
        'expiresOn': '2020-01-01',
      },
      {
        'id': 'vacio',
        'vaccineName': 'Sin saldo',
        'lotNumber': 'S1',
        'availableVials': 0,
        'expiresOn': '2028-02-01',
      },
    ];
    if (failReads) setError('Error consultando lotes.');
  }

  @override
  Future<void> loadVaccinators(String institution) async {
    await super.loadVaccinators(institution);
    vaccinators = [
      ...vaccinators,
      {
        'id': 'vacunador-2',
        'fullName': 'Luis Gómez',
        'status': 'ACTIVE',
        'roles': ['VACCINATOR'],
      },
    ];
  }

  @override
  Future<void> load(String institution, {required bool admin}) async {
    await super.load(institution, admin: admin);
    campaigns = [Map.of(_campaign)];
    assignments = [];
  }

  @override
  Future<List<Map<String, dynamic>>?> loadCampaignParticipants(
    String institution,
    String campaignId,
  ) async => List.of(team);

  @override
  Future<bool> post(
    String institution,
    String resource,
    Map<String, dynamic> body,
  ) async {
    shouldFail = postedBodies.length + 1 == failCall;
    lastPostStatus = shouldFail ? failureStatus : null;
    final ok = await super.post(institution, resource, body);
    if (ok && resource.endsWith('/participants')) {
      final id = body['vaccinatorId'];
      if (!team.any((p) => p['id'] == id)) {
        team.add({
          'id': id,
          'name': id == 'vacunador-1' ? 'Ana Pérez' : 'Luis Gómez',
        });
      }
    }
    return ok;
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String field, String option) async {
  await _tap(tester, field);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'entrega directa: vacunador, varios lotes y reintento solo del pendiente',
    (tester) async {
      final c = _WorkflowController()..failCall = 2;
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryFormPage(controller: c, institutionId: 'i'),
        ),
      );
      await tester.pumpAndSettle();
      await _select(tester, 'Vacunador', 'Ana Pérez');
      await _select(tester, 'Vacuna y lote', 'Vacuna · L1');
      expect(find.text('Vencida · V1'), findsNothing);
      expect(find.text('Sin saldo · S1'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Frascos completos'),
        '2',
      );
      await _tap(tester, 'Añadir otra vacuna o lote');
      final second = find
          .widgetWithText(DropdownButtonFormField<String>, 'Vacuna y lote')
          .last;
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(
        find.text('Vacuna · L1'),
        findsNothing,
      ); // no repetir lote en otra fila
      await tester.tap(find.text('Otra vacuna · L2').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Frascos completos').last,
        '3',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo de la entrega'),
        'Turno de mañana',
      );
      await _tap(tester, 'Revisar entrega');
      expect(c.postedBodies, isEmpty); // confirmar antes de mover existencias
      await _tap(tester, 'Confirmar entrega');
      expect(c.postedBodies, hasLength(2));
      expect(c.postedBodies.first.containsKey('campaignId'), isFalse);
      expect(c.postedBodies.first['vaccinatorId'], 'vacunador-1');
      expect(find.textContaining('1 de 2 lotes confirmados'), findsOneWidget);
      // Un fallo de red no permite regenerar IDs ni abandonar sin aviso.
      expect(find.text('Corregir pendientes rechazados'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hay entregas por confirmar'), findsOneWidget);
      await _tap(tester, 'Seguir revisando');
      await _tap(tester, 'Reintentar pendientes');
      expect(c.postedBodies, hasLength(3));
      expect(c.postedBodies[2], c.postedBodies[1]);
      expect(c.postedBodies.where((b) => b['lotId'] == 'lote-1'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'entrega valida saldo sin enviar y permite cancelar confirmación',
    (tester) async {
      final c = _WorkflowController();
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryFormPage(controller: c, institutionId: 'i'),
        ),
      );
      await tester.pumpAndSettle();
      await _select(tester, 'Vacunador', 'Ana Pérez');
      await _select(tester, 'Vacuna y lote', 'Vacuna · L1');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Frascos completos'),
        '6',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo de la entrega'),
        'Turno',
      );
      await _tap(tester, 'Revisar entrega');
      expect(
        find.text('Supera los frascos disponibles de este lote.'),
        findsOneWidget,
      );
      expect(c.postedBodies, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Frascos completos'),
        '2',
      );
      await _tap(tester, 'Revisar entrega');
      await _tap(tester, 'Volver');
      expect(c.postedBodies, isEmpty);
    },
  );

  testWidgets(
    'un rechazo explícito permite corregir sin modificar un resultado incierto',
    (tester) async {
      final c = _WorkflowController()
        ..failCall = 1
        ..failureStatus = 400;
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryFormPage(controller: c, institutionId: 'i'),
        ),
      );
      await tester.pumpAndSettle();
      await _select(tester, 'Vacunador', 'Ana Pérez');
      await _select(tester, 'Vacuna y lote', 'Vacuna · L1');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Frascos completos'),
        '2',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo de la entrega'),
        'Turno',
      );
      await _tap(tester, 'Revisar entrega');
      expect(find.text('Para Ana Pérez'), findsOneWidget);
      expect(find.text('Vacuna · Lote L1\n2 frascos'), findsOneWidget);
      await _tap(tester, 'Confirmar entrega');
      await _tap(tester, 'Corregir pendientes rechazados');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Frascos completos'),
        '1',
      );
      await _tap(tester, 'Revisar entrega');
      await _tap(tester, 'Confirmar entrega');
      expect(c.postedBodies, hasLength(2));
      expect(c.postedBodies.last['vials'], 1);
      expect(
        c.postedBodies.last['assignmentId'],
        isNot(c.postedBodies.first['assignmentId']),
      );
    },
  );

  testWidgets(
    'cambiar institución invalida respuesta tardía y no publica entregas anteriores',
    (tester) async {
      final c = _ContextController();
      Widget page(String institution) => MaterialApp(
        home: InventoryPage(
          controller: c,
          institutionId: institution,
          admin: true,
          online: true,
          canWrite: false,
        ),
      );
      await tester.pumpWidget(page('A'));
      await tester.pump();
      await tester.pumpWidget(page('B'));
      c.pendingB.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Vacuna B'), findsOneWidget);
      c.pendingA.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Vacuna A'), findsNothing);
      expect(find.textContaining('Vacuna B'), findsOneWidget);
    },
  );

  testWidgets(
    'jornada muestra equipo y abre asignación con destinatario y jornada fijos',
    (tester) async {
      final c = _WorkflowController()
        ..team.add({'id': 'vacunador-1', 'name': 'Ana Pérez'});
      await tester.pumpWidget(
        MaterialApp(
          home: CampaignDetailPage(
            controller: c,
            institutionId: 'i',
            campaign: _campaign,
            canWrite: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Centro'), findsOneWidget);
      expect(find.text('01/01/2028'), findsOneWidget);
      expect(find.text('Sin vacunas asignadas'), findsOneWidget);
      await _tap(tester, 'Ana Pérez');
      await _tap(tester, 'Asignar vacunas');
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Vacunador'), findsNothing);
      await _select(tester, 'Vacuna y lote', 'Vacuna · L1');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Frascos completos'),
        '1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo de la entrega'),
        'Jornada Centro',
      );
      await _tap(tester, 'Revisar entrega');
      await _tap(tester, 'Confirmar entrega');
      expect(c.postedBodies.single['campaignId'], 'j1');
      expect(c.postedBodies.single['vaccinatorId'], 'vacunador-1');
    },
  );

  testWidgets(
    'equipo permite selección múltiple y conserva lo guardado si falla uno',
    (tester) async {
      final c = _WorkflowController()..failCall = 2;
      await tester.pumpWidget(
        MaterialApp(
          home: CampaignTeamPage(
            controller: c,
            institutionId: 'i',
            campaignId: 'j1',
            participantIds: {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Ana Pérez');
      await _tap(tester, 'Luis Gómez');
      await _tap(tester, 'Agregar 2 vacunadores');
      expect(c.team, hasLength(1));
      expect(find.text('Ya participa en esta jornada'), findsOneWidget);
      await _tap(tester, 'Reintentar pendientes');
      expect(c.team, hasLength(2));
      expect(c.postedBodies[2], c.postedBodies[1]);
    },
  );

  testWidgets(
    'jornada finalizada no ofrece nuevas asignaciones ni edición de equipo',
    (tester) async {
      final campaign = {..._campaign, 'status': 'FINISHED'};
      // Mantener el estado del servidor coherente con esta prueba.
      await tester.pumpWidget(
        MaterialApp(
          home: CampaignDetailPage(
            controller: _FinishedController(),
            institutionId: 'i',
            campaign: campaign,
            canWrite: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Elegir vacunadores'), findsNothing);
      expect(find.text('Asignar vacunas'), findsNothing);
      expect(find.textContaining('Jornada finalizada.'), findsOneWidget);
    },
  );

  testWidgets(
    'solo lectura conserva equipo sin acciones de escritura en móvil estrecho',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = _WorkflowController()
        ..team.add({'id': 'vacunador-1', 'name': 'Ana Pérez'});
      await tester.pumpWidget(
        MaterialApp(
          home: CampaignDetailPage(
            controller: c,
            institutionId: 'i',
            campaign: _campaign,
            canWrite: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Ana Pérez');
      expect(find.text('Asignar vacunas'), findsNothing);
      expect(find.text('Agregar vacunadores'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fallo de carga no permite registrar entrega', (tester) async {
    final c = _WorkflowController()..failReads = true;
    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryFormPage(controller: c, institutionId: 'i'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Error consultando lotes.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Revisar entrega'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Revisar entrega'),
    );
    expect(button.onPressed, isNull);
    expect(c.postedBodies, isEmpty);
  });

  testWidgets(
    'desde Jornadas: lugar y fecha, equipo y asignación por vacunador',
    (tester) async {
      final c = _WorkflowController();
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryPage(
            controller: c,
            institutionId: 'i',
            admin: true,
            online: true,
            canWrite: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Jornadas');
      await _tap(tester, 'Nueva jornada');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lugar'),
        'Puesto Norte',
      );
      await _tap(tester, 'Seleccionar fecha');
      await _tap(tester, 'OK');
      await _tap(tester, 'Guardar y elegir vacunadores');
      expect(find.text('¿Quiénes participan?'), findsOneWidget);
      await _tap(tester, 'Ana Pérez');
      await _tap(tester, 'Agregar 1 vacunador');
      expect(find.text('Jornada · Puesto Norte'), findsOneWidget);
      await _tap(tester, 'Ana Pérez');
      await _tap(tester, 'Asignar vacunas');
      expect(find.text('¿Qué vacunas le entregas?'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(
        c.postedBodies,
        hasLength(2),
      ); // jornada + participante; aún no entrega
      expect(c.postedResource, endsWith('/participants'));
    },
  );

  testWidgets('pantalla principal admite texto ampliado en móvil estrecho', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = _WorkflowController();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: InventoryPage(
          controller: c,
          institutionId: 'i',
          admin: true,
          online: true,
          canWrite: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'crear jornada con lugar y fecha continúa automáticamente a elegir equipo',
    (tester) async {
      final c = _WorkflowController();
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<Map<String, dynamic>>(
                        MaterialPageRoute(
                          builder: (_) => CampaignFormPage(
                            controller: c,
                            institutionId: 'i',
                          ),
                        ),
                      );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, 'Abrir');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Lugar'),
        'Centro',
      );
      await _tap(tester, 'Seleccionar fecha');
      await _tap(tester, 'OK');
      await _tap(tester, 'Guardar y elegir vacunadores');
      expect(c.postedResource, 'campaigns');
      expect(c.postedBodies.single['name'], 'Jornada · Centro');
      expect(
        c.postedBodies.single['startsOn'],
        c.postedBodies.single['endsOn'],
      );
      expect(result?['status'], 'ACTIVE');
      expect(result?['location'], 'Centro');
    },
  );
}

class _ContextController extends FakeInventoryController {
  final pendingA = Completer<void>();
  final pendingB = Completer<void>();

  @override
  Future<void> load(String institution, {required bool admin}) async {
    await (institution == 'A' ? pendingA.future : pendingB.future);
    assignments = [
      {
        'id': institution,
        'vaccinatorId': 'vacunador-1',
        'vaccineName': 'Vacuna $institution',
        'lotNumber': institution,
        'vialCount': 1,
        'status': 'RECEIVED',
      },
    ];
    notifyListeners();
  }
}

class _FinishedController extends _WorkflowController {
  @override
  Future<void> load(String institution, {required bool admin}) async {
    await super.load(institution, admin: admin);
    campaigns = [
      {..._campaign, 'status': 'FINISHED'},
    ];
  }
}
