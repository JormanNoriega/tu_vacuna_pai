import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/auth/offline_access.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/repositories/attentions_repository.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/use_cases/attentions_use_cases.dart';
import 'package:tu_vacuna_pai/features/auth/domain/entities/session_restore_result.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/effective_catalog.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/geo.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/repositories/catalog_repository.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/use_cases/catalog_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/new_patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/patient_profile.dart';
import 'package:tu_vacuna_pai/features/patients/domain/repositories/patients_repository.dart';
import 'package:tu_vacuna_pai/features/patients/domain/use_cases/patient_profile_use_cases.dart';
import 'package:tu_vacuna_pai/features/patients/presentation/patient_detail_controller.dart';

import '../admin/fake_admin_repository.dart';

void main() {
  late FakePatientsRepository repository;
  late PatientDetailController controller;

  const online = OfflineAccess(
    status: SessionStatus.signedIn,
    permissions: ['PATIENT_WRITE', 'PATIENT_READ'],
  );
  const offlineLocked = OfflineAccess(
    status: SessionStatus.offlineLocked,
    permissions: ['PATIENT_WRITE', 'PATIENT_READ'],
  );

  setUp(() {
    repository = FakePatientsRepository();
    controller = PatientDetailController(
      sessionManager: FakeSessionManager('token-123'),
      getPatient: GetPatient(repository),
      updateDemographics: UpdatePatientDemographics(repository),
      updateContact: UpdatePatientContact(repository),
      updateMedicalHistories: UpdatePatientMedicalHistories(repository),
      listCountries: ListCountries(_NoopCatalogRepository()),
      listDepartments: ListDepartments(_NoopCatalogRepository()),
      listMunicipalities: ListMunicipalities(_NoopCatalogRepository()),
      listPatientAttentions: ListPatientAttentions(_NoopAttentionsRepository()),
    );
  });

  test('carga el perfil y guarda demografia', () async {
    expect(await controller.load('p1'), isTrue);
    expect(controller.profile?.patient.fullName, 'Juan Perez');

    final ok = await controller.saveDemographics(
      offline: online,
      gender: 'MALE',
      ethnicity: 'Mestiza',
    );

    expect(ok, isTrue);
    expect(repository.lastDemographicsGender, 'MALE');
    expect(repository.lastDemographicsEthnicity, 'Mestiza');
  });

  test('guarda antecedentes reemplazando la lista', () async {
    await controller.load('p1');

    final ok = await controller.saveMedicalHistories(
      offline: online,
      histories: const [NewPatientMedicalHistory(condition: 'Asma')],
    );

    expect(ok, isTrue);
    expect(repository.lastHistoriesCount, 1);
  });

  test('bloquea la edicion con la ventana offline vencida', () async {
    await controller.load('p1');

    final ok = await controller.saveDemographics(
      offline: offlineLocked,
      gender: 'FEMALE',
    );

    expect(ok, isFalse);
    expect(repository.lastDemographicsGender, isNull);
    expect(controller.error, isNotNull);
  });
}

class FakePatientsRepository implements PatientsRepository {
  String? lastDemographicsGender;
  String? lastDemographicsEthnicity;
  int? lastHistoriesCount;

  PatientProfile get _profile => PatientProfile(
    patient: Patient(
      id: 'p1',
      documentType: 'CC',
      documentNumber: '12345678',
      firstName: 'Juan',
      lastName: 'Perez',
      birthDate: DateTime(2020, 1, 1),
      sex: 'MALE',
      status: 'ACTIVE',
    ),
  );

  @override
  Future<PatientProfile> getById(String accessToken, String patientId) async =>
      _profile;

  @override
  Future<PatientProfile> updateDemographics(
    String accessToken,
    String patientId, {
    String? gender,
    String? ethnicity,
    String? educationLevel,
  }) async {
    lastDemographicsGender = gender;
    lastDemographicsEthnicity = ethnicity;
    return _profile;
  }

  @override
  Future<PatientProfile> updateContact(
    String accessToken,
    String patientId, {
    required List<NewPatientContact> contacts,
    required List<NewPatientAddress> addresses,
  }) async => _profile;

  @override
  Future<PatientProfile> updateMedicalHistories(
    String accessToken,
    String patientId,
    List<NewPatientMedicalHistory> histories,
  ) async {
    lastHistoriesCount = histories.length;
    return _profile;
  }

  @override
  Future<List<Patient>> searchByDocument(
    String accessToken, {
    required String documentType,
    required String documentNumber,
  }) => throw UnimplementedError();

  @override
  Future<Patient> create(
    String accessToken, {
    required NewPatientInput input,
    String? operationId,
  }) => throw UnimplementedError();
}

class _NoopCatalogRepository implements CatalogRepository {
  @override
  Future<List<GeoDepartment>> listDepartments(String token) async => const [];

  @override
  Future<List<GeoMunicipality>> listMunicipalities(
    String token,
    String departmentId,
  ) async => const [];

  @override
  Future<List<EffectiveVaccine>> listEffectiveCatalog(String token) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No usado en el test');
}

class _NoopAttentionsRepository implements AttentionsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('No usado en el test');
}
