import '../entities/metrics_summary.dart';
import '../entities/recent_record_item.dart';

/// Fuente de las metricas del home.
abstract interface class MetricsRepository {
  /// Consulta el resumen en el servidor y actualiza el cache local.
  Future<MetricsSummary> remoteSummary(
    String accessToken, {
    String? vaccinatorId,
  });

  /// Resumen sin red: ultimo valor cacheado del servidor mas los pendientes
  /// locales; si nunca se sincronizo, cuenta el working set local.
  Future<MetricsSummary> localSummary(
    String institutionId, {
    String? vaccinatorId,
  });

  /// Ultimos registros de atencion en el servidor.
  Future<List<RecentRecordItem>> remoteRecentRecords(
    String accessToken, {
    int limit = 5,
  });

  /// Ultimos registros de atencion offline.
  Future<List<RecentRecordItem>> localRecentRecords(
    String institutionId, {
    String? vaccinatorId,
    int limit = 5,
  });
}
