import '../../../../core/auth/offline_access.dart';
import '../../../../core/auth/offline_policy.dart';
import '../entities/attention.dart';
import '../repositories/attentions_repository.dart';

class CreateAttention {
  const CreateAttention(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final AttentionsRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<Attention> call(
    String accessToken, {
    required OfflineAccess offline,
    required String patientId,
    String? observations,
    String? operationId,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.createAttention,
    );
    return _repository.createAttention(
      accessToken,
      patientId: patientId,
      observations: observations,
      operationId: operationId,
    );
  }
}

class RegisterDose {
  const RegisterDose(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final AttentionsRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<AppliedDose> call(
    String accessToken,
    String attentionId, {
    required OfflineAccess offline,
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
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.registerDose,
    );
    return _repository.registerDose(
      accessToken,
      attentionId,
      vaccineId: vaccineId,
      doseOptionId: doseOptionId,
      pneumococcalTypeOptionId: pneumococcalTypeOptionId,
      lotNumber: lotNumber,
      applicationDate: applicationDate,
      selectedLaboratoryId: selectedLaboratoryId,
      selectedSyringeId: selectedSyringeId,
      selectedDropperId: selectedDropperId,
      selectedObservationId: selectedObservationId,
      operationId: operationId,
    );
  }
}

class CompleteAttention {
  const CompleteAttention(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final AttentionsRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<Attention> call(
    String accessToken,
    String attentionId, {
    required OfflineAccess offline,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.completeAttention,
    );
    return _repository.completeAttention(accessToken, attentionId);
  }
}

class CancelAttention {
  const CancelAttention(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final AttentionsRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<Attention> call(
    String accessToken,
    String attentionId, {
    required OfflineAccess offline,
    required String reason,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.cancelAttention,
    );
    return _repository.cancelAttention(
      accessToken,
      attentionId,
      reason: reason,
    );
  }
}

class CancelDose {
  const CancelDose(
    this._repository, [
    this._offlinePolicy = const OfflinePolicy(),
  ]);

  final AttentionsRepository _repository;
  final OfflinePolicy _offlinePolicy;

  Future<AppliedDose> call(
    String accessToken,
    String attentionId,
    String doseId, {
    required OfflineAccess offline,
    required String reason,
  }) {
    _offlinePolicy.ensureWritable(
      status: offline.status,
      permissions: offline.permissions,
      operation: OperationPermission.cancelDose,
    );
    return _repository.cancelDose(
      accessToken,
      attentionId,
      doseId,
      reason: reason,
    );
  }
}

class ListPatientAttentions {
  const ListPatientAttentions(this._repository);

  final AttentionsRepository _repository;

  Future<List<Attention>> call(String accessToken, String patientId) =>
      _repository.listByPatient(accessToken, patientId);
}
