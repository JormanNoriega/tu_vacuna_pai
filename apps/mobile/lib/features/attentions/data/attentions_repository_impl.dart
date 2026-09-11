import '../../../core/network/api_client.dart';
import '../domain/entities/attention.dart';
import '../domain/repositories/attentions_repository.dart';

class AttentionsRepositoryImpl implements AttentionsRepository {
  AttentionsRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Attention> createAttention(
    String accessToken, {
    required String patientId,
    String? observations,
    String? operationId,
  }) async {
    final json = await _apiClient.createAttention(accessToken, {
      'patientId': patientId,
      if (observations != null && observations.isNotEmpty)
        'observations': observations,
    }, operationId: operationId);
    return Attention.fromJson(json);
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
    final json = await _apiClient.registerDose(accessToken, attentionId, {
      'vaccineId': vaccineId,
      'doseOptionId': doseOptionId,
      if (pneumococcalTypeOptionId != null &&
          pneumococcalTypeOptionId.isNotEmpty)
        'pneumococcalTypeOptionId': pneumococcalTypeOptionId,
      if (lotNumber != null && lotNumber.isNotEmpty) 'lotNumber': lotNumber,
      if (applicationDate != null && applicationDate.isNotEmpty)
        'applicationDate': applicationDate,
      if (selectedLaboratoryId != null && selectedLaboratoryId.isNotEmpty)
        'selectedLaboratoryId': selectedLaboratoryId,
      if (selectedSyringeId != null && selectedSyringeId.isNotEmpty)
        'selectedSyringeId': selectedSyringeId,
      if (selectedDropperId != null && selectedDropperId.isNotEmpty)
        'selectedDropperId': selectedDropperId,
      if (selectedObservationId != null && selectedObservationId.isNotEmpty)
        'selectedObservationId': selectedObservationId,
    }, operationId: operationId);
    return AppliedDose.fromJson(json);
  }

  @override
  Future<Attention> completeAttention(
    String accessToken,
    String attentionId,
  ) async => Attention.fromJson(
    await _apiClient.completeAttention(accessToken, attentionId),
  );

  @override
  Future<Attention> cancelAttention(
    String accessToken,
    String attentionId, {
    required String reason,
  }) async => Attention.fromJson(
    await _apiClient.cancelAttention(accessToken, attentionId, {
      'reason': reason,
    }),
  );

  @override
  Future<AppliedDose> cancelDose(
    String accessToken,
    String attentionId,
    String doseId, {
    required String reason,
  }) async => AppliedDose.fromJson(
    await _apiClient.cancelDose(accessToken, attentionId, doseId, {
      'reason': reason,
    }),
  );

  @override
  Future<List<Attention>> listByPatient(
    String accessToken,
    String patientId,
  ) async {
    final jsonList = await _apiClient.listAttentionsByPatient(
      accessToken,
      patientId,
    );
    return jsonList.map(Attention.fromJson).toList();
  }
}
