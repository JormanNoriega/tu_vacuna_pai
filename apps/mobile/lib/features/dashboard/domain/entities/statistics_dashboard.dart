class StatisticsDashboard {
  const StatisticsDashboard({
    required this.from,
    required this.to,
    required this.granularity,
    required this.dosesApplied,
    required this.uniquePatients,
    required this.activeVaccinators,
    required this.dosesPerPatient,
    required this.doseSeries,
    required this.vaccineDistribution,
    required this.vaccinatorProductivity,
    required this.generatedAt,
    required this.source,
  });

  factory StatisticsDashboard.empty() => StatisticsDashboard(
        from: DateTime.now().toUtc(),
        to: DateTime.now().toUtc(),
        granularity: 'day',
        dosesApplied: 0,
        uniquePatients: 0,
        activeVaccinators: 0,
        dosesPerPatient: 0,
        doseSeries: const [],
        vaccineDistribution: const [],
        vaccinatorProductivity: const [],
        generatedAt: null,
        source: 'empty',
      );

  factory StatisticsDashboard.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>? ?? const {};
    final kpis = json['kpis'] as Map<String, dynamic>? ?? const {};
    final status = json['status'] as Map<String, dynamic>? ?? const {};

    return StatisticsDashboard(
      from: DateTime.tryParse(period['from']?.toString() ?? '')?.toUtc(),
      to: DateTime.tryParse(period['to']?.toString() ?? '')?.toUtc(),
      granularity: period['granularity']?.toString() ?? 'day',
      dosesApplied: (kpis['dosesApplied'] as num?)?.toInt() ?? 0,
      uniquePatients: (kpis['uniquePatients'] as num?)?.toInt() ?? 0,
      activeVaccinators: (kpis['activeVaccinators'] as num?)?.toInt() ?? 0,
      dosesPerPatient: (kpis['dosesPerPatient'] as num?)?.toInt() ?? 0,
      doseSeries: ((json['doseSeries'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => StatisticsTimePoint.fromJson(Map<String, dynamic>.from(item)))
          .toList()),
      vaccineDistribution: ((json['vaccineDistribution'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => StatisticsVaccine.fromJson(Map<String, dynamic>.from(item)))
          .toList()),
      vaccinatorProductivity:
          ((json['vaccinatorProductivity'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((item) => StatisticsVaccinator.fromJson(Map<String, dynamic>.from(item)))
              .toList()),
      generatedAt: DateTime.tryParse(status['generatedAt']?.toString() ?? '')?.toUtc(),
      source: status['source']?.toString() ?? 'server',
    );
  }

  final DateTime? from;
  final DateTime? to;
  final String granularity;
  final int dosesApplied;
  final int uniquePatients;
  final int activeVaccinators;
  final int dosesPerPatient;
  final List<StatisticsTimePoint> doseSeries;
  final List<StatisticsVaccine> vaccineDistribution;
  final List<StatisticsVaccinator> vaccinatorProductivity;
  final DateTime? generatedAt;
  final String source;

  bool get hasData => dosesApplied > 0 || uniquePatients > 0;
}

class StatisticsTimePoint {
  const StatisticsTimePoint({
    required this.label,
    required this.start,
    required this.doses,
    required this.uniquePatients,
  });

  factory StatisticsTimePoint.fromJson(Map<String, dynamic> json) {
    return StatisticsTimePoint(
      label: json['label']?.toString() ?? '',
      start: DateTime.tryParse(json['start']?.toString() ?? '')?.toUtc(),
      doses: (json['doses'] as num?)?.toInt() ?? 0,
      uniquePatients: (json['uniquePatients'] as num?)?.toInt() ?? 0,
    );
  }

  final String label;
  final DateTime? start;
  final int doses;
  final int uniquePatients;
}

class StatisticsVaccine {
  const StatisticsVaccine({
    required this.name,
    required this.code,
    required this.doses,
    required this.percentage,
  });

  factory StatisticsVaccine.fromJson(Map<String, dynamic> json) {
    return StatisticsVaccine(
      name: json['name']?.toString() ?? 'Biologico',
      code: json['code']?.toString() ?? '',
      doses: (json['doses'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  final String name;
  final String code;
  final int doses;
  final double percentage;
}

class StatisticsVaccinator {
  const StatisticsVaccinator({
    required this.id,
    required this.name,
    required this.doses,
    required this.uniquePatients,
  });

  factory StatisticsVaccinator.fromJson(Map<String, dynamic> json) {
    return StatisticsVaccinator(
      id: json['vaccinatorId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Vacunador',
      doses: (json['doses'] as num?)?.toInt() ?? 0,
      uniquePatients: (json['uniquePatients'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final int doses;
  final int uniquePatients;
}
