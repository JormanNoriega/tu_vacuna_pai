import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/presentation/widgets/shimmer_loading.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/entities/attention.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/repositories/attentions_repository.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/use_cases/attentions_use_cases.dart';
import 'package:tu_vacuna_pai/features/attentions/presentation/history_controller.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_user.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/effective_catalog.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/geo.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'package:tu_vacuna_pai/features/dashboard/domain/entities/metrics_summary.dart';
import 'package:tu_vacuna_pai/features/dashboard/domain/entities/recent_record_item.dart';
import 'package:tu_vacuna_pai/features/dashboard/domain/repositories/metrics_repository.dart';
import 'package:tu_vacuna_pai/features/dashboard/domain/use_cases/get_metrics_summary.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/metrics_controller.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/new_patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient_profile.dart';
import 'package:tu_vacuna_pai/features/patients/domain/repositories/patients_repository.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/patient_profile_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/search_patient.dart';
import 'package:tu_vacuna_pai/features/patients/presentation/patient_detail_controller.dart';

import '../admin/fake_admin_repository.dart';

void main() {
  final user = AuthUser(
    id: 'user-1',
    email: 'vacunador@hospital.com',
    name: 'Maria Gomez',
    roles: const ['VACCINATOR'],
    permissions: const ['ATTENTION_CREATE', 'ATTENTION_READ', 'PATIENT_READ'],
    institution: const InstitutionProfile(
      id: 'inst-1',
      code: 'HOSP-1',
      name: 'Hospital Central',
    ),
    offlineWindowHours: 72,
    lastOnlineValidation: DateTime(2026, 1, 1),
  );

  testWidgets('Dashboard muestra Skeleton con Shimmer en stats y registros recientes en carga inicial y en reload', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final summaryCompleter = Completer<MetricsSummary>();
    final recordsCompleter = Completer<List<RecentRecordItem>>();
    final repo = _AsyncMetricsRepository(summaryCompleter, recordsCompleter);

    final metricsController = MetricsController(
      sessionManager: FakeSessionManager('token-abc'),
      getSummary: GetMetricsSummary(repo),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          user: user,
          onSignOut: () {},
          sessionStatus: SessionStatus.signedIn,
          metricsController: metricsController,
        ),
      ),
    );

    // 1. Estado de carga inicial: debe mostrar el skeleton con Shimmer
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('stats_skeleton')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent_records_skeleton')), findsOneWidget);
    expect(find.byType(ShimmerLoading), findsWidgets);

    // 2. Simulamos la llegada de datos desde el backend
    summaryCompleter.complete(const MetricsSummary(patientsAttended: 15, dosesApplied: 24));
    recordsCompleter.complete([
      RecentRecordItem(
        id: 'rec-1',
        patientId: 'pat-1',
        patientName: 'Pedro Ramirez',
        vaccineName: 'Influenza Estacional',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    ]);

    // 3. Transición AnimatedSwitcher (300ms)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Skeleton desaparece y se ven los datos reales
    expect(find.byKey(const ValueKey('stats_skeleton')), findsNothing);
    expect(find.byKey(const ValueKey('recent_records_skeleton')), findsNothing);

    expect(find.text('15'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('Pedro Ramirez'), findsOneWidget);
    expect(find.text('Influenza Estacional'), findsOneWidget);

    // 4. Simulamos un reload (Pull-to-refresh) cuando ya existen datos
    final reloadSummaryCompleter = Completer<MetricsSummary>();
    final reloadRecordsCompleter = Completer<List<RecentRecordItem>>();
    repo.summaryCompleter = reloadSummaryCompleter;
    repo.recordsCompleter = reloadRecordsCompleter;

    unawaited(metricsController.load(
      institutionId: 'inst-1',
      offline: false,
      vaccinatorId: 'user-1',
    ));

    // Durante la recarga debe volver a activarse el efecto shimmer en los KPIs
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('stats_skeleton')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent_records_skeleton')), findsOneWidget);
    expect(find.byType(ShimmerLoading), findsWidgets);

    // 5. Completar recarga con nuevos valores
    reloadSummaryCompleter.complete(const MetricsSummary(patientsAttended: 18, dosesApplied: 30));
    reloadRecordsCompleter.complete([
      RecentRecordItem(
        id: 'rec-2',
        patientId: 'pat-2',
        patientName: 'Lucia Fernandez',
        vaccineName: 'Polio Oral',
        timestamp: DateTime.now(),
      ),
    ]);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Los datos nuevos se muestran correctamente
    expect(find.byKey(const ValueKey('stats_skeleton')), findsNothing);
    expect(find.byKey(const ValueKey('recent_records_skeleton')), findsNothing);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Lucia Fernandez'), findsOneWidget);
  });

  testWidgets('Cambiar de pestaña y volver a Inicio conserva los KPIs en memoria sin re-cargar ni hacer shimmer', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final summaryCompleter = Completer<MetricsSummary>();
    final recordsCompleter = Completer<List<RecentRecordItem>>();
    final repo = _AsyncMetricsRepository(summaryCompleter, recordsCompleter);

    final metricsController = MetricsController(
      sessionManager: FakeSessionManager('token-abc'),
      getSummary: GetMetricsSummary(repo),
    );

    final patientRepo = _StubPatientsRepository();
    final attentionsRepo = _StubAttentionsRepository();
    final catalogRepo = _StubCatalogRepository();

    final historyController = HistoryController(
      sessionManager: FakeSessionManager('token-abc'),
      searchPatient: SearchPatient(patientRepo),
      listPatientAttentions: ListPatientAttentions(attentionsRepo),
      listReferenceCatalogs: ListReferenceCatalogs(catalogRepo),
    );
    final patientDetailController = PatientDetailController(
      sessionManager: FakeSessionManager('token-abc'),
      getPatient: GetPatient(patientRepo),
      updateDemographics: UpdatePatientDemographics(patientRepo),
      updateContact: UpdatePatientContact(patientRepo),
      updateMedicalHistories: UpdatePatientMedicalHistories(patientRepo),
      listCountries: ListCountries(catalogRepo),
      listDepartments: ListDepartments(catalogRepo),
      listMunicipalities: ListMunicipalities(catalogRepo),
      listPatientAttentions: ListPatientAttentions(attentionsRepo),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          user: user,
          onSignOut: () {},
          sessionStatus: SessionStatus.signedIn,
          metricsController: metricsController,
          historyController: historyController,
          patientDetailController: patientDetailController,
        ),
      ),
    );

    // Carga inicial
    await tester.pump(const Duration(milliseconds: 50));
    summaryCompleter.complete(const MetricsSummary(patientsAttended: 15, dosesApplied: 24));
    recordsCompleter.complete([]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('15'), findsOneWidget);
    expect(find.byKey(const ValueKey('stats_skeleton')), findsNothing);

    // Cambiar a la pestaña "Historial"
    await tester.tap(find.text('Historial').first);
    await tester.pumpAndSettle();

    // Volver a la pestaña "Inicio"
    await tester.tap(find.text('Inicio').first);
    await tester.pump(const Duration(milliseconds: 50));

    // Los KPIs deben permanecer intactos en memoria: NUNCA deben mostrar skeleton/shimmer
    expect(find.byKey(const ValueKey('stats_skeleton')), findsNothing);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
  });
}

class _AsyncMetricsRepository implements MetricsRepository {
  _AsyncMetricsRepository(this.summaryCompleter, this.recordsCompleter);

  Completer<MetricsSummary> summaryCompleter;
  Completer<List<RecentRecordItem>> recordsCompleter;

  @override
  Future<MetricsSummary> localSummary(String institutionId, {String? vaccinatorId}) async =>
      MetricsSummary.empty;

  @override
  Future<List<RecentRecordItem>> localRecentRecords(String institutionId, {String? vaccinatorId, int limit = 5}) async =>
      const [];

  @override
  Future<MetricsSummary> remoteSummary(String accessToken, {String? vaccinatorId}) =>
      summaryCompleter.future;

  @override
  Future<List<RecentRecordItem>> remoteRecentRecords(String accessToken, {int limit = 5}) =>
      recordsCompleter.future;
}

class _StubPatientsRepository implements PatientsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAttentionsRepository implements AttentionsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubCatalogRepository implements CatalogRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
