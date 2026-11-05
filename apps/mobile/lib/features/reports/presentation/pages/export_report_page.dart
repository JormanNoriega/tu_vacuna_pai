import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../export_report_controller.dart';

class ExportReportPage extends StatefulWidget {
  const ExportReportPage({
    required this.user,
    required this.controller,
    super.key,
  });

  final AuthUser user;
  final ExportReportController controller;

  @override
  State<ExportReportPage> createState() => _ExportReportPageState();
}

class _ExportReportPageState extends State<ExportReportPage> {
  String _selectedFormat = 'xlsx';

  @override
  void initState() {
    super.initState();
    if (widget.user.hasPermission('USER_MANAGE')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.loadSummary(
          institutionId: widget.user.institution.id,
        );
      });
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.controller.startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      widget.controller.setStartDate(
        picked,
        institutionId: widget.user.institution.id,
      );
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.controller.endDate,
      firstDate: widget.controller.startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      widget.controller.setEndDate(
        picked,
        institutionId: widget.user.institution.id,
      );
    }
  }

  Future<void> _handleExport() async {
    final ok = await widget.controller.exportAndShare(format: _selectedFormat);
    if (!mounted) return;
    if (!ok && widget.controller.error != null) {
      AppSnackbar.error(
        context,
        widget.controller.error ?? 'No se pudo generar el reporte.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.hasPermission('USER_MANAGE')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Restringido')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 56,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Acceso no autorizado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Esta vista solo esta disponible para los administradores del hospital.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Exportar Registros',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final startDateStr = _formatDate(widget.controller.startDate);
          final endDateStr = _formatDate(widget.controller.endDate);
          final summary = widget.controller.summary;
          final isXlsx = _selectedFormat == 'xlsx';

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionLabel('FORMATO DE EXPORTACIÓN'),
                        const SizedBox(height: 10),
                        _buildFormatSelector(),
                        const SizedBox(height: 14),
                        _buildInfoBanner(),
                        const SizedBox(height: 24),
                        _buildSectionLabel('RANGO DE FECHAS'),
                        const SizedBox(height: 12),
                        _buildDateCard(
                          label: 'Fecha de inicio',
                          value: startDateStr,
                          onTap: _pickStartDate,
                        ),
                        const SizedBox(height: 12),
                        _buildDateCard(
                          label: 'Fecha de fin',
                          value: endDateStr,
                          onTap: _pickEndDate,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Text(
                              'Resumen',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$startDateStr - $endDateStr',
                                style: const TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildMetricCard(
                          icon: Icons.people_alt_rounded,
                          iconColor: const Color(0xFF4CAF50),
                          iconBgColor: const Color(0xFFE8F5E9),
                          value: '${summary.patientsCount}',
                          label: 'PACIENTES EN EL RANGO',
                        ),
                        const SizedBox(height: 12),
                        _buildMetricCard(
                          icon: Icons.vaccines_rounded,
                          iconColor: const Color(0xFF1E88E5),
                          iconBgColor: const Color(0xFFE1F5FE),
                          value: '${summary.dosesCount}',
                          label: 'DOSIS APLICADAS',
                        ),
                        const SizedBox(height: 12),
                        _buildMetricCard(
                          icon: Icons.medical_services_rounded,
                          iconColor: const Color(0xFFFF9800),
                          iconBgColor: const Color(0xFFFFF3E0),
                          value: '${summary.vaccineTypesCount}',
                          label: 'TIPOS DE VACUNAS USADAS',
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: widget.controller.isExporting
                              ? null
                              : _handleExport,
                          icon: widget.controller.isExporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.file_upload_outlined,
                                  size: 20,
                                ),
                          label: Text(
                            widget.controller.isExporting
                                ? 'Generando archivo...'
                                : (isXlsx
                                      ? 'Exportar y Compartir Excel'
                                      : 'Exportar y Compartir CSV'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isXlsx
                            ? 'El archivo se generará en formato XLSX con encabezados categorizados y datos clínicos.'
                            : 'El archivo se generará en formato CSV delimitado por comas, ideal para análisis de datos.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildFormatSelector() {
    final isXlsx = _selectedFormat == 'xlsx';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFormatTab(
              label: 'Excel (.xlsx)',
              icon: _buildExcelBadge(isSelected: isXlsx),
              isSelected: isXlsx,
              onTap: () {
                if (_selectedFormat != 'xlsx') {
                  setState(() => _selectedFormat = 'xlsx');
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildFormatTab(
              label: 'CSV (.csv)',
              icon: _buildCsvBadge(isSelected: !isXlsx),
              isSelected: !isXlsx,
              onTap: () {
                if (_selectedFormat != 'csv') {
                  setState(() => _selectedFormat = 'csv');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatTab({
    required String label,
    required Widget icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExcelBadge({required bool isSelected}) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Text(
        'X',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildCsvBadge({required bool isSelected}) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Text(
        'CSV',
        style: TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    final isXlsx = _selectedFormat == 'xlsx';
    final text = isXlsx
        ? 'Exporta los registros de vacunación en formato Excel con encabezados categorizados y colores profesionales.'
        : 'Exporta los registros de vacunación en formato CSV con valores delimitados por comas.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'i',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
