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
    String? attentionDate,
    bool? completeScheme,
    bool? paiwebRegistered,
    String? paiwebNotRegisteredReason,
    String? operationId,
  }) async {
    final json = await _apiClient.createAttention(accessToken, {
      'patientId': patientId,
      if (observations != null && observations.isNotEmpty)
        'observations': observations,
      if (attentionDate != null && attentionDate.isNotEmpty)
        'attentionDate': attentionDate,
      'completeScheme': ?completeScheme,
      'paiwebRegistered': ?paiwebRegistered,
      if (paiwebNotRegisteredReason != null &&
          paiwebNotRegisteredReason.isNotEmpty)
        'paiwebNotRegisteredReason': paiwebNotRegisteredReason,
    }, operationId: operationId);
    return Attention.fromJson(json);
  }

  @override
  Future<Attention> updateAttention(
    String accessToken,
    String attentionId, {
    required int version,
    String? observations,
    bool? completeScheme,
    bool? paiwebRegistered,
    String? paiwebNotRegisteredReason,
    String? attentionDate,
  }) async {
    final json = await _apiClient.updateAttention(accessToken, attentionId, {
      'version': version,
      'observations': ?observations,
      'completeScheme': ?completeScheme,
      'paiwebRegistered': ?paiwebRegistered,
      if (paiwebNotRegisteredReason != null &&
          paiwebNotRegisteredReason.isNotEmpty)
        'paiwebNotRegisteredReason': paiwebNotRegisteredReason,
      if (attentionDate != null && attentionDate.isNotEmpty)
        'attentionDate': attentionDate,
    });
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
    String? syringeLot,
    String? diluent,
    int? vialCount,
    String? customObservation,
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
      if (syringeLot != null && syringeLot.isNotEmpty) 'syringeLot': syringeLot,
      if (diluent != null && diluent.isNotEmpty) 'diluent': diluent,
      'vialCount': ?vialCount,
      if (customObservation != null && customObservation.isNotEmpty)
        'customObservation': customObservation,
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
