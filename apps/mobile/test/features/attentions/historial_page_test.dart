import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/core/presentation/widgets/shimmer_loading.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/entities/attention.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/repositories/attentions_repository.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/use_cases/attentions_use_cases.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/catalog_entities.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/repositories/patients_repository.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/patient_profile_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/search_patient.dart';
import 'package:tu_vacuna_pai/features/patients/presentation/patient_detail_controller.dart';
import 'package:tu_vacuna_pai/features/attentions/presentation/history_controller.dart';
import 'package:tu_vacuna_pai/features/attentions/presentation/pages/historial_page.dart';

import '../admin/fake_admin_repository.dart';

void main() {
  const online = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['ATTENTION_READ', 'PATIENT_READ'],
  );

  testWidgets(
    'HistorialPage muestra Skeleton con Shimmer mientras busca y luego muestra resultados',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final searchCompleter = Completer<List<Patient>>();
      final patientRepo = _AsyncPatientSearchRepo(searchCompleter);
      final attentionRepo = _FakeAttentionsRepo();
      final catalogRepo = _FakeCatalogRepo();

      final sessionManager = FakeSessionManager('token-hist-123');

      final historyController = HistoryController(
        sessionManager: sessionManager,
        searchPatient: SearchPatient(patientRepo),
        listPatientAttentions: ListPatientAttentions(attentionRepo),
        listReferenceCatalogs: ListReferenceCatalogs(catalogRepo),
      );

      final patientDetailController = PatientDetailController(
        sessionManager: sessionManager,
        getPatient: GetPatient(patientRepo),
        updateDemographics: UpdatePatientDemographics(patientRepo),
        updateContact: UpdatePatientContact(patientRepo),
        updateMedicalHistories: UpdatePatientMedicalHistories(patientRepo),
        listCountries: ListCountries(catalogRepo),
        listDepartments: ListDepartments(catalogRepo),
        listMunicipalities: ListMunicipalities(catalogRepo),
        listPatientAttentions: ListPatientAttentions(attentionRepo),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistorialPage(
              controller: historyController,
              patientDetailController: patientDetailController,
              offline: online,
            ),
          ),
        ),
      );

      await tester.pump();

      // 1. Estado inicial: pide buscar un paciente
      expect(find.byKey(const ValueKey('empty_prompt')), findsOneWidget);

      // 2. Ingresar documento y disparar la búsqueda
      await tester.enterText(find.byType(TextField), '12345678');
      await tester.tap(find.text('Buscar historial'));

      // 3. Estado de búsqueda en curso: debe mostrar el skeleton con Shimmer
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('history_skeleton')), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsOneWidget);

      // 4. Completamos la búsqueda con un paciente y sus atenciones
      searchCompleter.complete([
        Patient(
          id: 'pat-99',
          documentType: 'CC',
          documentNumber: '12345678',
          firstName: 'Elena',
          lastName: 'Rios',
          birthDate: DateTime(1992, 4, 15),
          sex: 'FEMALE',
          status: 'ACTIVE',
        ),
      ]);

      attentionRepo.attentions = [
        Attention(
          id: 'att-1',
          patientId: 'pat-99',
          professionalId: 'prof-1',
          status: 'COMPLETED',
          version: 1,
          attentionDate: DateTime(2026, 2, 10),
          doses: const [
            AppliedDose(
              id: 'dose-1',
              attentionId: 'att-1',
              vaccineId: 'vac-1',
              vaccineNameSnapshot: 'Hepatitis B',
              vaccineCodeSnapshot: 'HEP-B',
              doseLabelSnapshot: 'Dosis Única',
              status: 'REGISTERED',
            ),
          ],
        ),
      ];

      // Permitir resolución de microtasks y transición
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 5. El skeleton desaparece y se visualiza la cabecera y atenciones reales
      expect(find.byKey(const ValueKey('history_skeleton')), findsNothing);
      expect(find.byKey(const ValueKey('history_content')), findsOneWidget);
      expect(find.text('Elena Rios'), findsOneWidget);
      expect(find.text('Hepatitis B'), findsOneWidget);
      expect(find.text('Dosis Única'), findsOneWidget);
    },
  );

  testWidgets(
    'HistorialPage muestra buscador arriba y lista de registros abajo para vacunador',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final patientRepo = _ImmediatePatientSearchRepo([
        Patient(
          id: 'pat-1',
          documentType: 'CC',
          documentNumber: '87654321',
          firstName: 'Carlos',
          lastName: 'Mendoza',
          birthDate: DateTime(1990, 1, 1),
          sex: 'MALE',
          status: 'ACTIVE',
        ),
      ]);
      final attentionRepo = _FakeAttentionsRepo();
      final catalogRepo = _FakeCatalogRepo();
      final sessionManager = FakeSessionManager('token-test');

      final historyController = HistoryController(
        sessionManager: sessionManager,
        searchPatient: SearchPatient(patientRepo),
        listPatientAttentions: ListPatientAttentions(attentionRepo),
        listReferenceCatalogs: ListReferenceCatalogs(catalogRepo),
      );

      final patientDetailController = PatientDetailController(
        sessionManager: sessionManager,
        getPatient: GetPatient(patientRepo),
        updateDemographics: UpdatePatientDemographics(patientRepo),
        updateContact: UpdatePatientContact(patientRepo),
        updateMedicalHistories: UpdatePatientMedicalHistories(patientRepo),
        listCountries: ListCountries(catalogRepo),
        listDepartments: ListDepartments(catalogRepo),
        listMunicipalities: ListMunicipalities(catalogRepo),
        listPatientAttentions: ListPatientAttentions(attentionRepo),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistorialPage(
              controller: historyController,
              patientDetailController: patientDetailController,
              offline: online,
              institutionId: 'inst-100',
              userId: 'user-200',
              isAdmin: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. El buscador de paciente específico está arriba
      expect(find.text('Buscar paciente específico'), findsOneWidget);
      expect(find.text('Buscar historial'), findsOneWidget);

      // 2. Abajo se encuentra la sección de historial general de registros
      expect(
        find.byKey(const ValueKey('recent_history_section')),
        findsOneWidget,
      );
      expect(find.text('Historial de registros'), findsOneWidget);

      // 3. Verificamos que el buscador esté posicionado verticalmente antes (arriba) del historial
      final searchTop = tester
          .getTopLeft(find.text('Buscar paciente específico'))
          .dy;
      final historyTop = tester
          .getTopLeft(find.byKey(const ValueKey('recent_history_section')))
          .dy;
      expect(searchTop, lessThan(historyTop));

      // 4. Buscar un paciente específico
      await tester.enterText(find.byType(TextField), '87654321');
      await tester.tap(find.text('Buscar historial'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 5. Ahora muestra el resultado de búsqueda del paciente con su botón limpiar
      expect(find.byKey(const ValueKey('history_content')), findsOneWidget);
      expect(find.text('Carlos Mendoza'), findsOneWidget);
      expect(find.text('Limpiar búsqueda'), findsOneWidget);

      // 6. Al pulsar limpiar búsqueda, vuelve al historial general de registros
      await tester.tap(find.text('Limpiar búsqueda'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const ValueKey('recent_history_section')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('history_content')), findsNothing);
    },
  );

  testWidgets(
    'el filtro queda antes de cinco tarjetas y el historial permite desplazarse',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final patientRepo = _ImmediatePatientSearchRepo([]);
      final catalogRepo = _FakeCatalogRepo();
      final sessionManager = FakeSessionManager('token-test');
      final api = ApiClient(
        baseUrl: 'https://api.test',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/attention-history');
          expect(request.url.queryParameters['page'], '0');
          expect(request.url.queryParameters['from'], isNotNull);
          expect(request.url.queryParameters['to'], isNotNull);
          return http.Response(
            jsonEncode({
              'items': [
                for (var i = 0; i < 5; i++)
                  {
                    'id': 'record-$i',
                    'patientId': 'patient-$i',
                    'patientName': 'Paciente $i',
                    'document': 'CC 1234567$i',
                    'date': DateTime(2026, 11, 10 - i).toIso8601String(),
                    'status': 'COMPLETED',
                    'doses': i == 0
                        ? [
                            {
                              'vaccine': 'BCG',
                              'label': 'a1b2c3d4-e5f6-4789-9876-0123456789ab',
                            },
                          ]
                        : [],
                  },
              ],
              'hasNext': true,
            }),
            200,
          );
        }),
      );
      final historyController = HistoryController(
        sessionManager: sessionManager,
        searchPatient: SearchPatient(patientRepo),
        listPatientAttentions: ListPatientAttentions(_FakeAttentionsRepo()),
        listReferenceCatalogs: ListReferenceCatalogs(catalogRepo),
        api: api,
      );
      final patientDetailController = PatientDetailController(
        sessionManager: sessionManager,
        getPatient: GetPatient(patientRepo),
        updateDemographics: UpdatePatientDemographics(patientRepo),
        updateContact: UpdatePatientContact(patientRepo),
        updateMedicalHistories: UpdatePatientMedicalHistories(patientRepo),
        listCountries: ListCountries(catalogRepo),
        listDepartments: ListDepartments(catalogRepo),
        listMunicipalities: ListMunicipalities(catalogRepo),
        listPatientAttentions: ListPatientAttentions(_FakeAttentionsRepo()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistorialPage(
              controller: historyController,
              patientDetailController: patientDetailController,
              offline: online,
              institutionId: 'inst-100',
              userId: 'user-200',
              isAdmin: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('history-record-record-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('history-record-record-4')),
        findsOneWidget,
      );
      expect(find.textContaining('BCG'), findsOneWidget);
      expect(
        find.textContaining('a1b2c3d4-e5f6-4789-9876-0123456789ab'),
        findsNothing,
      );
      final rangeRect = tester.getRect(
        find.byKey(const ValueKey('history-date-range')),
      );
      final firstRecordRect = tester.getRect(
        find.byKey(const ValueKey('history-record-record-0')),
      );
      expect(firstRecordRect.top, greaterThanOrEqualTo(rangeRect.bottom));

      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Siguiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ImmediatePatientSearchRepo implements PatientsRepository {
  _ImmediatePatientSearchRepo(this.patients);
  final List<Patient> patients;

  @override
  Future<List<Patient>> searchByDocument(
    String accessToken, {
    String? documentType,
    required String documentNumber,
  }) async => patients;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AsyncPatientSearchRepo implements PatientsRepository {
  _AsyncPatientSearchRepo(this.searchCompleter);
  final Completer<List<Patient>> searchCompleter;

  @override
  Future<List<Patient>> searchByDocument(
    String accessToken, {
    String? documentType,
    required String documentNumber,
  }) => searchCompleter.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAttentionsRepo implements AttentionsRepository {
  List<Attention> attentions = [];

  @override
  Future<List<Attention>> listByPatient(
    String accessToken,
    String patientId,
  ) async => attentions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCatalogRepo implements CatalogRepository {
  @override
  Future<List<ReferenceCatalog>> listReferenceCatalogs(
    String accessToken,
  ) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
