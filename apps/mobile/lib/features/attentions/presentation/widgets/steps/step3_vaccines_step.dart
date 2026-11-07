import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../../../core/auth/offline_access.dart';
import '../../../../../core/utils/field_input.dart';
import '../../../../catalogs/domain/entities/effective_catalog.dart';
import '../../attention_controller.dart';
import 'form_helpers.dart';
import 'staged_dose_data.dart';

/// Paso 3: Selección de Vacunas y Registro de Dosis.
/// Presenta tarjetas expandibles para cada vacuna del catálogo efectivo,
/// selector de dosis tipo chips interactivos con estados y formulario detallado.
class Step3VaccinesStep extends StatefulWidget {
  const Step3VaccinesStep({
    required this.controller,
    required this.offline,
    required this.attentionDate,
    required this.stagedDoses,
    required this.onStagedDoseChanged,
    required this.onStagedDoseRemoved,
    super.key,
  });

  final AttentionController controller;
  final OfflineAccess offline;
  final DateTime attentionDate;
  final Map<String, StagedDose>
  stagedDoses; // key: "${vaccineId}_${doseOptionId}"
  final ValueChanged<StagedDose> onStagedDoseChanged;
  final ValueChanged<String> onStagedDoseRemoved; // key

  @override
  State<Step3VaccinesStep> createState() => _Step3VaccinesStepState();
}

class _Step3VaccinesStepState extends State<Step3VaccinesStep>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _expandedVaccines = {};
  String? _activeDoseKey;

  // Controladores temporales para la dosis activa en edición
  final _lotController = TextEditingController();
  final _syringeLotController = TextEditingController();
  final _diluentController = TextEditingController();
  final _vialCountController = TextEditingController();
  final _customObservationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _lotController.dispose();
    _syringeLotController.dispose();
    _diluentController.dispose();
    _vialCountController.dispose();
    _customObservationController.dispose();
    super.dispose();
  }

  void _syncControllersWithDose(StagedDose dose) {
    _lotController.text = dose.lotNumber;
    _syringeLotController.text = dose.syringeLot ?? '';
    _diluentController.text = dose.diluent ?? '';
    _vialCountController.text = dose.vialCount != null
        ? dose.vialCount.toString()
        : '';
    _customObservationController.text = dose.customObservation ?? '';
  }

  void _onDoseChipTapped(EffectiveVaccine vaccine, EffectiveOption doseOption) {
    final key = '${vaccine.vaccineId}_${doseOption.id}';

    if (_activeDoseKey == key) {
      return;
    }

    // Si ya existía un borrador de esta dosis, cargarla
    StagedDose staged;
    if (widget.stagedDoses.containsKey(key)) {
      staged = widget.stagedDoses[key]!;
    } else {
      staged = StagedDose(
        vaccineId: vaccine.vaccineId,
        doseOptionId: doseOption.id,
        vaccineName: vaccine.name,
        doseDisplayName: doseOption.displayName,
        applicationDate: widget.attentionDate,
      );
      widget.onStagedDoseChanged(staged);
    }

    setState(() {
      _activeDoseKey = key;
      _syncControllersWithDose(staged);
    });
  }

  void _saveCurrentDose(StagedDose current) {
    final lot = _lotController.text.trim();
    if (lot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El número de lote es obligatorio.')),
      );
      return;
    }

    final updated = current.copyWith(
      lotNumber: lot,
      syringeLot: _syringeLotController.text.trim().isEmpty
          ? null
          : _syringeLotController.text.trim(),
      diluent: _diluentController.text.trim().isEmpty
          ? null
          : _diluentController.text.trim(),
      vialCount: int.tryParse(_vialCountController.text.trim()),
      customObservation: _customObservationController.text.trim().isEmpty
          ? null
          : _customObservationController.text.trim(),
      isCompleted: true,
    );

    widget.onStagedDoseChanged(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dosis ${updated.doseDisplayName} configurada.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeCurrentDose(String key) {
    widget.onStagedDoseRemoved(key);
    setState(() {
      if (_activeDoseKey == key) {
        _activeDoseKey = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final vaccines = widget.controller.effectiveVaccines;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vacunas y Dosis',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Selecciona la vacuna y completa la información de la dosis a aplicar.',
                style: TextStyle(color: AppColors.slate, fontSize: 13.5),
              ),
            ],
          ),
        ),

        // Estado del Catálogo
        if (!widget.controller.effectiveCatalogLoaded)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (vaccines.isEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.vaccines_outlined,
                  size: 56,
                  color: AppColors.slate.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No hay vacunas disponibles',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tu institución no tiene biológicos habilitados en el catálogo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...vaccines.map((vaccine) => _buildVaccineCard(vaccine)),
      ],
    );
  }

  Widget _buildVaccineCard(EffectiveVaccine vaccine) {
    final isExpanded = _expandedVaccines.contains(vaccine.vaccineId);
    final hasStagedDoses = widget.stagedDoses.values.any(
      (d) => d.vaccineId == vaccine.vaccineId && d.isCompleted,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasStagedDoses ? AppColors.primary : AppColors.border,
          width: hasStagedDoses ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Tappeable
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedVaccines.remove(vaccine.vaccineId);
                } else {
                  _expandedVaccines.add(vaccine.vaccineId);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar con inicial
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        vaccine.name.isNotEmpty
                            ? vaccine.name[0].toUpperCase()
                            : 'V',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Nombre e Información
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vaccine.name,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${vaccine.code} • ${vaccine.doses.length} dosis registrables',
                          style: const TextStyle(
                            color: AppColors.slate,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Icono expansión
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.slate,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          // Contenido Expandible
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de Dosis Disponibles (Chips)
                  const Text(
                    'Dosis Disponibles',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: vaccine.doses.map((doseOption) {
                      final key = '${vaccine.vaccineId}_${doseOption.id}';
                      final isActive = _activeDoseKey == key;
                      final isCompleted =
                          widget.stagedDoses[key]?.isCompleted ?? false;

                      Color bg;
                      Color textColor;
                      IconData? icon;

                      if (isActive) {
                        bg = AppColors.primary;
                        textColor = Colors.white;
                        icon = Icons.edit_rounded;
                      } else if (isCompleted) {
                        bg = AppColors.successSoft;
                        textColor = AppColors.success;
                        icon = Icons.check_circle_rounded;
                      } else {
                        bg = AppColors.surfaceAlt;
                        textColor = AppColors.ink;
                        icon = null;
                      }

                      return InkWell(
                        onTap: () => _onDoseChipTapped(vaccine, doseOption),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                  : (isCompleted
                                        ? AppColors.success.withValues(
                                            alpha: 0.5,
                                          )
                                        : AppColors.border),
                              width: isActive ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                Icon(icon, size: 15, color: textColor),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                doseOption.displayName,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: isActive || isCompleted
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Leyenda
                  Row(
                    children: [
                      _legendItem(
                        Icons.edit_rounded,
                        'Activa',
                        AppColors.primary,
                      ),
                      const SizedBox(width: 14),
                      _legendItem(
                        Icons.check_circle_rounded,
                        'Completada',
                        AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Formulario de la dosis activa
                  if (_activeDoseKey != null &&
                      _activeDoseKey!.startsWith('${vaccine.vaccineId}_'))
                    _buildActiveDoseForm(vaccine),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 11)),
    ],
  );

  Widget _buildActiveDoseForm(EffectiveVaccine vaccine) {
    final currentDose = widget.stagedDoses[_activeDoseKey!];
    if (currentDose == null) return const SizedBox.shrink();

    final laboratories = vaccine.operationalOptions
        .where((o) => o.fieldType == 'LABORATORY')
        .toList();
    final syringes = vaccine.operationalOptions
        .where((o) => o.fieldType == 'SYRINGE')
        .toList();
    final droppers = vaccine.operationalOptions
        .where((o) => o.fieldType == 'DROPPER')
        .toList();
    final observations = vaccine.operationalOptions
        .where((o) => o.fieldType == 'OBSERVATION')
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de la dosis
            Row(
              children: [
                const Icon(
                  Icons.vaccines_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Datos de la ${currentDose.doseDisplayName}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.danger,
                  tooltip: 'Descartar esta dosis',
                  onPressed: () => _removeCurrentDose(_activeDoseKey!),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Fecha de aplicación
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: currentDose.applicationDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    currentDose.applicationDate = picked;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de Aplicación *',
                  prefixIcon: Icon(Icons.event, size: 20),
                ),
                child: Text(
                  formatDisplayDate(currentDose.applicationDate),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Laboratorio
            if (vaccine.hasLaboratory && laboratories.isNotEmpty) ...[
              DropdownButtonFormField<EffectiveOption>(
                initialValue:
                    laboratories.any(
                      (l) => l.id == currentDose.selectedLaboratoryId,
                    )
                    ? laboratories.firstWhere(
                        (l) => l.id == currentDose.selectedLaboratoryId,
                      )
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Laboratorio'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Seleccione laboratorio'),
                  ),
                  for (final lab in laboratories)
                    DropdownMenuItem(value: lab, child: Text(lab.displayName)),
                ],
                onChanged: (val) {
                  setState(() {
                    currentDose.selectedLaboratoryId = val?.id;
                    currentDose.laboratoryName = val?.displayName;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            // Lote de la Vacuna
            TextFormField(
              controller: _lotController,
              decoration: const InputDecoration(
                labelText: 'Número de Lote *',
                hintText: 'Ej: AB12345',
              ),
              onChanged: (val) => currentDose.lotNumber = val.trim(),
            ),
            const SizedBox(height: 12),

            // Jeringa
            if (vaccine.hasSyringe && syringes.isNotEmpty) ...[
              DropdownButtonFormField<EffectiveOption>(
                initialValue:
                    syringes.any((s) => s.id == currentDose.selectedSyringeId)
                    ? syringes.firstWhere(
                        (s) => s.id == currentDose.selectedSyringeId,
                      )
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jeringa'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Seleccione jeringa'),
                  ),
                  for (final syr in syringes)
                    DropdownMenuItem(value: syr, child: Text(syr.displayName)),
                ],
                onChanged: (val) {
                  setState(() {
                    currentDose.selectedSyringeId = val?.id;
                    currentDose.syringeName = val?.displayName;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            // Lote de Jeringa
            if (vaccine.hasSyringeLot) ...[
              TextFormField(
                controller: _syringeLotController,
                decoration: const InputDecoration(
                  labelText: 'Lote de Jeringa',
                  hintText: 'Ej: SYR987',
                ),
                onChanged: (val) => currentDose.syringeLot = val.trim(),
              ),
              const SizedBox(height: 12),
            ],

            // Diluyente
            if (vaccine.hasDiluent) ...[
              TextFormField(
                controller: _diluentController,
                decoration: const InputDecoration(
                  labelText: 'Diluyente',
                  hintText: 'Lote o código del diluyente',
                ),
                onChanged: (val) => currentDose.diluent = val.trim(),
              ),
              const SizedBox(height: 12),
            ],

            // Gotero
            if (vaccine.hasDropper && droppers.isNotEmpty) ...[
              DropdownButtonFormField<EffectiveOption>(
                initialValue:
                    droppers.any((d) => d.id == currentDose.selectedDropperId)
                    ? droppers.firstWhere(
                        (d) => d.id == currentDose.selectedDropperId,
                      )
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Gotero'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Seleccione gotero'),
                  ),
                  for (final drp in droppers)
                    DropdownMenuItem(value: drp, child: Text(drp.displayName)),
                ],
                onChanged: (val) {
                  setState(() {
                    currentDose.selectedDropperId = val?.id;
                    currentDose.dropperName = val?.displayName;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            // Tipo de Neumococo
            if (vaccine.hasPneumococcalType &&
                vaccine.pneumococcalTypes.isNotEmpty) ...[
              DropdownButtonFormField<EffectiveOption>(
                initialValue:
                    vaccine.pneumococcalTypes.any(
                      (p) => p.id == currentDose.pneumococcalTypeOptionId,
                    )
                    ? vaccine.pneumococcalTypes.firstWhere(
                        (p) => p.id == currentDose.pneumococcalTypeOptionId,
                      )
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Neumococo',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Seleccione tipo'),
                  ),
                  for (final pt in vaccine.pneumococcalTypes)
                    DropdownMenuItem(value: pt, child: Text(pt.displayName)),
                ],
                onChanged: (val) {
                  setState(() {
                    currentDose.pneumococcalTypeOptionId = val?.id;
                    currentDose.pneumococcalTypeName = val?.displayName;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            // Cantidad de Frascos
            if (vaccine.hasVialCount) ...[
              TextFormField(
                controller: _vialCountController,
                keyboardType: TextInputType.number,
                inputFormatters: digitsOnlyFormatters(max: 3),
                decoration: const InputDecoration(
                  labelText: 'Cantidad de Frascos',
                ),
                onChanged: (val) =>
                    currentDose.vialCount = int.tryParse(val.trim()),
              ),
              const SizedBox(height: 12),
            ],

            // Observación Predefinida
            if (vaccine.hasObservation && observations.isNotEmpty) ...[
              DropdownButtonFormField<EffectiveOption>(
                initialValue:
                    observations.any(
                      (o) => o.id == currentDose.selectedObservationId,
                    )
                    ? observations.firstWhere(
                        (o) => o.id == currentDose.selectedObservationId,
                      )
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Observación'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Sin observación'),
                  ),
                  for (final obs in observations)
                    DropdownMenuItem(value: obs, child: Text(obs.displayName)),
                ],
                onChanged: (val) {
                  setState(() {
                    currentDose.selectedObservationId = val?.id;
                    currentDose.observationName = val?.displayName;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

            // Observación Personalizada
            TextFormField(
              controller: _customObservationController,
              decoration: const InputDecoration(
                labelText: 'Observación Personalizada',
                hintText: 'Detalles adicionales sobre la aplicación',
              ),
              onChanged: (val) => currentDose.customObservation = val.trim(),
            ),
            const SizedBox(height: 14),

            // Botón Confirmar Dosis
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _saveCurrentDose(currentDose),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Confirmar esta dosis'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
