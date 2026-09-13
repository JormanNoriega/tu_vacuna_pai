import 'dart:convert';

import 'package:drift/drift.dart';

import '../auth/session_manager.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../storage/app_database.dart';
import 'sync_operation.dart';
import 'sync_outbox.dart';
import 'sync_queue.dart';
import 'sync_status.dart';

/// Resultado de un ciclo de sincronizacion.
class SyncOutcome {
  const SyncOutcome({
    this.pushed = 0,
    this.pulled = 0,
    this.skipped = false,
    this.error,
  });

  final int pushed;
  final int pulled;
  final bool skipped;
  final String? error;

  bool get isSuccess => error == null;
}

/// Politica de reintentos (backoff exponencial) del outbox.
class SyncBackoff {
  const SyncBackoff({
    this.base = const Duration(seconds: 2),
    this.max = const Duration(minutes: 5),
    this.maxRetries = 6,
  });

  final Duration base;
  final Duration max;
  final int maxRetries;

  Duration delayFor(int retryCount) {
    final factor = 1 << retryCount.clamp(0, 16).toInt();
    final milliseconds = base.inMilliseconds * factor;
    return Duration(
      milliseconds: milliseconds > max.inMilliseconds
          ? max.inMilliseconds
          : milliseconds,
    );
  }
}

/// Motor de sincronizacion: empuja el outbox (`/sync/push`) y aplica los
/// cambios del servidor al working set local (`/sync/pull`).
///
/// No decide permisos ni autorizacion offline (eso es `OfflinePolicy`); solo
/// transporta lo ya encolado y refleja el resultado.
class SyncEngine {
  SyncEngine({
    required ApiClient apiClient,
    required this.outbox,
    required AppDatabase database,
    required this.sessionManager,
    this.backoff = const SyncBackoff(),
    this.maxBatchSize = 100,
    this.catalogsApplier,
  }) : _api = apiClient,
       _db = database;

  final ApiClient _api;
  final SyncOutboxRepository outbox;
  final AppDatabase _db;
  final SessionManager sessionManager;

  final SyncBackoff backoff;
  final int maxBatchSize;

  /// Callback opcional para aplicar la seccion `catalogs` del pull.
  final Future<void> Function(Map<String, dynamic> catalogs)? catalogsApplier;

  static const _pullCursorKey = 'last_pull_cursor';
  static const _appliedPullKey = 'applied_pull_operations';
  static const _maxAppliedPullIds = 2000;

  bool _running = false;

  bool get isRunning => _running;

  /// Ejecuta push y pull en secuencia, sin solaparse.
  Future<SyncOutcome> syncOnce() async {
    if (_running) return const SyncOutcome(skipped: true);
    _running = true;
    try {
      await outbox.resetProcessingToPending();
      final token = await _accessToken();
      if (token == null) return const SyncOutcome(skipped: true);
      final pushed = await _push(token);
      final pulled = await _pull(token);
      return SyncOutcome(pushed: pushed, pulled: pulled);
    } on ApiException catch (error) {
      return SyncOutcome(error: error.message);
    } catch (error) {
      return SyncOutcome(error: error.toString());
    } finally {
      _running = false;
    }
  }

  // ---------- Push ----------

  Future<int> _push(String token) async {
    final entries = await outbox.pendingOperations();
    if (entries.isEmpty) return 0;

    final ordered = SyncQueue.order(entries).take(maxBatchSize).toList();
    final byId = {
      for (final entry in ordered) entry.operation.operationId: entry,
    };
    for (final entry in ordered) {
      await outbox.markProcessing(entry.operation.operationId);
    }

    final Map<String, dynamic> response;
    try {
      response = await _api.pushSync(
        token,
        [for (final entry in ordered) entry.operation.toJson()],
      );
    } catch (error) {
      await _scheduleTransportRetry(ordered, error);
      return 0;
    }

    final accepted = (response['accepted'] as List<dynamic>?) ?? const [];
    final rejected = (response['rejected'] as List<dynamic>?) ?? const [];

    var acceptedCount = 0;
    for (final rawId in accepted) {
      final operationId = rawId.toString();
      await outbox.markCompleted(operationId);
      final entry = byId[operationId];
      if (entry != null) await _markAggregateSynced(entry.operation);
      acceptedCount++;
    }

    for (final raw in rejected) {
      if (raw is! Map<String, dynamic>) continue;
      final operationId = raw['operationId']?.toString();
      if (operationId == null) continue;
      await _handleRejection(
        operationId,
        raw['reason']?.toString(),
        raw['error']?.toString(),
        byId[operationId],
      );
    }
    return acceptedCount;
  }

  Future<void> _scheduleTransportRetry(
    List<OutboxEntry> entries,
    Object error,
  ) async {
    final message = error.toString();
    for (final entry in entries) {
      final operationId = entry.operation.operationId;
      final nextCount = entry.retryCount + 1;
      if (nextCount > backoff.maxRetries) {
        await outbox.markFailed(
          operationId,
          retryCount: nextCount,
          nextRetryAtEpoch: 0,
          error: message,
        );
      } else {
        await outbox.scheduleRetry(
          operationId,
          retryCount: nextCount,
          nextRetryAtEpoch: _epochIn(backoff.delayFor(nextCount)),
          error: message,
        );
      }
    }
  }

  Future<void> _handleRejection(
    String operationId,
    String? reason,
    String? error,
    OutboxEntry? entry,
  ) async {
    switch (reason) {
      case 'DEPENDENCY_NOT_FOUND':
      case 'DEPENDENCY_FAILED':
        await outbox.requeue(operationId, error: reason);
      case 'DUPLICATE_BUSINESS_IDENTITY':
      case 'PERMISSION_DENIED':
      case 'USER_NOT_ACTIVE':
        await outbox.markQuarantined(operationId, error: reason);
        if (entry != null) {
          await _markAggregateState(
            entry.operation,
            SyncAggregateState.quarantined,
          );
        }
      default:
        await outbox.markFailed(
          operationId,
          retryCount: 0,
          nextRetryAtEpoch: 0,
          error: error ?? reason,
        );
        if (entry != null) {
          await _markAggregateState(entry.operation, SyncAggregateState.failed);
        }
    }
  }

  Future<void> _markAggregateSynced(SyncOperation operation) =>
      _markAggregateState(operation, SyncAggregateState.synced);

  Future<void> _markAggregateState(
    SyncOperation operation,
    SyncAggregateState state,
  ) async {
    switch (operation.commandType) {
      case SyncCommandType.createPatient:
        await _db.updatePatientSyncState(operation.aggregateId, state.value);
      case SyncCommandType.createAttention:
        await _db.updateAttentionSyncState(
          operation.aggregateId,
          state.value,
        );
      case SyncCommandType.completeAttention:
        await _db.updateAttentionSyncState(
          operation.aggregateId,
          state.value,
          status: state == SyncAggregateState.synced ? 'COMPLETED' : null,
        );
      case SyncCommandType.registerAppliedDose:
        await _db.updateDoseSyncState(operation.aggregateId, state.value);
    }
  }

  // ---------- Pull ----------

  Future<int> _pull(String token) async {
    final cursor = await _db.syncMetadataValue(_pullCursorKey) ?? '0|';
    final response = await _api.pullSync(token, since: cursor);
    final rawOperations = (response['operations'] as List<dynamic>?) ?? const [];

    final applied = await _loadAppliedPullIds();
    var appliedCount = 0;
    for (final raw in rawOperations) {
      if (raw is! Map<String, dynamic>) continue;
      final operation = SyncOperation.fromJson(raw);
      if (applied.contains(operation.operationId)) continue;
      await _applyPulledOperation(operation);
      applied.add(operation.operationId);
      appliedCount++;
    }
    await _saveAppliedPullIds(applied);

    final nextCursor = response['nextCursor']?.toString();
    if (nextCursor != null && nextCursor.isNotEmpty) {
      await _db.setSyncMetadata(_pullCursorKey, nextCursor);
    }

    final catalogs = response['catalogs'];
    if (catalogs is Map<String, dynamic> && catalogsApplier != null) {
      await catalogsApplier!(catalogs);
    }
    return appliedCount;
  }

  Future<void> _applyPulledOperation(SyncOperation operation) async {
    final institutionId = await _institutionId();
    if (institutionId == null) return;
    final payload = operation.payload;

    switch (operation.commandType) {
      case SyncCommandType.createPatient:
        final demographics = payload['demographics'];
        final contacts = (payload['contacts'] as List<dynamic>?) ?? const [];
        final addresses = (payload['addresses'] as List<dynamic>?) ?? const [];
        await _db.upsertPatientLocal(
          PatientsLocalCompanion.insert(
            id: operation.aggregateId,
            institutionId: institutionId,
            documentType: _str(payload['documentType']),
            documentNumber: _str(payload['documentNumber']),
            firstName: _str(payload['firstName']),
            lastName: _str(payload['lastName']),
            birthDate: Value(_date(payload['birthDate'])),
            sex: Value(_nullable(payload['sex'])),
            gender: Value(
              demographics is Map ? _nullable(demographics['gender']) : null,
            ),
            phone: Value(_contactValue(contacts, 'PHONE')),
            email: Value(_contactValue(contacts, 'EMAIL')),
            addressLine: Value(_firstAddressField(addresses, 'street')),
            addressDepartment: Value(
              _firstAddressField(addresses, 'departmentId'),
            ),
            addressMunicipality: Value(
              _firstAddressField(addresses, 'municipalityId'),
            ),
            syncState: SyncAggregateState.synced.value,
            version: 0,
            updatedAt: _epochNow(),
          ),
        );
      case SyncCommandType.createAttention:
        await _db.upsertAttentionLocal(
          AttentionsLocalCompanion.insert(
            id: operation.aggregateId,
            institutionId: institutionId,
            patientId: _str(payload['patientId']),
            status: 'DRAFT',
            attentionDate: Value(_epoch(payload['attentionDate'])),
            observations: Value(_nullable(payload['observations'])),
            version: 0,
            syncState: SyncAggregateState.synced.value,
            updatedAt: _epochNow(),
          ),
        );
      case SyncCommandType.registerAppliedDose:
        final attentionId = _nullable(payload['attentionId']);
        if (attentionId == null) return;
        await _db.upsertAppliedDoseLocal(
          AppliedDosesLocalCompanion.insert(
            id: operation.aggregateId,
            attentionId: attentionId,
            vaccineId: Value(_nullable(payload['vaccineId'])),
            status: 'REGISTERED',
            appliedAt: _epoch(payload['applicationDate']) ?? _epochNow(),
            lot: Value(_nullable(payload['lotNumber'])),
            vaccineNameSnapshot: _str(payload['vaccineId']),
            doseLabelSnapshot: Value(_nullable(payload['doseOptionId'])),
            syncState: SyncAggregateState.synced.value,
            updatedAt: _epochNow(),
          ),
        );
      case SyncCommandType.completeAttention:
        await _db.updateAttentionSyncState(
          operation.aggregateId,
          SyncAggregateState.synced.value,
          status: 'COMPLETED',
        );
    }
  }

  // ---------- Helpers ----------

  Future<Set<String>> _loadAppliedPullIds() async {
    final raw = await _db.syncMetadataValue(_appliedPullKey);
    if (raw == null || raw.isEmpty) return <String>{};
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toSet();
    }
    return <String>{};
  }

  Future<void> _saveAppliedPullIds(Set<String> ids) async {
    final list = ids.toList();
    final trimmed = list.length > _maxAppliedPullIds
        ? list.sublist(list.length - _maxAppliedPullIds)
        : list;
    await _db.setSyncMetadata(_appliedPullKey, jsonEncode(trimmed));
  }

  Future<String?> _accessToken() async =>
      (await sessionManager.loadSession())?.accessToken;

  Future<String?> _institutionId() async =>
      (await _db.currentUserProfile())?.institutionId;

  static int _epochNow() =>
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  static int _epochIn(Duration delay) {
    final seconds = delay.inSeconds < 1
        ? 1
        : (delay.inSeconds > 86400 ? 86400 : delay.inSeconds);
    return _epochNow() + seconds;
  }

  static String _str(Object? value) => value?.toString() ?? '';

  static String? _nullable(Object? value) {
    final text = value?.toString();
    return (text == null || text.isEmpty) ? null : text;
  }

  static String? _contactValue(List<dynamic> contacts, String type) {
    for (final contact in contacts) {
      if (contact is Map && contact['type'] == type) {
        return _nullable(contact['value']);
      }
    }
    return null;
  }

  static String? _firstAddressField(List<dynamic> addresses, String field) {
    for (final address in addresses) {
      if (address is Map) {
        final value = _nullable(address[field]);
        if (value != null) return value;
      }
    }
    return null;
  }

  static DateTime? _date(Object? value) {
    final text = _nullable(value);
    return text == null ? null : DateTime.tryParse(text);
  }

  static int? _epoch(Object? value) {
    final text = _nullable(value);
    if (text == null) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return parsed.toUtc().millisecondsSinceEpoch ~/ 1000;
    }
    return int.tryParse(text);
  }
}
