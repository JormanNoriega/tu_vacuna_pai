import '../entities/attention.dart';

/// Gestion clinica de atenciones y dosis. Online-first: las escrituras se
/// confirman con la respuesta del servidor. El profesional y la institucion se
/// resuelven en el backend.
abstract interface class AttentionsRepository {
  Future<Attention> createAttention(
    String accessToken, {
    required String patientId,
    String? observations,
    String? attentionDate,
    bool? completeScheme,
    bool? paiwebRegistered,
    String? paiwebNotRegisteredReason,
    String? operationId,
  });

  /// Actualiza los detalles del encuentro (fecha, observaciones, esquema
  /// completo y PAIWEB). Solo en estados editables.
  Future<Attention> updateAttention(
    String accessToken,
    String attentionId, {
    required int version,
    String? observations,
    bool? completeScheme,
    bool? paiwebRegistered,
    String? paiwebNotRegisteredReason,
    String? attentionDate,
  });

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
  });

  Future<Attention> completeAttention(String accessToken, String attentionId);

  /// Anula la atencion con motivo (append-only).
  Future<Attention> cancelAttention(
    String accessToken,
    String attentionId, {
    required String reason,
  });

  /// Anula una dosis aplicada con motivo (append-only).
  Future<AppliedDose> cancelDose(
    String accessToken,
    String attentionId,
    String doseId, {
    required String reason,
  });

  Future<List<Attention>> listByPatient(String accessToken, String patientId);
}
