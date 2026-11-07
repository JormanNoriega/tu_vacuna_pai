import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../../../core/auth/offline_access.dart';
import '../../../../../core/utils/document_input.dart';
import '../../../../../core/utils/document_rules.dart';
import '../../../../../core/utils/field_input.dart';
import '../../../../catalogs/domain/entities/catalog_entities.dart';
import '../../../../patients/domain/entities/patient.dart';
import '../../attention_controller.dart';
import 'form_helpers.dart';

/// Paso 1: Datos Básicos del Paciente con búsqueda automática por documento,
/// cálculo reactivo de edad y selector de esquema completo.
class Step1BasicDataStep extends StatefulWidget {
  const Step1BasicDataStep({
    required this.formKey,
    required this.controller,
    required this.offline,
    required this.attentionDate,
    required this.onAttentionDateChanged,
    required this.documentType,
    required this.onDocumentTypeChanged,
    required this.documentNumberController,
    required this.firstNameController,
    required this.secondNameController,
    required this.lastNameController,
    required this.secondLastNameController,
    required this.birthDate,
    required this.onBirthDateChanged,
    required this.completeScheme,
    required this.onCompleteSchemeChanged,
    required this.onExistingPatientLoaded,
    this.isExistingPatient = false,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final AttentionController controller;
  final OfflineAccess offline;
  final DateTime attentionDate;
  final ValueChanged<DateTime> onAttentionDateChanged;
  final String documentType;
  final ValueChanged<String> onDocumentTypeChanged;
  final TextEditingController documentNumberController;
  final TextEditingController firstNameController;
  final TextEditingController secondNameController;
  final TextEditingController lastNameController;
  final TextEditingController secondLastNameController;
  final DateTime? birthDate;
  final ValueChanged<DateTime?> onBirthDateChanged;
  final bool completeScheme;
  final ValueChanged<bool> onCompleteSchemeChanged;
  final ValueChanged<Patient> onExistingPatientLoaded;
  final bool isExistingPatient;

  @override
  State<Step1BasicDataStep> createState() => _Step1BasicDataStepState();
}

class _Step1BasicDataStepState extends State<Step1BasicDataStep>
    with AutomaticKeepAliveClientMixin {
  Timer? _debounceTimer;
  String? _lastCheckedId;
  bool _searching = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onDocumentNumberChanged(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim();

    if (widget.isExistingPatient ||
        trimmed.length < 4 ||
        trimmed == _lastCheckedId) {
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      _lastCheckedId = trimmed;
      setState(() => _searching = true);

      try {
        await widget.controller.findPatients(
          offline: widget.offline,
          documentType: widget.documentType,
          documentNumber: trimmed,
        );
      } finally {
        if (mounted) setState(() => _searching = false);
      }

      if (!mounted) return;
      if (widget.controller.searchResults.isNotEmpty) {
        final found = widget.controller.searchResults.firstWhere(
          (p) =>
              p.documentNumber.trim() == trimmed &&
              p.documentType == widget.documentType,
          orElse: () => widget.controller.searchResults.first,
        );
        _showPatientFoundDialog(found);
      }
    });
  }

  void _showPatientFoundDialog(Patient patient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Paciente Encontrado',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ya existe un paciente registrado con este documento:',
              style: TextStyle(color: AppColors.slate, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${patient.documentType} • ${patient.documentNumber}',
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '¿Deseas cargar los datos de este paciente para registrar su atención?',
              style: TextStyle(color: AppColors.ink, fontSize: 13.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _lastCheckedId = null;
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              widget.onExistingPatientLoaded(patient);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sí, cargar paciente'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttentionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.attentionDate,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Seleccionar fecha de atención',
    );
    if (picked != null) {
      widget.onAttentionDateChanged(picked);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          widget.birthDate ?? DateTime(now.year - 5, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Seleccionar fecha de nacimiento',
    );
    if (picked != null) {
      widget.onBirthDateChanged(picked);
    }
  }

  List<ReferenceOption> _documentTypes() {
    final options = widget.controller.referenceOptions('document_type');
    return options.isEmpty ? documentTypeFallback : options;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final rule = documentRuleFor(widget.documentType);
    final maxLen = rule?.maxLength ?? 20;
    final minLen = rule?.minLength ?? 4;

    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Datos Básicos del Paciente',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Complete la información básica del paciente o busque por documento.',
                  style: TextStyle(color: AppColors.slate, fontSize: 13.5),
                ),
              ],
            ),
          ),

          // Tarjeta Única
          FormCard(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fecha de Atención
                InkWell(
                  onTap: _pickAttentionDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Atención',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                    ),
                    child: Text(
                      formatDisplayDate(widget.attentionDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tipo de Documento
                DropdownButtonFormField<String>(
                  initialValue: widget.documentType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Documento *',
                  ),
                  items: [
                    for (final opt in _documentTypes())
                      DropdownMenuItem(
                        value: opt.code,
                        child: Text('${opt.code} - ${opt.label}'),
                      ),
                  ],
                  onChanged: widget.isExistingPatient
                      ? null
                      : (val) {
                          if (val != null) {
                            widget.onDocumentTypeChanged(val);
                          }
                        },
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Selecciona el tipo' : null,
                ),
                const SizedBox(height: 16),

                // Número de Identificación
                TextFormField(
                  controller: widget.documentNumberController,
                  enabled: !widget.isExistingPatient,
                  keyboardType: documentKeyboardType(widget.documentType),
                  inputFormatters: [
                    ...documentInputFormatters(widget.documentType),
                    ...maxLengthFormatters(maxLen),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Número de Identificación *',
                    hintText: 'Ej: 1020304050',
                    suffixIcon: _searching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _onDocumentNumberChanged,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ingresa el número de identificación';
                    }
                    if (val.trim().length < minLen) {
                      return 'Mínimo $minLen dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Primer Nombre
                TextFormField(
                  controller: widget.firstNameController,
                  enabled: !widget.isExistingPatient,
                  inputFormatters: maxLengthFormatters(FieldLimits.name),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Primer Nombre *',
                    hintText: 'Ingrese el primer nombre',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Primer nombre requerido'
                      : null,
                ),
                const SizedBox(height: 16),

                // Segundo Nombre
                TextFormField(
                  controller: widget.secondNameController,
                  enabled: !widget.isExistingPatient,
                  inputFormatters: maxLengthFormatters(FieldLimits.name),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Segundo Nombre (opcional)',
                    hintText: 'Ingrese el segundo nombre',
                  ),
                ),
                const SizedBox(height: 16),

                // Primer Apellido
                TextFormField(
                  controller: widget.lastNameController,
                  enabled: !widget.isExistingPatient,
                  inputFormatters: maxLengthFormatters(FieldLimits.name),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Primer Apellido *',
                    hintText: 'Ingrese el primer apellido',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Primer apellido requerido'
                      : null,
                ),
                const SizedBox(height: 16),

                // Segundo Apellido
                TextFormField(
                  controller: widget.secondLastNameController,
                  enabled: !widget.isExistingPatient,
                  inputFormatters: maxLengthFormatters(FieldLimits.name),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Segundo Apellido (opcional)',
                    hintText: 'Ingrese el segundo apellido',
                  ),
                ),
                const SizedBox(height: 16),

                // Fecha de Nacimiento
                FormField<DateTime>(
                  initialValue: widget.birthDate,
                  validator: (val) => widget.birthDate == null
                      ? 'Fecha de nacimiento requerida'
                      : null,
                  builder: (state) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: widget.isExistingPatient ? null : _pickBirthDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Fecha de Nacimiento *',
                            prefixIcon: const Icon(
                              Icons.cake_outlined,
                              size: 20,
                            ),
                            errorText: state.errorText,
                          ),
                          child: Text(
                            widget.birthDate != null
                                ? formatDisplayDate(widget.birthDate!)
                                : 'Seleccione la fecha de nacimiento',
                            style: TextStyle(
                              color: widget.birthDate != null
                                  ? AppColors.ink
                                  : AppColors.hint,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tarjeta de Edad Calculada
                if (widget.birthDate != null) ...[
                  const SizedBox(height: 16),
                  AgeSummaryCard(birthDate: widget.birthDate!),
                ],

                const SizedBox(height: 18),

                // Esquema Completo
                const Text(
                  '¿Esquema Completo?',
                  style: TextStyle(
                    color: AppColors.slate,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SelectionOptionButton(
                        label: 'Sí',
                        icon: Icons.check_circle_outline_rounded,
                        isSelected: widget.completeScheme == true,
                        onTap: () => widget.onCompleteSchemeChanged(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectionOptionButton(
                        label: 'No',
                        icon: Icons.cancel_outlined,
                        isSelected: widget.completeScheme == false,
                        onTap: () => widget.onCompleteSchemeChanged(false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
