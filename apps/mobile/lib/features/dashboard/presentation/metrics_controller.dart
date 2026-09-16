import '../../../core/presentation/async_controller.dart';
import '../domain/entities/metrics_summary.dart';
import '../domain/use_cases/get_metrics_summary.dart';

/// Metricas del home (pacientes atendidos y dosis aplicadas).
///
/// Online consulta el servidor; si falla o la sesion esta offline, cae al
/// resumen local (cache del servidor + pendientes). No bloquea la UI: ante
/// error conserva el ultimo valor.
class MetricsController extends AsyncController {
  MetricsController({
    required super.sessionManager,
    required this.getSummary,
  });

  final GetMetricsSummary getSummary;

  MetricsSummary _summary = MetricsSummary.empty;
  MetricsSummary get summary => _summary;

  Future<void> load({
    required String institutionId,
    required bool offline,
  }) async {
    if (offline) {
      _summary = await getSummary.local(institutionId);
      notifyListeners();
      return;
    }

    await execute((token) async {
      _summary = await getSummary.remote(token);
    });

    // Sin red o servidor no disponible: usar el respaldo local sin dejar error
    // visible (los pendientes ya se comunican en la insignia de sincronizacion).
    if (error != null) {
      clearError();
      _summary = await getSummary.local(institutionId);
      notifyListeners();
    }
  }

  void clearSession() {
    _summary = MetricsSummary.empty;
    clearError();
    notifyListeners();
  }
}
