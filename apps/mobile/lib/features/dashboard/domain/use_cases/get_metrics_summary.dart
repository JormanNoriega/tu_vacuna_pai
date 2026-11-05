import '../entities/metrics_summary.dart';
import '../entities/recent_record_item.dart';
import '../repositories/metrics_repository.dart';

/// Obtiene el resumen de metricas del home.
class GetMetricsSummary {
  const GetMetricsSummary(this._repository);

  final MetricsRepository _repository;

  /// Resumen del servidor (requiere sesion).
  Future<MetricsSummary> remote(String accessToken, {String? vaccinatorId}) =>
      _repository.remoteSummary(accessToken, vaccinatorId: vaccinatorId);

  /// Resumen offline (cache + pendientes locales o working set local).
  Future<MetricsSummary> local(String institutionId, {String? vaccinatorId}) =>
      _repository.localSummary(institutionId, vaccinatorId: vaccinatorId);

  /// Ultimos registros del servidor.
  Future<List<RecentRecordItem>> remoteRecent(
    String accessToken, {
    int limit = 5,
  }) => _repository.remoteRecentRecords(accessToken, limit: limit);

  /// Ultimos registros offline.
  Future<List<RecentRecordItem>> localRecent(
    String institutionId, {
    String? vaccinatorId,
    int limit = 5,
  }) => _repository.localRecentRecords(
    institutionId,
    vaccinatorId: vaccinatorId,
    limit: limit,
  );
}
