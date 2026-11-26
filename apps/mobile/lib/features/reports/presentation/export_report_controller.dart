import 'dart:io';

import 'package:flutter/foundation.dart';
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
  String? _vaccinatorId;
  List<Map<String, dynamic>> _vaccinators = [];
  int _summaryRequest = 0;

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  ReportSummary get summary => _summary;
  bool get isExporting => _isExporting;
  String? get vaccinatorId => _vaccinatorId;
  List<Map<String, dynamic>> get vaccinators => _vaccinators;

  void setDateRange(DateTime start, DateTime end, {String? institutionId}) {
    _startDate = start;
    _endDate = end;
    _vaccinatorId = null;
    _vaccinators = [];
    notifyListeners();
    loadSummary(institutionId: institutionId, refreshVaccinators: true);
  }

  void setVaccinator(String? id, {String? institutionId}) {
    _vaccinatorId = id;
    notifyListeners();
    loadSummary(institutionId: institutionId);
  }

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

  Future<void> loadSummary({String? institutionId, bool refreshVaccinators = false}) async {
    final request = ++_summaryRequest;
    final selectedVaccinator = _vaccinatorId;
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
      final summary = await repository.fetchSummary(
        token,
        from: from,
        to: to,
        institutionId: institutionId,
        vaccinatorId: selectedVaccinator,
      );
      if (request == _summaryRequest) _summary = summary;
      if (refreshVaccinators) {
        final vaccinators = await repository.fetchVaccinators(token, from: from, to: to);
        if (request == _summaryRequest) _vaccinators = vaccinators;
      }
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
          vaccinatorId: _vaccinatorId,
        );
      });

      final fileBytes = bytes;
      if (fileBytes == null || fileBytes.isEmpty) {
        return false;
      }

      final fromStr =
          '${_startDate.year}${_startDate.month.toString().padLeft(2, '0')}${_startDate.day.toString().padLeft(2, '0')}';
      final toStr =
          '${_endDate.year}${_endDate.month.toString().padLeft(2, '0')}${_endDate.day.toString().padLeft(2, '0')}';
      final filename = 'registro-diario-$fromStr-$toStr.$format';

      final isCsv = format.toLowerCase() == 'csv';
      final mimeType = isCsv
          ? 'text/csv'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      final XFile xfile;
      if (kIsWeb) {
        xfile = XFile.fromData(
          fileBytes,
          mimeType: mimeType,
          name: filename,
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(fileBytes);
        xfile = XFile(file.path, mimeType: mimeType, name: filename);
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [xfile],
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
