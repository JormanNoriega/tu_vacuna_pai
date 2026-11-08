import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/entities/attention.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/repositories/attentions_repository.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/use_cases/attentions_use_cases.dart';
import 'package:tu_vacuna_pai/features/attentions/presentation/attention_controller.dart';
import 'package:tu_vacuna_pai/features/attentions/presentation/pages/nueva_atencion_page.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/auth_user.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/catalog_entities.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/effective_catalog.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/geo.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/new_patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/repositories/patients_repository.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/create_patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/search_patient.dart';

import '../admin/fake_admin_repository.dart';

void main() {
  late _FakePatientsRepository patientsRepo;
  late _FakeAttentionsRepository attentionsRepo;
  late _FakeCatalogRepository catalogRepo;
  late AttentionController controller;

  final user = AuthUser(
    id: 'usr-1',
    name: 'Ana Vacunadora',
    email: 'ana@hospital.com',
    institution: const InstitutionProfile(
      id: 'inst-1',
      code: 'HOSP-1',
      name: 'Hospital Central',
    ),
    roles: const ['VACCINATOR'],
    permissions: const ['PATIENT_WRITE', 'ATTENTION_CREATE', 'ATTENTION_READ'],
    offlineWindowHours: 72,
    lastOnlineValidation: DateTime(2026, 11, 1),
  );

  const offline = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['PATIENT_WRITE', 'ATTENTION_CREATE', 'ATTENTION_READ'],
  );

  setUp(() {
    patientsRepo = _FakePatientsRepository();
    attentionsRepo = _FakeAttentionsRepository();
    catalogRepo = _FakeCatalogRepository();

    controller = AttentionController(
      sessionManager: FakeSessionManager('token-123'),
      searchPatient: SearchPatient(patientsRepo),
      createPatient: CreatePatient(patientsRepo),
      listEffectiveCatalog: ListEffectiveCatalog(catalogRepo),
      listCountries: ListCountries(catalogRepo),
      listDepartments: ListDepartments(catalogRepo),
      listMunicipalities: ListMunicipalities(catalogRepo),
      listReferenceCatalogs: ListReferenceCatalogs(catalogRepo),
      listInsurers: ListInsurers(catalogRepo),
      createAttention: CreateAttention(attentionsRepo),
      updateAttention: UpdateAttention(attentionsRepo),
      registerDose: RegisterDose(attentionsRepo),
      completeAttention: CompleteAttention(attentionsRepo),
      cancelAttention: CancelAttention(attentionsRepo),
      cancelDose: CancelDose(attentionsRepo),
    );
  });

  Widget createTestWidget({
    VoidCallback? onFinished,
    ValueChanged<bool>? onSubmittingChanged,
  }) {
    return MaterialApp(
      home: NuevaAtencionPage(
        user: user,
        controller: controller,
        offline: offline,
        onFinished: onFinished,
        onSubmittingChanged: onSubmittingChanged,
      ),
    );
  }

  group('NuevaAtencionPage Wizard (4 Pasos estilo Vistas Anteriores)', () {
    testWidgets('renderiza paso 1 con indicador de progreso y datos basicos', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Registro de Vacunación'), findsOneWidget);
      expect(find.text('Paso 1 de 4'), findsOneWidget);
      expect(find.text('Datos Básicos del Paciente'), findsOneWidget);
      expect(find.text('Fecha de Atención *'), findsOneWidget);
      expect(find.text('Tipo de Documento *'), findsOneWidget);
      expect(find.text('Número de Identificación *'), findsOneWidget);
      expect(find.text('Primer Nombre *'), findsOneWidget);
      expect(find.text('Primer Apellido *'), findsOneWidget);
      expect(find.text('Fecha de Nacimiento *'), findsOneWidget);
      expect(find.text('¿Esquema Completo? *'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
    });

    testWidgets('valida campos requeridos del paso 1 antes de avanzar', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      // Debe permanecer en paso 1 y mostrar mensajes de validación
      expect(find.text('Paso 1 de 4'), findsOneWidget);
      expect(find.text('Ingresa el número de identificación'), findsOneWidget);
      expect(find.text('Primer nombre requerido'), findsOneWidget);
      expect(find.text('Primer apellido requerido'), findsOneWidget);
    });

    testWidgets('avanza al paso 2 y permite regresar al paso 1 con Anterior', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Llenar campos requeridos del paso 1
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Número de Identificación *'),
        '1020304050',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Primer Nombre *'),
        'Carlos',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Primer Apellido *'),
        'Gomez',
      );

      // Simular selección de fecha de nacimiento
      await tester.tap(find.text('Seleccione la fecha de nacimiento'));
      await tester.pumpAndSettle();

      // Confirmar en el date picker
      final confirmBtn = find.text('ACEPTAR').evaluate().isNotEmpty
          ? find.text('ACEPTAR')
          : find.text('OK');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Tocar Siguiente
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      // Debe estar en el Paso 2
      expect(find.text('Paso 2 de 4'), findsOneWidget);
      expect(find.text('Datos Adicionales'), findsOneWidget);
      expect(find.text('1. Datos Demográficos'), findsOneWidget);
      expect(find.text('2. Origen y Migración'), findsOneWidget);
      expect(find.text('Anterior'), findsOneWidget);

      // Tocar Anterior
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();

      // Debe regresar al Paso 1 conservando los datos
      expect(find.text('Paso 1 de 4'), findsOneWidget);
      expect(find.text('1020304050'), findsOneWidget);
      expect(find.text('Carlos'), findsOneWidget);
    });

    testWidgets(
      'carga automaticamente los datos de un paciente existente si se encuentra',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final existing = Patient(
          id: 'pat-99',
          documentType: 'CC',
          documentNumber: '1122334455',
          firstName: 'Mariana',
          lastName: 'Lopez',
          birthDate: DateTime(2015, 6, 10),
          sex: 'FEMALE',
          status: 'ACTIVE',
        );
        patientsRepo.patients.add(existing);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Ingresar el número de identificación que dispara el debounce
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Número de Identificación *'),
          '1122334455',
        );

        // Esperar debounce y resolución del Future
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump();
        await tester.pumpAndSettle();

        // Debe aparecer el diálogo "Paciente Encontrado"
        expect(find.text('Paciente Encontrado'), findsOneWidget);
        expect(find.textContaining('Mariana Lopez'), findsOneWidget);

        // Tocar "Sí, cargar"
        await tester.tap(find.text('Sí, cargar'));
        await tester.pumpAndSettle();

        // Debe haber cargado el paciente y avanzado directamente al Paso 3 de vacunas
        expect(controller.patient?.firstName, 'Mariana');
        expect(find.text('Paso 3 de 4'), findsOneWidget);
      },
    );

    testWidgets(
      'completa el flujo de atencion e invoca onFinished para redirigir a Inicio',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;

        bool finishedCalled = false;
        final submittingEvents = <bool>[];
        await tester.pumpWidget(
          createTestWidget(
            onFinished: () => finishedCalled = true,
            onSubmittingChanged: (val) => submittingEvents.add(val),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Llenar Paso 1
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Número de Identificación *'),
          '99887766',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primer Nombre *'),
          'Lucia',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primer Apellido *'),
          'Perez',
        );
        await tester.tap(find.text('Seleccione la fecha de nacimiento'));
        await tester.pumpAndSettle();
        final confirmBtn = find.text('ACEPTAR').evaluate().isNotEmpty
            ? find.text('ACEPTAR')
            : find.text('OK');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Siguiente -> Paso 2
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('Paso 2 de 4'), findsOneWidget);

        // Seleccionar Sexo en Paso 2
        await tester.tap(find.text('Mujer'));
        await tester.pumpAndSettle();

        // Seleccionar Nivel Educativo en Paso 2 (Dropdown)
        await tester.tap(find.text('Seleccione escolaridad'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Primaria').last);
        await tester.pumpAndSettle();

        // Siguiente -> Paso 3
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('Paso 3 de 4'), findsOneWidget);

        // Configurar y confirmar una dosis en Paso 3
        if (find.text('Ver todas').evaluate().isNotEmpty) {
          await tester.tap(find.text('Ver todas'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('BCG'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Única'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Número de Lote *'),
          'LOT-999',
        );
        await tester.tap(find.text('Confirmar esta dosis'));
        await tester.pumpAndSettle(const Duration(milliseconds: 350));

        // Siguiente -> Paso 4
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        expect(find.text('Paso 4 de 4'), findsOneWidget);
        expect(find.text('Confirmar Atención'), findsOneWidget);

        // Confirmar atención
        await tester.tap(find.text('Confirmar Atención'));
        await tester.pumpAndSettle();

        // Debe haber invocado onFinished y notificado cambio de estado submitting
        expect(finishedCalled, isTrue);
        expect(submittingEvents, contains(true));
        expect(submittingEvents.last, isFalse);
      },
    );

    testWidgets(
      'descarta dosis seleccionadas que no fueron confirmadas explicitamente con el boton al avanzar',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // 1. Llenar Paso 1
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Número de Identificación *'),
          '11223344',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primer Nombre *'),
          'Carlos',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primer Apellido *'),
          'Gomez',
        );
        await tester.tap(find.text('Seleccione la fecha de nacimiento'));
        await tester.pumpAndSettle();
        final confirmBtn = find.text('ACEPTAR').evaluate().isNotEmpty
            ? find.text('ACEPTAR')
            : find.text('OK');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Siguiente -> Paso 2
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        // Seleccionar Sexo en Paso 2
        await tester.tap(find.text('Hombre'));
        await tester.pumpAndSettle();

        // Siguiente -> Paso 3
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('Paso 3 de 4'), findsOneWidget);

        // Mostrar todas las vacunas para ver el catálogo completo
        if (find.text('Ver todas').evaluate().isNotEmpty) {
          await tester.tap(find.text('Ver todas'));
          await tester.pumpAndSettle();
        }

        // Expandir tarjeta de vacuna BCG
        await tester.tap(find.text('BCG'));
        await tester.pumpAndSettle();

        // Seleccionar la dosis 'Única' de BCG para abrir el menú pero NO confirmar
        final chipDosis = find.text('Única');
        expect(chipDosis, findsOneWidget);
        await tester.tap(chipDosis);
        await tester.pumpAndSettle();

        // El menú de la dosis se abre mostrando el botón "Confirmar esta dosis"
        expect(find.text('Confirmar esta dosis'), findsOneWidget);

        // El usuario NO confirma y hace tap en "Siguiente" directamente
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        // Debe bloquear el avance y mostrar advertencia porque la dosis no confirmada fue descartada
        expect(
          find.text('Debes registrar y confirmar al menos una vacuna antes de continuar.'),
          findsOneWidget,
        );
        // Debe mantenerse en el Paso 3
        expect(find.text('Paso 3 de 4'), findsOneWidget);
        expect(find.text('Paso 4 de 4'), findsNothing);
      },
    );

    testWidgets(
      'al presionar Confirmar esta dosis se marca como completada, cierra el formulario y se incluye en la revision',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // 1. Llenar Paso 1
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Número de Identificación *'),
          '55667788',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primer Nombre *'),
          'Ana',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Primer Apellido *'),
          'Ruiz',
        );
        await tester.tap(find.text('Seleccione la fecha de nacimiento'));
        await tester.pumpAndSettle();
        final confirmBtn = find.text('ACEPTAR').evaluate().isNotEmpty
            ? find.text('ACEPTAR')
            : find.text('OK');
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Siguiente -> Paso 2
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        // Seleccionar Sexo en Paso 2
        await tester.tap(find.text('Mujer'));
        await tester.pumpAndSettle();

        // Seleccionar Nivel Educativo en Paso 2 (Dropdown)
        await tester.tap(find.text('Seleccione escolaridad'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Primaria').last);
        await tester.pumpAndSettle();

        // Siguiente -> Paso 3
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
        expect(find.text('Paso 3 de 4'), findsOneWidget);

        // Mostrar todas las vacunas para ver el catálogo completo
        if (find.text('Ver todas').evaluate().isNotEmpty) {
          await tester.tap(find.text('Ver todas'));
          await tester.pumpAndSettle();
        }

        // Expandir tarjeta de vacuna BCG
        await tester.tap(find.text('BCG'));
        await tester.pumpAndSettle();

        // Seleccionar la dosis 'Única' de BCG
        await tester.tap(find.text('Única'));
        await tester.pumpAndSettle();

        // Ingresar Lote
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Número de Lote *'),
          'LOT-12345',
        );
        await tester.pumpAndSettle();

        // Confirmar la dosis
        await tester.tap(find.text('Confirmar esta dosis'));
        await tester.pumpAndSettle();

        // El formulario de la dosis debe cerrarse (soltarse)
        expect(find.text('Confirmar esta dosis'), findsNothing);

        // Siguiente -> Paso 4
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();

        // No debe mostrar diálogo de "Continuar sin vacunas"
        expect(find.text('¿Continuar sin vacunas?'), findsNothing);
        expect(find.text('Paso 4 de 4'), findsOneWidget);

        // En la revisión debe aparecer la vacuna BCG con su dosis confirmada y el lote ingresado
        expect(find.text('BCG - Única'), findsOneWidget);
        expect(find.text('LOT-12345'), findsOneWidget);
      },
    );
  });
}

class _FakePatientsRepository implements PatientsRepository {
  final List<Patient> patients = [];

  @override
  Future<List<Patient>> searchByDocument(
    String accessToken, {
    required String documentType,
    required String documentNumber,
  }) async {
    return patients
        .where(
          (p) =>
              p.documentType == documentType &&
              p.documentNumber == documentNumber,
        )
        .toList();
  }

  @override
  Future<Patient> create(
    String accessToken, {
    required NewPatientInput input,
    String? operationId,
    OfflineAccess? offline,
  }) async {
    final pat = Patient(
      id: 'pat-${patients.length + 1}',
      documentType: input.documentType,
      documentNumber: input.documentNumber,
      firstName: input.firstName,
      lastName: input.lastName,
      birthDate: DateTime.tryParse(input.birthDate),
      sex: input.sex,
      status: 'ACTIVE',
    );
    patients.add(pat);
    return pat;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAttentionsRepository implements AttentionsRepository {
  @override
  Future<Attention> createAttention(
    String accessToken, {
    required String patientId,
    String? observations,
    String? attentionDate,
    double? latitude,
    double? longitude,
    bool? completeScheme,
    bool? paiwebRegistered,
    String? paiwebNotRegisteredReason,
    String? operationId,
  }) async => Attention(
    id: 'att-1',
    patientId: patientId,
    professionalId: 'pro-1',
    status: 'IN_PROGRESS',
    version: 1,
    doses: const [],
  );

  @override
  Future<Attention> updateAttention(
    String accessToken,
    String attentionId, {
    required int version,
    String? attentionDate,
    bool? completeScheme,
    bool? paiwebRegistered,
    String? paiwebNotRegisteredReason,
    String? observations,
  }) async => Attention(
    id: attentionId,
    patientId: 'pat-1',
    professionalId: 'pro-1',
    status: 'IN_PROGRESS',
    version: version + 1,
    doses: const [],
  );

  @override
  Future<AppliedDose> registerDose(
    String accessToken,
    String attentionId, {
    required String vaccineId,
    required String doseOptionId,
    String? pneumococcalTypeOptionId,
    String? lotNumber,
    String? applicationDate,
    String? selectedLaboratoryId,
    String? selectedSyringeId,
    String? selectedDropperId,
    String? selectedObservationId,
    String? syringeLot,
    String? diluent,
    int? vialCount,
    String? customObservation,
    String? operationId,
  }) async => AppliedDose(
    id: 'dose-1',
    attentionId: attentionId,
    vaccineId: vaccineId,
    vaccineNameSnapshot: 'BCG',
    vaccineCodeSnapshot: 'BCG',
    doseLabelSnapshot: 'Única',
    lotNumber: lotNumber ?? 'LOT-1',
    status: 'APPLIED',
  );

  @override
  Future<Attention> completeAttention(
    String accessToken,
    String attentionId,
  ) async => Attention(
    id: attentionId,
    patientId: 'pat-1',
    professionalId: 'pro-1',
    status: 'COMPLETED',
    version: 1,
    doses: const [],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCatalogRepository implements CatalogRepository {
  @override
  Future<List<EffectiveVaccine>> listEffectiveCatalog(String token) async => [
    const EffectiveVaccine(
      vaccineId: 'vac-1',
      code: 'BCG',
      name: 'BCG',
      category: 'REGULAR',
      maxDoses: 1,
      version: 1,
      doses: [
        EffectiveOption(
          id: 'd-1',
          fieldType: 'DOSE',
          value: 'UNICA',
          displayName: 'Única',
          sortOrder: 1,
          isDefault: true,
        ),
      ],
      operationalOptions: [],
      pneumococcalTypes: [],
    ),
  ];

  @override
  Future<List<GeoCountry>> listCountries(String token) async => [
    const GeoCountry(id: 'col', code: 'COL', name: 'Colombia'),
  ];

  @override
  Future<List<GeoDepartment>> listDepartments(String token) async => [];

  @override
  Future<List<GeoMunicipality>> listMunicipalities(
    String token,
    String departmentId,
  ) async => [];

  @override
  Future<List<ReferenceCatalog>> listReferenceCatalogs(String token) async => [
    const ReferenceCatalog(
      code: 'document_type',
      name: 'Tipo de documento',
      options: [
        ReferenceOption(
          code: 'CC',
          label: 'Cédula de Ciudadanía',
          sortOrder: 1,
        ),
      ],
    ),
  ];

  @override
  Future<List<HealthInsurer>> listInsurers(String token) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
