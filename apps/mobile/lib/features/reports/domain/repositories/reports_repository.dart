import 'dart:typed_data';

import '../entities/report_summary.dart';

abstract interface class ReportsRepository {
  Future<ReportSummary> fetchSummary(
    String accessToken, {
    required DateTime from,
    required DateTime to,
    String? institutionId,
  });

  Future<Uint8List> exportReport(
    String accessToken, {
    required DateTime from,
    required DateTime to,
    String format = 'xlsx',
  });
}
