import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/clinical_components.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/utils/document_input.dart';
import '../../../catalogs/domain/entities/catalog_entities.dart';
import '../../../patients/presentation/patient_detail_controller.dart';
import '../../../patients/presentation/pages/patient_detail_page.dart';
import '../../domain/entities/attention.dart';
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
  final _number = TextEditingController();
  String _docType = 'CC';

  @override
  void initState() {
    super.initState();
    // Entra siempre en blanco: no arrastra la busqueda ni las atenciones de una
    // visita anterior (el dashboard recrea la pagina al cambiar de pestaña).
    widget.controller.clearSession();
    widget.controller.loadDocumentTypes();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  /// Tipo de identificacion con etiqueta "CODIGO - Nombre" (ej.
  /// "CC - Cedula de Ciudadania"), desde el catalogo `document_type`.
  List<DropdownMenuItem<String>> _documentTypeItems() {
    final options = widget.controller.documentTypes;
    final list = options.isEmpty ? documentTypeFallback : options;
    return [
      for (final option in list)
        DropdownMenuItem(
          value: option.code,
          child: Text('${option.code} - ${option.label}'),
        ),
    ];
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
        final patient = controller.patient;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Historial', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Consulta las atenciones y dosis aplicadas de un paciente.',
              style: TextStyle(color: AppColors.slate, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _docType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de documento',
                    ),
                    items: _documentTypeItems(),
                    onChanged: (value) =>
                        setState(() => _docType = value ?? 'CC'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _number,
                    keyboardType: documentKeyboardType(_docType),
                    inputFormatters: documentInputFormatters(_docType),
                    decoration: const InputDecoration(labelText: 'Documento'),
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: controller.isLoading ? null : _search,
                    icon: const Icon(Icons.search_rounded, size: 20),
                    label: const Text('Buscar historial'),
                  ),
                ],
              ),
            ),
            if (controller.error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (controller.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (patient == null)
              const EmptyState(
                icon: Icons.folder_shared_outlined,
                title: 'Busca un paciente',
                message:
                    'Ingresa un documento para ver sus atenciones y dosis '
                    'aplicadas.',
              )
            else ...[
              _PatientHeader(
                patientName: patient.fullName,
                documentType: patient.documentType,
                documentNumber: patient.documentNumber,
                onOpenProfile: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PatientDetailPage(
                      controller: widget.patientDetailController,
                      offline: widget.offline,
                      patientId: patient.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'ATENCIONES',
                    style: AppTextStyles.overline.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  if (controller.history.isNotEmpty)
                    StatusPill(
                      label: '${controller.history.length}',
                      tone: StatusTone.neutral,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (controller.history.isEmpty)
                const EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'Sin atenciones registradas',
                  message: 'Este paciente aun no tiene dosis aplicadas.',
                )
              else
                for (var i = 0; i < controller.history.length; i++)
                  _AttentionTimelineItem(
                    attention: controller.history[i],
                    isLast: i == controller.history.length - 1,
                  ),
            ],
          ],
        );
      },
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({
    required this.patientName,
    required this.documentType,
    required this.documentNumber,
    required this.onOpenProfile,
  });

  final String patientName;
  final String documentType;
  final String documentNumber;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IdentityStrip(
          documentType: documentType,
          documentNumber: documentNumber,
          name: patientName,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenProfile,
          icon: const Icon(Icons.badge_outlined, size: 18),
          label: const Text('Ver ficha del paciente'),
        ),
      ],
    ),
  );
}

/// Linea de tiempo clinica: cada atencion es un nodo sobre un riel vertical.
class _AttentionTimelineItem extends StatelessWidget {
  const _AttentionTimelineItem({required this.attention, required this.isLast});

  final Attention attention;
  final bool isLast;

  StatusTone get _tone => switch (attention.status) {
    'COMPLETED' => StatusTone.applied,
    'CANCELLED' => StatusTone.cancelled,
    _ => StatusTone.draft,
  };

  Color get _nodeColor => switch (attention.status) {
    'COMPLETED' => AppColors.success,
    'CANCELLED' => AppColors.danger,
    _ => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MonoText(
                            _formatDate(attention.attentionDate),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusPill(label: attention.statusLabel, tone: _tone),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${attention.doses.length} dosis'
                      '${attention.consecutive != null ? '  ·  Consecutivo ${attention.consecutive}' : ''}',
                      style: const TextStyle(
                        color: AppColors.hint,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    for (final dose in attention.doses) _DoseLine(dose: dose),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha desconocida';
    final local = date.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }
}

class _DoseLine extends StatelessWidget {
  const _DoseLine({required this.dose});

  final AppliedDose dose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dose.isCancelled ? AppColors.danger : AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.vaccineNameSnapshot,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${dose.doseLabelSnapshot}'
                  '${(dose.lotNumber ?? '').isNotEmpty ? '  ·  Lote ${dose.lotNumber}' : ''}',
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (dose.isCancelled)
            const StatusPill(label: 'Anulada', tone: StatusTone.cancelled),
        ],
      ),
    );
  }
}
