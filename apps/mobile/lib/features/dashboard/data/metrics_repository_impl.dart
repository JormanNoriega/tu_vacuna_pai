import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/synchronization/sync_operation.dart';
import '../../../core/synchronization/sync_outbox.dart';
import '../domain/entities/metrics_summary.dart';
import '../domain/repositories/metrics_repository.dart';

/// Implementacion de [MetricsRepository] sobre la API, con respaldo offline.
///
/// Online consulta `/metrics/summary` y cachea el ultimo valor en
/// [SyncMetadata]. Sin red devuelve el ultimo valor cacheado mas los
/// comprobantes pendientes del outbox (para que una vacunacion sin internet
/// cuente) o, si nunca hubo cache, el conteo del working set local.
class MetricsRepositoryImpl implements MetricsRepository {
  MetricsRepositoryImpl({
    required this.api,
    required this.database,
    required this.outbox,
  });

  final ApiClient api;
  final AppDatabase database;
  final SyncOutboxRepository outbox;

  static const _cacheKey = 'metrics_summary';

  @override
  Future<MetricsSummary> remoteSummary(String accessToken) async {
    final json = await api.fetchMetricsSummary(accessToken);
    final summary = MetricsSummary(
      patientsAttended: (json['patientsAttended'] as num?)?.toInt() ?? 0,
      dosesApplied: (json['dosesApplied'] as num?)?.toInt() ?? 0,
    );
    await database.setSyncMetadata(
      _cacheKey,
      jsonEncode({
        'patientsAttended': summary.patientsAttended,
        'dosesApplied': summary.dosesApplied,
      }),
    );
    return summary;
  }

  @override
  Future<MetricsSummary> localSummary(String institutionId) async {
    final cached = await _readCache();
    if (cached == null) {
      return MetricsSummary(
        patientsAttended: await database.countDistinctPatientsLocal(
          institutionId,
        ),
        dosesApplied: await database.countAppliedDosesLocal(institutionId),
      );
    }

    var pendingAttentions = 0;
    var pendingDoses = 0;
    for (final entry in await outbox.pendingEntries()) {
      switch (entry.operation.commandType) {
        case SyncCommandType.createAttention:
          pendingAttentions++;
        case SyncCommandType.registerAppliedDose:
          pendingDoses++;
        case SyncCommandType.createPatient:
        case SyncCommandType.completeAttention:
          break;
      }
    }

    return MetricsSummary(
      patientsAttended: cached.patientsAttended + pendingAttentions,
      dosesApplied: cached.dosesApplied + pendingDoses,
    );
  }

  Future<MetricsSummary?> _readCache() async {
    final raw = await database.syncMetadataValue(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return MetricsSummary(
      patientsAttended: (decoded['patientsAttended'] as num?)?.toInt() ?? 0,
      dosesApplied: (decoded['dosesApplied'] as num?)?.toInt() ?? 0,
    );
  }
}
