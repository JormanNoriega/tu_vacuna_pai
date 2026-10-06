import 'sync_status.dart';

/// Tipos de comando de dominio transportables por el outbox.
///
/// La Fase 1 (motor offline) cubre la cadena MVP; los comandos restantes del
/// contrato se agregaran aqui sin cambiar el transporte.
enum SyncCommandType {
  createPatient('CREATE_PATIENT', 'patient'),
  createAttention('CREATE_ATTENTION', 'attention'),
  registerAppliedDose('REGISTER_APPLIED_DOSE', 'applied_dose'),
  completeAttention('COMPLETE_ATTENTION', 'attention');

  const SyncCommandType(this.value, this.aggregate);

  /// `command_type` del contrato de sincronizacion.
  final String value;

  /// Agregado afectado (informativo/auditoria).
  final String aggregate;

  static SyncCommandType fromValue(String value) =>
      values.firstWhere((type) => type.value == value);
}

/// Comando listo para encolar y transportar por `POST /sync/push`.
class SyncOperation {
  const SyncOperation({
    required this.operationId,
    required this.commandType,
    required this.aggregateId,
    required this.payload,
    this.dependencies = const [],
    this.summary,
  });

  /// Clave de idempotencia (UUID v4, unica global).
  final String operationId;
  final SyncCommandType commandType;

  /// UUID del agregado afectado (paciente, atencion o dosis).
  final String aggregateId;

  /// Cuerpo especifico del comando.
  final Map<String, dynamic> payload;

  /// `operation_id` de operaciones que deben procesarse antes.
  final List<String> dependencies;

  /// Etiqueta legible del comprobante para la bandeja de pendientes. Es metadata
  /// local: NO se incluye en [toJson] ni viaja al servidor.
  final String? summary;

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'commandType': commandType.value,
    'aggregateId': aggregateId,
    'payload': payload,
    if (dependencies.isNotEmpty) 'dependencies': dependencies,
  };

  static SyncOperation fromJson(Map<String, dynamic> json) => SyncOperation(
    operationId: json['operationId'].toString(),
    commandType: SyncCommandType.fromValue(json['commandType'] as String),
    aggregateId: json['aggregateId'].toString(),
    payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
    dependencies: ((json['dependencies'] as List<dynamic>?) ?? const [])
        .map((item) => item.toString())
        .toList(),
  );
}

/// Entrada del outbox con su estado local y contador de reintentos.
class OutboxEntry {
  const OutboxEntry({
    required this.operation,
    required this.status,
    required this.retryCount,
    this.createdAt,
  });

  final SyncOperation operation;
  final SyncOutboxStatus status;
  final int retryCount;

  /// Momento en que se encolo el comprobante (para la bandeja de pendientes).
  final DateTime? createdAt;
}
