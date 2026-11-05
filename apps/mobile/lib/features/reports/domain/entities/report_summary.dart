class ReportSummary {
  const ReportSummary({
    required this.patientsCount,
    required this.dosesCount,
    required this.vaccineTypesCount,
  });

  final int patientsCount;
  final int dosesCount;
  final int vaccineTypesCount;

  static const zero = ReportSummary(
    patientsCount: 0,
    dosesCount: 0,
    vaccineTypesCount: 0,
  );

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      patientsCount: (json['patientsCount'] as num?)?.toInt() ?? 0,
      dosesCount: (json['dosesCount'] as num?)?.toInt() ?? 0,
      vaccineTypesCount: (json['vaccineTypesCount'] as num?)?.toInt() ?? 0,
    );
  }
}
