import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_engine.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_operation.dart';
import 'package:tu_vacuna_pai/core/synchronization/sync_status_controller.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_user.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/repositories/attentions_repository.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/use_cases/attentions_use_cases.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/geo.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'package:tu_vacuna_pai/features/dashboard/domain/entities/metrics_summary.dart';
import 'package:tu_vacuna_pai/features/dashboard/domain/entities/recent_record_item.dart';
import 'package:tu_vacuna_pai/features/dashboard/domain/repositories/metrics_repository.dart';
import 'package:tu_vacuna_pai/features/dashboard/domain/use_cases/get_metrics_summary.dart';
import 'package:tu_vacuna_pai/features/dashboard/presentation/metrics_controller.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient_profile.dart';
import 'package:tu_vacuna_pai/features/patients/domain/repositories/patients_repository.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/patient_profile_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/presentation/patient_detail_controller.dart';
import 'package:tu_vacuna_pai/features/reports/domain/entities/report_summary.dart';
import 'package:tu_vacuna_pai/features/reports/domain/repositories/reports_repository.dart';
import 'package:tu_vacuna_pai/features/reports/presentation/export_report_controller.dart';
import 'package:tu_vacuna_pai/features/reports/presentation/pages/export_report_page.dart';

import '../admin/fake_admin_repository.dart';

class FakeReportsRepository implements ReportsRepository {
  FakeReportsRepository({
    this.summary = const ReportSummary(
      patientsCount: 12,
      dosesCount: 15,
      vaccineTypesCount: 4,
    ),
  });

  ReportSummary summary;
  DateTime? lastFrom;
  DateTime? lastTo;
  String? lastFormat;
  bool exportCalled = false;

  @override
  Future<ReportSummary> fetchSummary(
    String accessToken, {
    required DateTime from,
    required DateTime to,
    String? institutionId,
  }) async {
    lastFrom = from;
    lastTo = to;
    return summary;
  }

  @override
  Future<Uint8List> exportReport(
    String accessToken, {
    required DateTime from,
    required DateTime to,
    String format = 'xlsx',
  }) async {
    exportCalled = true;
    lastFormat = format;
    return Uint8List.fromList([1, 2, 3, 4]);
  }
}

class FakeSyncStatusController extends ChangeNotifier
    implements SyncStatusController {
  @override
  int get pendingCount => 0;

  @override
  bool get syncing => false;

  @override
  SyncOutcome? get lastOutcome => null;

  @override
  bool get hasPending => false;

  @override
  Future<void> refresh() async {}

  @override
  Future<List<OutboxEntry>> pendingEntries() async => [];

  @override
  Future<SyncOutcome> syncNow() async =>
      const SyncOutcome(pushed: 0, pulled: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeReportsRepository repository;
  late FakeSessionManager sessionManager;
  late ExportReportController controller;

  final adminUser = AuthUser(
    id: 'usr-admin',
    email: 'admin@hospital.com',
    name: 'Admin Hospital',
    institution: const InstitutionProfile(
      id: 'inst-1',
      code: 'HOSP-01',
      name: 'Hospital Central',
    ),
    roles: const ['ADMIN_INSTITUTION'],
    permissions: const ['USER_MANAGE'],
    offlineWindowHours: 24,
    lastOnlineValidation: DateTime.now(),
  );

  final vaccinatorUser = AuthUser(
    id: 'usr-vac',
    email: 'vac@hospital.com',
    name: 'Enfermera Vacunadora',
    institution: const InstitutionProfile(
      id: 'inst-1',
      code: 'HOSP-01',
      name: 'Hospital Central',
    ),
    roles: const ['VACCINATOR'],
    permissions: const [
      'ATTENTION_CREATE',
      'ATTENTION_READ',
      'PATIENT_READ',
      'PATIENT_WRITE',
      'CATALOG_READ',
    ],
    offlineWindowHours: 24,
    lastOnlineValidation: DateTime.now(),
  );

  final superAdminUser = AuthUser(
    id: 'usr-super',
    email: 'super@minsalud.gov.co',
    name: 'Super Admin',
    institution: const InstitutionProfile(
      id: 'inst-minsalud',
      code: 'MINSALUD',
      name: 'Ministerio de Salud',
    ),
    roles: const ['SUPER_ADMIN'],
    permissions: const ['GLOBAL_ADMIN'],
    offlineWindowHours: 24,
    lastOnlineValidation: DateTime.now(),
  );

  setUp(() {
    repository = FakeReportsRepository();
    sessionManager = FakeSessionManager('valid-token');
    controller = ExportReportController(
      sessionManager: sessionManager,
      repository: repository,
    );
  });

  group('ExportReportController', () {
    test('carga el resumen correctamente y actualiza metricas', () async {
      expect(controller.summary.patientsCount, 0);
      await controller.loadSummary(institutionId: 'inst-1');
      expect(controller.summary.patientsCount, 12);
      expect(controller.summary.dosesCount, 15);
      expect(controller.summary.vaccineTypesCount, 4);
    });

    test('actualiza fecha de inicio y fin recargando el resumen', () async {
      final newStart = DateTime(2026, 8, 1);
      final newEnd = DateTime(2026, 8, 15);

      controller.setStartDate(newStart, institutionId: 'inst-1');
      expect(controller.startDate, newStart);

      controller.setEndDate(newEnd, institutionId: 'inst-1');
      expect(controller.endDate, newEnd);

      await Future<void>.delayed(Duration.zero);
      expect(repository.lastTo?.year, 2026);
      expect(repository.lastTo?.month, 8);
      expect(repository.lastTo?.day, 15);
    });
  });

  group('ExportReportPage UI & Permissions', () {
    testWidgets(
      'Hospital Admin ve banner, rango de fechas, resumen y boton de exportar',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ExportReportPage(user: adminUser, controller: controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Exportar Registros'), findsOneWidget);
        expect(find.text('FORMATO DE EXPORTACIÓN'), findsOneWidget);
        expect(find.text('Excel (.xlsx)'), findsOneWidget);
        expect(find.text('CSV (.csv)'), findsOneWidget);
        expect(
          find.textContaining('formato Excel con encabezados categorizados'),
          findsOneWidget,
        );
        expect(find.text('RANGO DE FECHAS'), findsOneWidget);
        expect(find.text('Fecha de inicio'), findsOneWidget);
        expect(find.text('Fecha de fin'), findsOneWidget);
        expect(find.text('Resumen'), findsOneWidget);
        expect(find.text('PACIENTES EN EL RANGO'), findsOneWidget);
        expect(find.text('DOSIS APLICADAS'), findsOneWidget);
        expect(find.text('TIPOS DE VACUNAS USADAS'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('Exportar y Compartir Excel'), findsOneWidget);
      },
    );

    testWidgets('Cambio interactivo entre formato Excel y CSV es dinamico', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExportReportPage(user: adminUser, controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente en Excel
      expect(
        find.text(
          'Exporta los registros de vacunación en formato Excel con encabezados categorizados y colores profesionales.',
        ),
        findsOneWidget,
      );
      expect(find.text('Exportar y Compartir Excel'), findsOneWidget);

      // Tocar CSV
      await tester.tap(find.text('CSV (.csv)'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Exporta los registros de vacunación en formato CSV con valores delimitados por comas.',
        ),
        findsOneWidget,
      );
      expect(find.text('Exportar y Compartir CSV'), findsOneWidget);

      // Tocar nuevamente Excel
      await tester.tap(find.text('Excel (.xlsx)'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Exporta los registros de vacunación en formato Excel con encabezados categorizados y colores profesionales.',
        ),
        findsOneWidget,
      );
      expect(find.text('Exportar y Compartir Excel'), findsOneWidget);
    });

    testWidgets('Vacunador/Enfermera sin permiso ve acceso restringido', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExportReportPage(user: vaccinatorUser, controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acceso Restringido'), findsOneWidget);
      expect(find.text('Acceso no autorizado'), findsOneWidget);
      expect(
        find.text(
          'Esta vista solo esta disponible para los administradores del hospital.',
        ),
        findsOneWidget,
      );
      expect(find.text('Exportar y Compartir Excel'), findsNothing);
    });
  });

  group('DashboardPage Quick Action Visibility', () {
    testWidgets(
      'Hospital Admin con USER_MANAGE ve solo Inventario y Exportar en Centro de Accion',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DashboardPage(
              user: adminUser,
              onSignOut: () {},
              exportReportController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Exportar'), findsOneWidget);
        expect(find.text('Descargar datos'), findsOneWidget);
        expect(find.text('Inventario'), findsWidgets);
        // No debe ver Nueva Atencion en el centro de accion
        expect(find.text('Nueva Atención'), findsNothing);
      },
    );

    testWidgets(
      'Centro de Accion muestra Nueva Atención, Historial e Inventario para el vacunador (sin Exportar)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DashboardPage(
              user: vaccinatorUser,
              onSignOut: () {},
              exportReportController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nueva Atención'), findsOneWidget);
        expect(find.text('Historial'), findsWidgets);
        expect(find.text('Inventario'), findsWidgets);
        expect(find.text('Exportar'), findsNothing);
      },
    );
  });

  group('Sync Status Badge & Pending Card Visibility by Role', () {
    testWidgets(
      'Vacunador online sin cambios oculta el boton de sync y conserva su resumen',
      (tester) async {
        final syncController = FakeSyncStatusController();
        await tester.pumpWidget(
          MaterialApp(
            home: DashboardPage(
              user: vaccinatorUser,
              onSignOut: () {},
              syncStatusController: syncController,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('Todo sincronizado.'), findsNothing);
        expect(find.text('Pendientes de sync'), findsOneWidget);
      },
    );

    testWidgets(
      'Hospital Admin (no realiza atenciones) NO ve el boton de sync ni pendientes',
      (tester) async {
        final syncController = FakeSyncStatusController();
        await tester.pumpWidget(
          MaterialApp(
            home: DashboardPage(
              user: adminUser,
              onSignOut: () {},
              syncStatusController: syncController,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('Todo sincronizado.'), findsNothing);
        expect(find.text('Pendientes de sync'), findsNothing);
      },
    );

    testWidgets('Super Admin (no realiza atenciones) NO ve el boton de sync', (
      tester,
    ) async {
      final syncController = FakeSyncStatusController();
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardPage(
            user: superAdminUser,
            onSignOut: () {},
            syncStatusController: syncController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Todo sincronizado.'), findsNothing);
    });
  });

  group('Recent Records Navigation and Stats Layout', () {
    testWidgets(
      'Tocar un registro reciente abre la ficha tecnica del paciente',
      (tester) async {
        final metricsRepo = _TestMetricsRepository();
        final metricsController = MetricsController(
          sessionManager: FakeSessionManager('token-test'),
          getSummary: GetMetricsSummary(metricsRepo),
        );

        final patientRepo = _TestPatientsRepository();
        final patientDetailController = PatientDetailController(
          sessionManager: FakeSessionManager('token-test'),
          getPatient: GetPatient(patientRepo),
          updateDemographics: UpdatePatientDemographics(patientRepo),
          updateContact: UpdatePatientContact(patientRepo),
          updateMedicalHistories: UpdatePatientMedicalHistories(patientRepo),
          listCountries: ListCountries(_TestCatalogRepository()),
          listDepartments: ListDepartments(_TestCatalogRepository()),
          listMunicipalities: ListMunicipalities(_TestCatalogRepository()),
          listPatientAttentions: ListPatientAttentions(
            _TestAttentionsRepository(),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DashboardPage(
              user: vaccinatorUser,
              onSignOut: () {},
              metricsController: metricsController,
              patientDetailController: patientDetailController,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verificar que el registro reciente aparece
        expect(find.text('Julio Rios'), findsOneWidget);
        expect(find.text('COVID-19'), findsOneWidget);

        // Desplazarse hasta el registro reciente y tocarlo
        await tester.ensureVisible(find.text('Julio Rios'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Julio Rios'));
        await tester.pumpAndSettle();

        // Debe abrir la ficha técnica (PatientDetailPage)
        expect(find.text('Ficha del paciente'), findsOneWidget);
      },
    );

    testWidgets(
      'Hospital Admin NO ve la seccion de ultimos registros recientes',
      (tester) async {
        final metricsRepo = _TestMetricsRepository();
        final metricsController = MetricsController(
          sessionManager: FakeSessionManager('token-test'),
          getSummary: GetMetricsSummary(metricsRepo),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DashboardPage(
              user: adminUser,
              onSignOut: () {},
              metricsController: metricsController,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Últimos registros'), findsNothing);
        expect(find.text('Julio Rios'), findsNothing);
      },
    );
  });
}

class _TestMetricsRepository implements MetricsRepository {
  @override
  Future<MetricsSummary> remoteSummary(
    String token, {
    String? vaccinatorId,
  }) async => const MetricsSummary(patientsAttended: 10, dosesApplied: 15);

  @override
  Future<MetricsSummary> localSummary(
    String institutionId, {
    String? vaccinatorId,
  }) async => const MetricsSummary(patientsAttended: 10, dosesApplied: 15);

  @override
  Future<List<RecentRecordItem>> remoteRecentRecords(
    String token, {
    int limit = 5,
  }) async => [
    RecentRecordItem(
      id: 'rec-1',
      patientId: 'pat-xyz',
      patientName: 'Julio Rios',
      vaccineName: 'COVID-19',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  @override
  Future<List<RecentRecordItem>> localRecentRecords(
    String institutionId, {
    String? vaccinatorId,
    int limit = 5,
  }) async => [
    RecentRecordItem(
      id: 'rec-1',
      patientId: 'pat-xyz',
      patientName: 'Julio Rios',
      vaccineName: 'COVID-19',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];
}

class _TestPatientsRepository implements PatientsRepository {
  @override
  Future<PatientProfile> getById(String accessToken, String patientId) async =>
      PatientProfile(
        patient: Patient(
          id: patientId,
          documentType: 'CC',
          documentNumber: '12345678',
          firstName: 'Julio',
          lastName: 'Rios',
          birthDate: DateTime(1990, 5, 20),
          sex: 'MALE',
          status: 'ACTIVE',
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _TestCatalogRepository implements CatalogRepository {
  @override
  Future<List<GeoDepartment>> listDepartments(String token) async => const [];

  @override
  Future<List<GeoMunicipality>> listMunicipalities(
    String token,
    String departmentId,
  ) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _TestAttentionsRepository implements AttentionsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
