import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/clinical_components.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/utils/document_input.dart';
import '../../../../core/utils/field_input.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/domain/entities/session_restore_result.dart';
import '../../../catalogs/domain/entities/catalog_entities.dart';
import '../../../catalogs/domain/entities/effective_catalog.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../patients/presentation/pages/patient_wizard_page.dart';
import '../../domain/entities/attention.dart';
import '../attention_controller.dart';

/// Flujo de una nueva atencion: buscar o registrar paciente, seleccionar la
/// vacuna del catalogo efectivo, registrar dosis y completar la atencion.
class NuevaAtencionPage extends StatefulWidget {
  const NuevaAtencionPage({
    required this.user,
    required this.controller,
    required this.offline,
    super.key,
  });

  final AuthUser user;
  final AttentionController controller;
  final OfflineAccess offline;

  @override
  State<NuevaAtencionPage> createState() => _NuevaAtencionPageState();
}

class _NuevaAtencionPageState extends State<NuevaAtencionPage> {
  final _searchNumber = TextEditingController();
  final _lotNumber = TextEditingController();
  final _syringeLot = TextEditingController();
  final _diluent = TextEditingController();
  final _vialCount = TextEditingController();
  final _customObservation = TextEditingController();
  final _observations = TextEditingController();
  final _paiwebReason = TextEditingController();
  final _attentionDateText = TextEditingController();
  String _searchDocType = 'CC';
  bool _searched = false;
  bool _completeScheme = false;
  bool _paiwebRegistered = true;

  EffectiveVaccine? _vaccine;
  EffectiveOption? _dose;
  EffectiveOption? _pneumo;
  EffectiveOption? _laboratory;
  EffectiveOption? _syringe;
  EffectiveOption? _dropper;
  EffectiveOption? _observation;
  DateTime? _attentionDate;
  bool _submittingDose = false;
  final _doseFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // La fecha de atencion arranca en hoy (fecha local del dispositivo) para
    // agilizar el registro; el vacunador solo la cambia si aplico otro dia.
    final today = DateTime.now();
    _attentionDate = today;
    _attentionDateText.text = _displayDate(today);
    widget.controller.loadReferenceCatalogs();
    // No arrastrar la busqueda de una visita anterior (el dashboard recrea la
    // pagina al cambiar de pestaña).
    widget.controller.clearSearch();
  }

  @override
  void dispose() {
    _searchNumber.dispose();
    _lotNumber.dispose();
    _syringeLot.dispose();
    _diluent.dispose();
    _vialCount.dispose();
    _customObservation.dispose();
    _observations.dispose();
    _paiwebReason.dispose();
    _attentionDateText.dispose();
    super.dispose();
  }

  static String _isoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _displayDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  Future<void> _pickAttentionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _attentionDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Fecha de atencion',
    );
    if (picked == null) return;
    setState(() {
      _attentionDate = picked;
      _attentionDateText.text = _displayDate(picked);
    });
  }

  /// Pide un motivo (obligatorio) para una anulacion. Devuelve null si cancela.
  Future<String?> _promptReason(String title) => showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title: title),
  );

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    final number = _searchNumber.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el numero de documento.')),
      );
      return;
    }
    await widget.controller.findPatients(
      offline: widget.offline,
      documentType: _searchDocType,
      documentNumber: number,
    );
    if (!mounted) return;
    setState(() => _searched = true);
    if (widget.controller.searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontro un paciente con ese documento.'),
        ),
      );
    }
  }

  Future<void> _createPatient() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PatientWizardPage(
          controller: widget.controller,
          offline: widget.offline,
        ),
      ),
    );
    if (!mounted) return;
    // Al volver del alta rapida, deja la busqueda en blanco: sin documento ni
    // resultados previos.
    setState(() {
      _searchNumber.clear();
      _searched = false;
    });
    widget.controller.clearSearch();
    if (created == true) {
      await widget.controller.loadEffectiveCatalog();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Paciente registrado.')));
    }
  }

  /// Selecciona un paciente y carga el catalogo efectivo para aplicar vacuna.
  Future<void> _selectPatient(Patient patient) async {
    widget.controller.selectPatient(patient);
    await widget.controller.loadEffectiveCatalog();
  }

  Future<void> _addDose() async {
    if (!(_doseFormKey.currentState?.validate() ?? false)) return;
    final vaccine = _vaccine!;
    final dose = _dose!;
    final dateIso = _attentionDate == null
        ? null
        : '${_isoDate(_attentionDate!)}T12:00:00Z';

    // Si la atencion ya existe y el vacunador cambio la fecha, se actualiza
    // antes de registrar: todas las dosis de la visita comparten la fecha.
    // La actualizacion de detalles es online-only; en offline se conserva la
    // fecha con la que se creo la atencion.
    final attention = widget.controller.attention;
    if (attention != null &&
        dateIso != null &&
        widget.offline.status == SessionStatus.signedIn) {
      final current = attention.attentionDate == null
          ? null
          : _isoDate(attention.attentionDate!.toLocal());
      final selected = _isoDate(_attentionDate!);
      if (current != selected) {
        await widget.controller.updateAttentionDetails(
          offline: widget.offline,
          attentionDate: dateIso,
        );
        if (!mounted) return;
      }
    }

    setState(() => _submittingDose = true);
    final ok = await widget.controller.addDose(
      offline: widget.offline,
      vaccineId: vaccine.vaccineId,
      doseOptionId: dose.id,
      observations: _observations.text.trim(),
      attentionDate: dateIso,
      pneumococcalTypeOptionId: _pneumo?.id,
      lotNumber: _lotNumber.text.trim(),
      applicationDate: dateIso,
      selectedLaboratoryId: _laboratory?.id,
      selectedSyringeId: _syringe?.id,
      selectedDropperId: _dropper?.id,
      selectedObservationId: _observation?.id,
      syringeLot: _syringeLot.text.trim().isEmpty
          ? null
          : _syringeLot.text.trim(),
      diluent: _diluent.text.trim().isEmpty ? null : _diluent.text.trim(),
      vialCount: int.tryParse(_vialCount.text.trim()),
      customObservation: _customObservation.text.trim().isEmpty
          ? null
          : _customObservation.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _submittingDose = false;
      if (ok) {
        _dose = null;
        _pneumo = null;
        _laboratory = null;
        _syringe = null;
        _dropper = null;
        _observation = null;
        _lotNumber.clear();
        _syringeLot.clear();
        _diluent.clear();
        _vialCount.clear();
        _customObservation.clear();
      }
    });
  }

  Future<void> _cancelDose(String doseId) async {
    final reason = await _promptReason('Anular dosis');
    if (reason == null || !mounted) return;
    final ok = await widget.controller.cancelDoseFlow(
      offline: widget.offline,
      doseId: doseId,
      reason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Dosis anulada.' : 'No se pudo anular la dosis.'),
      ),
    );
  }

  Future<void> _cancelAttention() async {
    final reason = await _promptReason('Anular atencion');
    if (reason == null || !mounted) return;
    final ok = await widget.controller.cancelAttentionFlow(
      offline: widget.offline,
      reason: reason,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Atencion anulada.')));
      _resetFlow();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo anular la atencion.')),
      );
    }
  }

  Future<void> _finish() async {
    if (!_paiwebRegistered && _paiwebReason.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indica el motivo de no ingreso al aplicativo PAIWEB.'),
        ),
      );
      return;
    }
    final details = await widget.controller.updateAttentionDetails(
      offline: widget.offline,
      completeScheme: _completeScheme,
      paiwebRegistered: _paiwebRegistered,
      paiwebNotRegisteredReason: _paiwebRegistered
          ? null
          : _paiwebReason.text.trim(),
    );
    if (!mounted) return;
    if (details == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el cierre del registro.'),
        ),
      );
      return;
    }
    final ok = await widget.controller.finishAttention(offline: widget.offline);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Atencion completada.')));
      _resetFlow();
    }
  }

  /// Reinicia el flujo y limpia el estado local de busqueda.
  void _resetFlow() {
    widget.controller.resetFlow();
    final today = DateTime.now();
    setState(() {
      _searched = false;
      _searchNumber.clear();
      _observations.clear();
      _attentionDate = today;
      _attentionDateText.text = _displayDate(today);
    });
  }

  List<EffectiveOption> _operational(String fieldType) =>
      _vaccine?.operationalOptions
          .where((option) => option.fieldType == fieldType)
          .toList() ??
      const [];

  /// Tipo de identificacion con etiqueta "CODIGO - Nombre" (ej.
  /// "CC - Cedula de Ciudadania"), desde el catalogo `document_type`.
  List<DropdownMenuItem<String>> _documentTypeItems() {
    final options = widget.controller.referenceOptions('document_type');
    final list = options.isEmpty ? documentTypeFallback : options;
    return [
      for (final option in list)
        DropdownMenuItem(
          value: option.code,
          child: Text('${option.code} - ${option.label}'),
        ),
    ];
  }

  /// Superficie base de la pantalla: borde tenue y radio consistente.
  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        if (controller.error != null) {
          return _ErrorView(
            message: controller.error!,
            onRetry: () {
              controller.clearError();
              if (controller.patient != null &&
                  !controller.effectiveCatalogLoaded) {
                controller.loadEffectiveCatalog();
              }
            },
          );
        }
        if (controller.isLoading &&
            controller.patient == null &&
            controller.attention == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.patient == null) {
          return _buildSearch(controller);
        }
        return _buildAttention(controller);
      },
    );
  }

  Widget _buildSearch(AttentionController controller) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const _StepHint(
        'Paso 1 de 2 · Verifica al paciente antes de aplicar la vacuna.',
      ),
      const SizedBox(height: 16),
      Text('Buscar paciente', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text(
        'Ingresa el documento. Si no existe, registralo para continuar.',
        style: TextStyle(color: AppColors.slate, height: 1.4),
      ),
      const SizedBox(height: 16),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _searchDocType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de documento'),
              items: _documentTypeItems(),
              onChanged: (value) =>
                  setState(() => _searchDocType = value ?? 'CC'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchNumber,
              keyboardType: documentKeyboardType(_searchDocType),
              inputFormatters: documentInputFormatters(_searchDocType),
              decoration: const InputDecoration(labelText: 'Documento'),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: controller.isLoading ? null : _search,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text('Buscar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.isLoading ? null : _createPatient,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: const Text('Registrar nuevo paciente'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      if (controller.searchResults.isEmpty)
        if (_searched)
          const EmptyState(
            icon: Icons.person_search_outlined,
            title: 'Sin coincidencias',
            message:
                'No se encontro un paciente con ese documento. '
                'Puedes registrarlo como nuevo.',
          )
        else
          const SizedBox.shrink()
      else ...[
        Text(
          'COINCIDENCIAS',
          style: AppTextStyles.overline.copyWith(color: AppColors.slate),
        ),
        const SizedBox(height: 8),
        for (final patient in controller.searchResults)
          _PatientTile(patient: patient, onTap: () => _selectPatient(patient)),
      ],
    ],
  );

  Widget _buildAttention(AttentionController controller) {
    final vaccine = _vaccine;
    final attentionStarted = controller.attention != null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _StepHint(
          'Paso 2 de 2 · Aplica el biologico y cierra el registro.',
        ),
        const SizedBox(height: 12),
        _PatientCard(patient: controller.patient!),
        const SizedBox(height: 12),
        _card(
          child: attentionStarted
              ? _observationsReadOnly(controller)
              : TextField(
                  controller: _observations,
                  maxLines: 3,
                  inputFormatters: maxLengthFormatters(
                    FieldLimits.attentionObservations,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Observaciones de la atencion (opcional)',
                  ),
                ),
        ),
        const SizedBox(height: 12),
        _card(
          child: TextField(
            controller: _attentionDateText,
            readOnly: true,
            onTap: _pickAttentionDate,
            decoration: const InputDecoration(
              labelText: 'Fecha de atencion',
              helperText:
                  'Por defecto hoy. Cambiala si la aplicacion fue otro dia.',
              prefixIcon: Icon(Icons.event_available_outlined),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (!controller.effectiveCatalogLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (controller.effectiveVaccines.isEmpty)
          _emptyCatalog()
        else ...[
          const SectionHeading(
            index: '01',
            title: 'Biologico aplicado',
            subtitle: 'Vacuna, dosis y datos del lote',
          ),
          const SizedBox(height: 12),
          _card(
            child: Form(
              key: _doseFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<EffectiveVaccine>(
                    initialValue: vaccine,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Vacuna'),
                    items: [
                      for (final item in controller.effectiveVaccines)
                        DropdownMenuItem(
                          value: item,
                          child: Text('${item.name} (${item.code})'),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? 'Selecciona la vacuna.' : null,
                    onChanged: (value) => setState(() {
                      _vaccine = value;
                      _dose = null;
                      _pneumo = null;
                      _laboratory = null;
                      _syringe = null;
                      _dropper = null;
                      _observation = null;
                    }),
                  ),
                  if (vaccine != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<EffectiveOption>(
                      initialValue: _dose,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Dosis'),
                      items: [
                        for (final dose in vaccine.doses)
                          DropdownMenuItem(
                            value: dose,
                            child: Text(dose.displayName),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Selecciona la dosis.' : null,
                      onChanged: (value) => setState(() => _dose = value),
                    ),
                    if (vaccine.hasPneumococcalType) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<EffectiveOption>(
                        initialValue: _pneumo,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de neumococo',
                        ),
                        items: [
                          for (final item in vaccine.pneumococcalTypes)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.displayName),
                            ),
                        ],
                        onChanged: (value) => setState(() => _pneumo = value),
                      ),
                    ],
                    if (vaccine.hasLaboratory)
                      _optionDropdown(
                        'Laboratorio',
                        'laboratory',
                        _laboratory,
                        (value) => setState(() => _laboratory = value),
                      ),
                    if (vaccine.hasSyringe)
                      _optionDropdown(
                        'Jeringa',
                        'syringe',
                        _syringe,
                        (value) => setState(() => _syringe = value),
                      ),
                    if (vaccine.hasDropper)
                      _optionDropdown(
                        'Gotero',
                        'dropper',
                        _dropper,
                        (value) => setState(() => _dropper = value),
                      ),
                    if (vaccine.hasObservation)
                      _optionDropdown(
                        'Observacion',
                        'observation',
                        _observation,
                        (value) => setState(() => _observation = value),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lotNumber,
                      inputFormatters: maxLengthFormatters(
                        FieldLimits.lotNumber,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Lote (opcional)',
                      ),
                    ),
                    if (vaccine.hasSyringeLot) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _syringeLot,
                        inputFormatters: maxLengthFormatters(
                          FieldLimits.lotNumber,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Lote de jeringa',
                        ),
                      ),
                    ],
                    if (vaccine.hasDiluent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _diluent,
                        inputFormatters: maxLengthFormatters(
                          FieldLimits.lotNumber,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Diluyente',
                        ),
                      ),
                    ],
                    if (vaccine.hasVialCount) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _vialCount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad de frascos',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customObservation,
                      inputFormatters: maxLengthFormatters(
                        FieldLimits.historyNotes,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Observacion personalizada (opcional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _submittingDose ? null : _addDose,
                      icon: const Icon(Icons.vaccines_rounded, size: 20),
                      label: const Text('Registrar dosis'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              '02 · DOSIS REGISTRADAS',
              style: AppTextStyles.overline.copyWith(color: AppColors.primary),
            ),
            const Spacer(),
            if (controller.doses.isNotEmpty)
              StatusPill(
                label: '${controller.doses.length} registradas',
                tone: StatusTone.neutral,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (controller.doses.isEmpty)
          const EmptyState(
            icon: Icons.vaccines_outlined,
            title: 'Aun no hay dosis',
            message: 'Registra la primera dosis para verla listada aqui.',
          )
        else
          for (final dose in controller.doses) _doseEntry(dose),
        if (attentionStarted) ...[
          const SizedBox(height: 16),
          _closingSection(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: controller.isLoading ? null : _finish,
            icon: const Icon(Icons.done_all_rounded),
            label: const Text('Completar atencion'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.isLoading ? null : _cancelAttention,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Anular atencion'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: controller.isLoading ? null : _resetFlow,
          child: const Text('Cambiar paciente'),
        ),
      ],
    );
  }

  Widget _closingSection() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(
          index: '03',
          title: 'Cierre del registro',
          subtitle: 'Esquema completo y reporte PAIWEB',
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Esquema completo para la edad'),
          value: _completeScheme,
          onChanged: (value) => setState(() => _completeScheme = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('El registro fue ingresado al aplicativo PAIWEB'),
          value: _paiwebRegistered,
          onChanged: (value) => setState(() => _paiwebRegistered = value),
        ),
        if (!_paiwebRegistered)
          TextField(
            controller: _paiwebReason,
            maxLines: 2,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
            decoration: const InputDecoration(
              labelText: 'Motivo de no ingreso',
              helperText: 'Minimo 5 caracteres.',
            ),
          ),
      ],
    ),
  );

  /// Entrada de la dosis como linea de registro: franja de estado a la
  /// izquierda, biologico y lote en cifras tabulares, sello a la derecha.
  /// El `IntrinsicHeight` acota la altura del `Row` (que si no seria infinita
  /// dentro del `ListView`) para que `stretch` dimensione la franja.
  Widget _doseEntry(AppliedDose dose) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: dose.isCancelled ? AppColors.danger : AppColors.success,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dose.vaccineNameSnapshot,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
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
                      StatusPill(
                        label: dose.isCancelled ? 'Anulada' : 'Aplicada',
                        tone: dose.isCancelled
                            ? StatusTone.cancelled
                            : StatusTone.applied,
                      ),
                      if (!dose.isCancelled)
                        IconButton(
                          tooltip: 'Anular dosis',
                          onPressed: _submittingDose
                              ? null
                              : () => _cancelDose(dose.id),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.hint,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _observationsReadOnly(AttentionController controller) {
    final observations = controller.attention?.observations;
    final hasText = observations != null && observations.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OBSERVACIONES DE LA ATENCION',
          style: AppTextStyles.overline.copyWith(color: AppColors.slate),
        ),
        const SizedBox(height: 5),
        Text(
          hasText ? observations : 'Sin observaciones.',
          style: TextStyle(
            color: hasText ? AppColors.ink : AppColors.hint,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _emptyCatalog() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.warningSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.warning.withValues(alpha: .35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No hay vacunas habilitadas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Tu institucion no tiene vacunas habilitadas en el catalogo. '
                'Configuralas en Inventario para poder registrar dosis.',
                style: TextStyle(
                  color: AppColors.slate,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _optionDropdown(
    String label,
    String fieldType,
    EffectiveOption? value,
    ValueChanged<EffectiveOption?> onChanged,
  ) {
    final options = _operational(fieldType);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<EffectiveOption>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option.displayName)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: IdentityStrip(
                  documentType: patient.documentType,
                  documentNumber: patient.documentNumber,
                  name: patient.fullName,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.primary.withValues(alpha: .22)),
    ),
    child: IdentityStrip(
      documentType: patient.documentType,
      documentNumber: patient.documentNumber,
      name: patient.fullName,
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.warning, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Entendido')),
        ],
      ),
    ),
  );
}

class _StepHint extends StatelessWidget {
  const _StepHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(
          Icons.subdirectory_arrow_right_rounded,
          size: 15,
          color: AppColors.hint,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.slate,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        inputFormatters: [LengthLimitingTextInputFormatter(500)],
        decoration: const InputDecoration(
          labelText: 'Motivo',
          helperText: 'Minimo 5 caracteres.',
        ),
        validator: (value) => (value == null || value.trim().length < 5)
            ? 'Ingresa un motivo (minimo 5 caracteres).'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Anular')),
    ],
  );
}
