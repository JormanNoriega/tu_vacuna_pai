import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/utils/document_input.dart';
import '../../../patients/presentation/patient_detail_controller.dart';
import '../../../patients/presentation/pages/patient_detail_page.dart';
import '../history_controller.dart';

/// Historial de atenciones de un paciente (busqueda por documento).
class HistorialPage extends StatefulWidget {
  const HistorialPage({
    required this.controller,
    required this.patientDetailController,
    required this.offline,
    super.key,
  });

  final HistoryController controller;
  final PatientDetailController patientDetailController;
  final OfflineAccess offline;

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  static const _documentTypes = ['CC', 'TI', 'CE', 'PASAPORTE'];

  final _number = TextEditingController();
  String _docType = 'CC';

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    final number = _number.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el numero de documento.')),
      );
      return;
    }
    await widget.controller.loadHistory(
      documentType: _docType,
      documentNumber: number,
    );
    if (!mounted) return;
    if (widget.controller.patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontro un paciente con ese documento.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Historial', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Consulta las atenciones y dosis aplicadas de un paciente.',
              style: TextStyle(color: AppColors.slate, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    initialValue: _docType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: [
                      for (final type in _documentTypes)
                        DropdownMenuItem(value: type, child: Text(type)),
                    ],
                    onChanged: (value) =>
                        setState(() => _docType = value ?? 'CC'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _number,
                    keyboardType: documentKeyboardType(_docType),
                    inputFormatters: documentInputFormatters(_docType),
                    decoration: const InputDecoration(labelText: 'Documento'),
                    onSubmitted: (_) => _search(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: controller.isLoading ? null : _search,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Buscar historial'),
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 16),
              Text(
                controller.error!,
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            ],
            const SizedBox(height: 24),
            if (controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (controller.patient == null)
              const Text(
                'Busca un paciente para ver su historial.',
                style: TextStyle(color: AppColors.slate),
              )
            else ...[
              Text(
                controller.patient!.fullName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PatientDetailPage(
                        controller: widget.patientDetailController,
                        offline: widget.offline,
                        patientId: controller.patient!.id,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: const Text('Ver ficha del paciente'),
                ),
              ),
              const SizedBox(height: 12),
              if (controller.history.isEmpty)
                const Text(
                  'Sin atenciones registradas.',
                  style: TextStyle(color: AppColors.slate),
                )
              else
                for (final attention in controller.history)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      title: Text(
                        'Atencion del '
                        '${_formatDate(attention.attentionDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${attention.statusLabel} · '
                        '${attention.doses.length} dosis',
                      ),
                      children: [
                        for (final dose in attention.doses)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              dose.isCancelled
                                  ? Icons.cancel_outlined
                                  : Icons.check_circle_outline,
                              color: dose.isCancelled
                                  ? AppColors.warning
                                  : AppColors.success,
                              size: 20,
                            ),
                            title: Text(dose.vaccineNameSnapshot),
                            subtitle: Text(
                              '${dose.doseLabelSnapshot}'
                              '${dose.lotNumber != null ? ' · Lote ${dose.lotNumber}' : ''}'
                              '${dose.isCancelled ? ' · ANULADA' : ''}',
                            ),
                          ),
                      ],
                    ),
                  ),
            ],
          ],
        );
      },
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'fecha desconocida';
    final local = date.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }
}
