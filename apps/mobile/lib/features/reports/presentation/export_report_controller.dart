import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/presentation/async_controller.dart';
import '../domain/entities/report_summary.dart';
import '../domain/repositories/reports_repository.dart';

class ExportReportController extends AsyncController {
  ExportReportController({
    required super.sessionManager,
    required this.repository,
  });

  final ReportsRepository repository;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  ReportSummary _summary = ReportSummary.zero;
  bool _isExporting = false;

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  ReportSummary get summary => _summary;
  bool get isExporting => _isExporting;

  void setStartDate(DateTime start, {String? institutionId}) {
    if (start.isAfter(_endDate)) {
      _endDate = start;
    }
    _startDate = start;
    notifyListeners();
    loadSummary(institutionId: institutionId);
  }

  void setEndDate(DateTime end, {String? institutionId}) {
    if (end.isBefore(_startDate)) {
      _startDate = end;
    }
    _endDate = end;
    notifyListeners();
    loadSummary(institutionId: institutionId);
  }

  Future<void> loadSummary({String? institutionId}) async {
    final from = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      0,
      0,
      0,
    );
    final to = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      23,
      59,
      59,
    );

    await execute((token) async {
      _summary = await repository.fetchSummary(
        token,
        from: from,
        to: to,
        institutionId: institutionId,
      );
    });
  }

  Future<bool> exportAndShare({String format = 'xlsx'}) async {
    if (_isExporting) return false;
    _isExporting = true;
    notifyListeners();

    try {
      final from = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        0,
        0,
        0,
      );
      final to = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
      );

      Uint8List? bytes;
      await execute((token) async {
        bytes = await repository.exportReport(
          token,
          from: from,
          to: to,
          format: format,
        );
      });

      final fileBytes = bytes;
      if (fileBytes == null || fileBytes.isEmpty) {
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final fromStr =
          '${_startDate.year}${_startDate.month.toString().padLeft(2, '0')}${_startDate.day.toString().padLeft(2, '0')}';
      final toStr =
          '${_endDate.year}${_endDate.month.toString().padLeft(2, '0')}${_endDate.day.toString().padLeft(2, '0')}';
      final filename = 'registro-diario-$fromStr-$toStr.$format';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(fileBytes);

      final isCsv = format.toLowerCase() == 'csv';
      final mimeType = isCsv
          ? 'text/csv'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          subject: 'Reporte Registro Diario PAI ($fromStr a $toStr)',
        ),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}
