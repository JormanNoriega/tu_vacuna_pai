import '../../../../core/auth/offline_access.dart';
import '../../../../core/auth/offline_policy.dart';
import '../entities/new_patient.dart';
import '../entities/patient.dart';
import '../repositories/patients_repository.dart';

class CreatePatient {
  const CreatePatient(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final PatientsRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<Patient> call(
    String accessToken, {
    required OfflineAccess offline,
    required NewPatientInput input,
    String? operationId,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.createPatient,
    );
    return _repository.create(
      accessToken,
      input: input,
      operationId: operationId,
    );
  }
}
