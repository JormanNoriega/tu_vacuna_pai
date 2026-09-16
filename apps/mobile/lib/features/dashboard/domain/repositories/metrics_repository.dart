import '../entities/metrics_summary.dart';

/// Fuente de las metricas del home.
abstract interface class MetricsRepository {
  /// Consulta el resumen en el servidor y actualiza el cache local.
  Future<MetricsSummary> remoteSummary(String accessToken);

  /// Resumen sin red: ultimo valor cacheado del servidor mas los pendientes
  /// locales; si nunca se sincronizo, cuenta el working set local.
  Future<MetricsSummary> localSummary(String institutionId);
}
