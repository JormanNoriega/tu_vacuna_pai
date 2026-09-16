/// Resumen de metricas de la institucion para el home (acumulado historico).
class MetricsSummary {
  const MetricsSummary({
    required this.patientsAttended,
    required this.dosesApplied,
  });

  final int patientsAttended;
  final int dosesApplied;

  static const empty = MetricsSummary(patientsAttended: 0, dosesApplied: 0);
}
