import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/utils/document_input.dart';
import '../../../../core/utils/field_input.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../catalogs/domain/entities/effective_catalog.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../patients/presentation/pages/patient_wizard_page.dart';
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
  static const _documentTypes = ['CC', 'TI', 'CE', 'PASAPORTE'];

  final _searchNumber = TextEditingController();
  final _lotNumber = TextEditingController();
  final _observations = TextEditingController();
  final _applicationDateText = TextEditingController();
  String _searchDocType = 'CC';
  bool _searched = false;

  EffectiveVaccine? _vaccine;
  EffectiveOption? _dose;
  EffectiveOption? _pneumo;
  EffectiveOption? _laboratory;
  EffectiveOption? _syringe;
  EffectiveOption? _dropper;
  EffectiveOption? _observation;
  DateTime? _applicationDate;
  bool _submittingDose = false;
  final _doseFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _searchNumber.dispose();
    _lotNumber.dispose();
    _observations.dispose();
    _applicationDateText.dispose();
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

  Future<void> _pickApplicationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _applicationDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Fecha de aplicacion',
    );
    if (picked == null) return;
    setState(() {
      _applicationDate = picked;
      _applicationDateText.text = _displayDate(picked);
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
    if (created != true || !mounted) return;
    await widget.controller.loadEffectiveCatalog();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Paciente registrado.')));
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
    setState(() => _submittingDose = true);
    final ok = await widget.controller.addDose(
      offline: widget.offline,
      vaccineId: vaccine.vaccineId,
      doseOptionId: dose.id,
      observations: _observations.text.trim(),
      pneumococcalTypeOptionId: _pneumo?.id,
      lotNumber: _lotNumber.text.trim(),
      applicationDate: _applicationDate == null
          ? null
          : '${_isoDate(_applicationDate!)}T12:00:00Z',
      selectedLaboratoryId: _laboratory?.id,
      selectedSyringeId: _syringe?.id,
      selectedDropperId: _dropper?.id,
      selectedObservationId: _observation?.id,
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
        _applicationDate = null;
        _applicationDateText.clear();
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
    setState(() {
      _searched = false;
      _searchNumber.clear();
      _observations.clear();
    });
  }

  List<EffectiveOption> _operational(String fieldType) =>
      _vaccine?.operationalOptions
          .where((option) => option.fieldType == fieldType)
          .toList() ??
      const [];

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
      const _StepHint('Paso 1 de 2: busca o registra al paciente.'),
      const SizedBox(height: 12),
      Text('Buscar paciente', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text(
        'Busca por documento para iniciar la atencion. Si no existe, '
        'registralo.',
        style: TextStyle(color: AppColors.slate, height: 1.4),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<String>(
              initialValue: _searchDocType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final type in _documentTypes)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) =>
                  setState(() => _searchDocType = value ?? 'CC'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchNumber,
              keyboardType: documentKeyboardType(_searchDocType),
              inputFormatters: documentInputFormatters(_searchDocType),
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
        label: const Text('Buscar'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: controller.isLoading ? null : _createPatient,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Registrar nuevo paciente'),
      ),
      const SizedBox(height: 24),
      if (controller.searchResults.isEmpty)
        if (_searched)
          const Text(
            'Sin resultados.',
            style: TextStyle(color: AppColors.slate),
          )
        else
          const SizedBox.shrink()
      else
        for (final patient in controller.searchResults)
          _PatientTile(patient: patient, onTap: () => _selectPatient(patient)),
    ],
  );

  Widget _buildAttention(AttentionController controller) {
    final vaccine = _vaccine;
    final attentionStarted = controller.attention != null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _StepHint(
          'Paso 2 de 2: registra la vacuna y las dosis, y completa la atencion.',
        ),
        const SizedBox(height: 12),
        _PatientCard(patient: controller.patient!),
        const SizedBox(height: 12),
        if (attentionStarted)
          _observationsReadOnly(controller)
        else
          TextField(
            controller: _observations,
            maxLines: 3,
            inputFormatters: maxLengthFormatters(
              FieldLimits.attentionObservations,
            ),
            decoration: const InputDecoration(
              labelText: 'Observaciones de la atencion (opcional)',
            ),
          ),
        const SizedBox(height: 16),
        if (!controller.effectiveCatalogLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (controller.effectiveVaccines.isEmpty)
          _emptyCatalog()
        else ...[
          Text(
            'Registrar dosis',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Form(
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
                    inputFormatters: maxLengthFormatters(FieldLimits.lotNumber),
                    decoration: const InputDecoration(
                      labelText: 'Lote (opcional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _applicationDateText,
                    readOnly: true,
                    onTap: _pickApplicationDate,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de aplicacion (opcional)',
                      hintText: 'Hoy',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _submittingDose ? null : _addDose,
                    icon: const Icon(Icons.vaccines_rounded),
                    label: const Text('Registrar dosis'),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Dosis registradas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (controller.doses.isEmpty)
          const Text(
            'Aun no hay dosis registradas.',
            style: TextStyle(color: AppColors.slate),
          )
        else
          for (final dose in controller.doses)
            ListTile(
              dense: true,
              leading: Icon(
                dose.isCancelled
                    ? Icons.cancel_outlined
                    : Icons.check_circle_outline,
                color: dose.isCancelled ? AppColors.warning : AppColors.success,
                size: 20,
              ),
              title: Text(dose.vaccineNameSnapshot),
              subtitle: Text(
                '${dose.doseLabelSnapshot}'
                '${dose.lotNumber != null ? ' · Lote ${dose.lotNumber}' : ''}'
                '${dose.isCancelled ? ' · ANULADA' : ''}',
              ),
              trailing: dose.isCancelled
                  ? null
                  : TextButton(
                      onPressed: _submittingDose
                          ? null
                          : () => _cancelDose(dose.id),
                      child: const Text('Anular'),
                    ),
            ),
        if (attentionStarted) ...[
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

  Widget _observationsReadOnly(AttentionController controller) {
    final observations = controller.attention?.observations;
    return Text(
      (observations == null || observations.isEmpty)
          ? 'Sin observaciones.'
          : 'Observaciones: $observations',
      style: const TextStyle(color: AppColors.slate),
    );
  }

  Widget _emptyCatalog() => Card(
    color: AppColors.warning.withValues(alpha: .1),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
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
                  style: TextStyle(color: AppColors.slate, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      leading: const Icon(Icons.person_outline_rounded),
      title: Text(patient.fullName),
      subtitle: Text('${patient.documentType} ${patient.documentNumber}'),
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(
        patient.fullName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${patient.documentType} ${patient.documentNumber}'),
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
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
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
