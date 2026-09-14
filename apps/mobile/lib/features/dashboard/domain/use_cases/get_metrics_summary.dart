import '../entities/metrics_summary.dart';
import '../repositories/metrics_repository.dart';

/// Obtiene el resumen de metricas del home.
class GetMetricsSummary {
  const GetMetricsSummary(this._repository);

  final MetricsRepository _repository;

  /// Resumen del servidor (requiere sesion).
  Future<MetricsSummary> remote(String accessToken) =>
      _repository.remoteSummary(accessToken);

  /// Resumen offline (cache + pendientes locales o working set local).
  Future<MetricsSummary> local(String institutionId) =>
      _repository.localSummary(institutionId);
}
