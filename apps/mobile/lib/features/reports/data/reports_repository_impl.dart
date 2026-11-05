import 'package:drift/drift.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/app_database.dart';
import '../domain/entities/report_summary.dart';
import '../domain/repositories/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl({required this.api, this.database});

  final ApiClient api;
  final AppDatabase? database;

  @override
  Future<ReportSummary> fetchSummary(
    String accessToken, {
    required DateTime from,
    required DateTime to,
    String? institutionId,
  }) async {
    try {
      final json = await api.fetchRegistroDiarioSummary(
        accessToken,
        from: from,
        to: to,
      );
      return ReportSummary.fromJson(json);
    } catch (_) {
      if (database != null && institutionId != null) {
        return _localSummary(institutionId, from, to);
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> exportReport(
    String accessToken, {
    required DateTime from,
    required DateTime to,
    String format = 'xlsx',
  }) {
    return api.downloadRegistroDiario(
      accessToken,
      from: from,
      to: to,
      format: format,
    );
  }

  Future<ReportSummary> _localSummary(
    String institutionId,
    DateTime from,
    DateTime to,
  ) async {
    final db = database!;
    final fromMs = from.millisecondsSinceEpoch;
    final toMs = to.millisecondsSinceEpoch;

    final attentions =
        await (db.select(db.attentionsLocal)..where(
              (tbl) =>
                  tbl.institutionId.equals(institutionId) &
                  tbl.status.equals('CANCELLED').not() &
                  tbl.attentionDate.isBiggerOrEqualValue(fromMs) &
                  tbl.attentionDate.isSmallerOrEqualValue(toMs),
            ))
            .get();

    if (attentions.isEmpty) {
      return ReportSummary.zero;
    }

    final attentionIds = attentions.map((a) => a.id).toSet();
    final patientIds = attentions.map((a) => a.patientId).toSet();

    final doses =
        await (db.select(db.appliedDosesLocal)..where(
              (tbl) =>
                  tbl.attentionId.isIn(attentionIds) &
                  tbl.status.equals('CANCELLED').not(),
            ))
            .get();

    final vaccineCodes = doses
        .map((d) => d.vaccineNameSnapshot)
        .where((name) => name.trim().isNotEmpty)
        .toSet();

    return ReportSummary(
      patientsCount: patientIds.length,
      dosesCount: doses.length,
      vaccineTypesCount: vaccineCodes.length,
    );
  }
}
