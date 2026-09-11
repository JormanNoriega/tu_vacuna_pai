import '../../../../core/auth/offline_access.dart';
import '../../../../core/auth/offline_policy.dart';
import '../entities/new_patient.dart';
import '../entities/patient_profile.dart';
import '../repositories/patients_repository.dart';

class GetPatient {
  const GetPatient(this._repository);

  final PatientsRepository _repository;

  Future<PatientProfile> call(String accessToken, String patientId) =>
      _repository.getById(accessToken, patientId);
}

class UpdatePatientDemographics {
  const UpdatePatientDemographics(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final PatientsRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<PatientProfile> call(
    String accessToken,
    String patientId, {
    required OfflineAccess offline,
    String? gender,
    String? ethnicity,
    String? educationLevel,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.updatePatient,
    );
    return _repository.updateDemographics(
      accessToken,
      patientId,
      gender: gender,
      ethnicity: ethnicity,
      educationLevel: educationLevel,
    );
  }
}

class UpdatePatientContact {
  const UpdatePatientContact(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final PatientsRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<PatientProfile> call(
    String accessToken,
    String patientId, {
    required OfflineAccess offline,
    required List<NewPatientContact> contacts,
    required List<NewPatientAddress> addresses,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.updatePatient,
    );
    return _repository.updateContact(
      accessToken,
      patientId,
      contacts: contacts,
      addresses: addresses,
    );
  }
}

class UpdatePatientMedicalHistories {
  const UpdatePatientMedicalHistories(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final PatientsRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<PatientProfile> call(
    String accessToken,
    String patientId, {
    required OfflineAccess offline,
    required List<NewPatientMedicalHistory> histories,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.updatePatient,
    );
    return _repository.updateMedicalHistories(
      accessToken,
      patientId,
      histories,
    );
  }
}
