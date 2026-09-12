import 'dart:convert';

import '../storage/app_database.dart';
import 'sync_operation.dart';
import 'sync_status.dart';

/// Repositorio del outbox de sincronizacion.
///
/// Cada operacion se inserta en una transaccion junto con la escritura local
/// del agregado (`commitLocalWrite`), de modo que nunca exista un dato clinico
/// local sin su comando pendiente.
class SyncOutboxRepository {
  SyncOutboxRepository(this._db);

  final AppDatabase _db;

  /// Ejecuta [writeLocal] y encola [operation] de forma atomica.
  Future<void> commitLocalWrite({
    required Future<void> Function() writeLocal,
    required SyncOperation operation,
  }) => _db.transaction(() async {
    await writeLocal();
    await _insert(operation);
  });

  /// Encola [operation] sin escribir agregado local.
  Future<void> enqueue(SyncOperation operation) =>
      _db.transaction(() => _insert(operation));

  Future<void> _insert(SyncOperation operation) async {
    final now = _now();
    await _db.insertOutboxEntry(
      SyncOutboxCompanion.insert(
        operationId: operation.operationId,
        commandType: operation.commandType.value,
        aggregateId: operation.aggregateId,
        payload: _encodePayload(operation.payload),
        status: SyncOutboxStatus.pending.value,
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (final dependency in operation.dependencies) {
      await _db.insertOutboxDependency(operation.operationId, dependency);
    }
  }

  /// Operaciones listas para enviar (PENDING y con backoff vencido).
  Future<List<OutboxEntry>> pendingOperations() async {
    final rows = await _db.pendingOutboxOperations();
    return Future.wait(rows.map(_toEntry));
  }

  Future<List<OutboxEntry>> operationsByStatus(SyncOutboxStatus status) async {
    final rows = await _db.outboxByStatus(status.value);
    return Future.wait(rows.map(_toEntry));
  }

  Future<OutboxEntry?> byOperationId(String operationId) async {
    final row = await _db.outboxByOperationId(operationId);
    return row == null ? null : _toEntry(row);
  }

  Future<void> markProcessing(String operationId) => _db.updateOutboxStatus(
    operationId,
    SyncOutboxStatus.processing.value,
  );

  Future<void> markCompleted(String operationId) => _db.updateOutboxStatus(
    operationId,
    SyncOutboxStatus.completed.value,
    lastError: null,
  );

  /// Marca [operationId] como `failed` y agenda el proximo reintento.
  Future<void> markFailed(
    String operationId, {
    required int retryCount,
    required int nextRetryAtEpoch,
    String? error,
  }) => _db.updateOutboxStatus(
    operationId,
    SyncOutboxStatus.failed.value,
    retryCount: retryCount,
    nextRetryAt: nextRetryAtEpoch,
    lastError: error,
  );

  /// Reencola una operacion `failed` para reintento manual/inmediato.
  Future<void> requeue(String operationId, {String? error}) =>
      _db.updateOutboxStatus(
        operationId,
        SyncOutboxStatus.pending.value,
        nextRetryAt: 0,
        lastError: error,
      );

  /// Reagenda un reintento automatico con backoff (fallo transitorio).
  Future<void> scheduleRetry(
    String operationId, {
    required int retryCount,
    required int nextRetryAtEpoch,
    String? error,
  }) => _db.updateOutboxStatus(
    operationId,
    SyncOutboxStatus.pending.value,
    retryCount: retryCount,
    nextRetryAt: nextRetryAtEpoch,
    lastError: error,
  );

  Future<void> markQuarantined(String operationId, {String? error}) =>
      _db.updateOutboxStatus(
        operationId,
        SyncOutboxStatus.quarantined.value,
        lastError: error,
      );

  /// Al arrancar, cualquier `PROCESSING` vuelve a `PENDING` (idempotencia).
  Future<void> resetProcessingToPending() => _db.resetProcessingToPending();

  Future<int> pendingCount() => _db.pendingOutboxCount();

  Future<void> clear() => _db.clearOutbox();

  Future<OutboxEntry> _toEntry(SyncOutboxData row) async {
    final dependencies = await _db.outboxDependenciesOf(row.operationId);
    return OutboxEntry(
      operation: SyncOperation(
        operationId: row.operationId,
        commandType: SyncCommandType.fromValue(row.commandType),
        aggregateId: row.aggregateId,
        payload: _decodePayload(row.payload),
        dependencies: dependencies
            .map((dependency) => dependency.dependsOnOperationId)
            .toList(),
      ),
      status: SyncOutboxStatus.fromValue(row.status),
      retryCount: row.retryCount,
    );
  }

  static String _encodePayload(Map<String, dynamic> payload) =>
      jsonEncode(payload);

  static Map<String, dynamic> _decodePayload(String raw) {
    if (raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return const {};
  }

  static int _now() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
}
