import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/entities/attention.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/repositories/attentions_repository.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/use_cases/attentions_use_cases.dart';
import 'package:tu_vacuna_pai/features/attentions/presentation/attention_controller.dart';
import 'package:tu_vacuna_pai/features/attentions/presentation/history_controller.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/effective_catalog.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/new_patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient_profile.dart';
import 'package:tu_vacuna_pai/features/patients/domain/repositories/patients_repository.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/create_patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/search_patient.dart';

import '../admin/fake_admin_repository.dart';

void main() {
  late FakePatientsRepository patients;
  late FakeAttentionsRepository attentions;
  late AttentionController controller;

  const online = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['PATIENT_WRITE', 'ATTENTION_CREATE', 'ATTENTION_READ'],
  );
  const offlineLocked = OfflineAccess(
    status: SessionStatus.offlineLocked,
    permissions: ['PATIENT_WRITE', 'ATTENTION_CREATE', 'ATTENTION_READ'],
  );

  final existing = Patient(
    id: 'pat-1',
    documentType: 'CC',
    documentNumber: '12345678',
    firstName: 'Juan',
    lastName: 'Perez',
    birthDate: DateTime(2020, 5, 1),
    sex: 'MALE',
    status: 'ACTIVE',
  );

  setUp(() {
    patients = FakePatientsRepository(results: [existing]);
    attentions = FakeAttentionsRepository();
    controller = AttentionController(
      sessionManager: FakeSessionManager('token-123'),
      searchPatient: SearchPatient(patients),
      createPatient: CreatePatient(patients),
      listEffectiveCatalog: ListEffectiveCatalog(_NoopCatalogRepository()),
      listDepartments: ListDepartments(_NoopCatalogRepository()),
      listMunicipalities: ListMunicipalities(_NoopCatalogRepository()),
      createAttention: CreateAttention(attentions),
      registerDose: RegisterDose(attentions),
      completeAttention: CompleteAttention(attentions),
      cancelAttention: CancelAttention(attentions),
      cancelDose: CancelDose(attentions),
    );
  });

  group('AttentionController', () {
    test('busca y selecciona un paciente', () async {
      await controller.findPatients(
        documentType: 'CC',
        documentNumber: '12345678',
      );

      expect(controller.searchResults, hasLength(1));
      controller.selectPatient(controller.searchResults.first);
      expect(controller.patient?.documentNumber, '12345678');
    });

    test('registra un paciente y lo selecciona', () async {
      final created = await controller.registerPatient(
        offline: online,
        input: const NewPatientInput(
          documentType: 'TI',
          documentNumber: '99',
          firstName: 'Ana',
          lastName: 'Diaz',
          birthDate: '2021-01-02',
          sex: 'FEMALE',
        ),
      );

      expect(created, isNotNull);
      expect(controller.patient?.fullName, 'Ana Diaz');
    });

    test(
      'registra la primera dosis creando la atencion de forma perezosa',
      () async {
        controller.selectPatient(existing);
        expect(controller.attention, isNull);

        final ok = await controller.addDose(
          offline: online,
          vaccineId: 'vac-1',
          doseOptionId: 'dose-1',
          lotNumber: 'L-1',
          observations: 'Control anual',
        );

        expect(ok, isTrue);
        expect(controller.attention?.status, 'DRAFT');
        expect(controller.doses, hasLength(1));
        expect(controller.doses.first.lotNumber, 'L-1');
        expect(attentions.lastObservations, 'Control anual');
        expect(attentions.createAttentionCalls, 1);

        // La segunda dosis usa la misma atencion (no la vuelve a crear).
        await controller.addDose(
          offline: online,
          vaccineId: 'vac-1',
          doseOptionId: 'dose-2',
        );
        expect(controller.doses, hasLength(2));
        expect(attentions.createAttentionCalls, 1);

        expect(await controller.finishAttention(offline: online), isTrue);
        expect(controller.attention?.status, 'COMPLETED');
      },
    );

    test(
      'bloquea el registro de dosis con la ventana offline vencida',
      () async {
        controller.selectPatient(existing);

        final ok = await controller.addDose(
          offline: offlineLocked,
          vaccineId: 'vac-1',
          doseOptionId: 'dose-1',
        );

        expect(ok, isFalse);
        expect(controller.attention, isNull);
        expect(controller.error, isNotNull);
      },
    );

    test('exige un paciente antes de registrar la dosis', () async {
      final ok = await controller.addDose(
        offline: online,
        vaccineId: 'vac-1',
        doseOptionId: 'dose-1',
      );

      expect(ok, isFalse);
      expect(controller.error, isNotNull);
    });

    test('registra la fecha de aplicacion de la dosis', () async {
      controller.selectPatient(existing);

      await controller.addDose(
        offline: online,
        vaccineId: 'vac-1',
        doseOptionId: 'dose-1',
        applicationDate: '2024-01-01T12:00:00Z',
      );

      expect(attentions.lastApplicationDate, '2024-01-01T12:00:00Z');
    });

    test('anula una dosis registrada', () async {
      controller.selectPatient(existing);
      await controller.addDose(
        offline: online,
        vaccineId: 'vac-1',
        doseOptionId: 'dose-1',
      );
      final doseId = controller.doses.first.id;

      final ok = await controller.cancelDoseFlow(
        offline: online,
        doseId: doseId,
        reason: 'registro equivocado',
      );

      expect(ok, isTrue);
      expect(controller.doses.first.isCancelled, isTrue);
    });

    test('anula la atencion con motivo', () async {
      controller.selectPatient(existing);
      await controller.addDose(
        offline: online,
        vaccineId: 'vac-1',
        doseOptionId: 'dose-1',
      );

      final ok = await controller.cancelAttentionFlow(
        offline: online,
        reason: 'duplicada',
      );

      expect(ok, isTrue);
      expect(controller.attention?.status, 'CANCELLED');
    });
  });

  group('HistoryController', () {
    test('carga las atenciones del paciente por documento', () async {
      attentions.historyList = [
        Attention(
          id: 'att-1',
          patientId: 'pat-1',
          professionalId: 'pro-1',
          status: 'COMPLETED',
          version: 1,
          doses: const [],
        ),
      ];
      final history = HistoryController(
        sessionManager: FakeSessionManager('token-123'),
        searchPatient: SearchPatient(patients),
        listPatientAttentions: ListPatientAttentions(attentions),
      );

      await history.loadHistory(documentType: 'CC', documentNumber: '12345678');

      expect(history.patient?.documentNumber, '12345678');
      expect(history.history, hasLength(1));
      expect(history.error, isNull);
    });

    test('sin coincidencias deja el historial vacio', () async {
      final empty = FakePatientsRepository(results: const []);
      final history = HistoryController(
        sessionManager: FakeSessionManager('token-123'),
        searchPatient: SearchPatient(empty),
        listPatientAttentions: ListPatientAttentions(attentions),
      );

      await history.loadHistory(documentType: 'CC', documentNumber: '0');

      expect(history.patient, isNull);
      expect(history.history, isEmpty);
    });
  });
}

class FakePatientsRepository implements PatientsRepository {
  FakePatientsRepository({this.results = const []});

  final List<Patient> results;
  bool createCalled = false;

  @override
  Future<List<Patient>> searchByDocument(
    String accessToken, {
    required String documentType,
    required String documentNumber,
  }) async => results;

  @override
  Future<Patient> create(
    String accessToken, {
    required NewPatientInput input,
    String? operationId,
  }) async {
    createCalled = true;
    return Patient(
      id: 'pat-new',
      documentType: input.documentType,
      documentNumber: input.documentNumber,
      firstName: input.firstName,
      lastName: input.lastName,
      birthDate: DateTime.tryParse(input.birthDate),
      sex: input.sex,
      status: 'ACTIVE',
    );
  }

  @override
  Future<PatientProfile> getById(String accessToken, String patientId) =>
      throw UnimplementedError();

  @override
  Future<PatientProfile> updateDemographics(
    String accessToken,
    String patientId, {
    String? gender,
    String? ethnicity,
    String? educationLevel,
  }) => throw UnimplementedError();

  @override
  Future<PatientProfile> updateContact(
    String accessToken,
    String patientId, {
    required List<NewPatientContact> contacts,
    required List<NewPatientAddress> addresses,
  }) => throw UnimplementedError();

  @override
  Future<PatientProfile> updateMedicalHistories(
    String accessToken,
    String patientId,
    List<NewPatientMedicalHistory> histories,
  ) => throw UnimplementedError();
}

class FakeAttentionsRepository implements AttentionsRepository {
  final List<AppliedDose> registered = [];
  List<Attention> historyList = const [];
  String status = 'DRAFT';
  int createAttentionCalls = 0;
  String? lastObservations;
  String? lastApplicationDate;

  @override
  Future<Attention> createAttention(
    String accessToken, {
    required String patientId,
    String? observations,
    String? operationId,
  }) async {
    createAttentionCalls++;
    lastObservations = observations;
    return Attention(
      id: 'att-1',
      patientId: patientId,
      professionalId: 'pro-1',
      status: 'DRAFT',
      version: 0,
      doses: const [],
    );
  }

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
    String? operationId,
  }) async {
    lastApplicationDate = applicationDate;
    final dose = AppliedDose(
      id: 'dose-${registered.length}',
      attentionId: attentionId,
      vaccineId: vaccineId,
      vaccineNameSnapshot: 'Influenza',
      vaccineCodeSnapshot: 'INF',
      doseLabelSnapshot: 'Primera dosis',
      status: 'REGISTERED',
      lotNumber: lotNumber,
    );
    registered.add(dose);
    return dose;
  }

  @override
  Future<Attention> cancelAttention(
    String accessToken,
    String attentionId, {
    required String reason,
  }) async => Attention(
    id: attentionId,
    patientId: 'pat-1',
    professionalId: 'pro-1',
    status: 'CANCELLED',
    version: 2,
    doses: List.of(registered),
  );

  @override
  Future<AppliedDose> cancelDose(
    String accessToken,
    String attentionId,
    String doseId, {
    required String reason,
  }) async => AppliedDose(
    id: doseId,
    attentionId: attentionId,
    vaccineId: 'vac-1',
    vaccineNameSnapshot: 'Influenza',
    vaccineCodeSnapshot: 'INF',
    doseLabelSnapshot: 'Primera dosis',
    status: 'CANCELLED',
    cancelledReason: reason,
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
    doses: List.of(registered),
  );

  @override
  Future<List<Attention>> listByPatient(
    String accessToken,
    String patientId,
  ) async => historyList;
}

/// Repositorio de catalogo no usado por el flujo bajo prueba.
class _NoopCatalogRepository implements CatalogRepository {
  @override
  Future<List<EffectiveVaccine>> listEffectiveCatalog(String token) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No usado en el test');
}
