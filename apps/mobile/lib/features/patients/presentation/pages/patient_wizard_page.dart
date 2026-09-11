import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/utils/document_input.dart';
import '../../../../core/utils/field_input.dart';
import '../../../attentions/presentation/attention_controller.dart';
import '../../../catalogs/domain/entities/geo.dart';
import '../../domain/entities/new_patient.dart';

/// Asistente de registro de paciente en 6 pasos. Guarda todo en un solo
/// `POST /patients` al final; los pasos 2-6 son opcionales.
class PatientWizardPage extends StatefulWidget {
  const PatientWizardPage({
    required this.controller,
    required this.offline,
    super.key,
  });

  final AttentionController controller;
  final OfflineAccess offline;

  @override
  State<PatientWizardPage> createState() => _PatientWizardPageState();
}

class _PatientWizardPageState extends State<PatientWizardPage> {
  static const _steps = [
    'Identidad',
    'Demografia',
    'Contacto',
    'Acompañante',
    'Direccion',
    'Antecedentes',
  ];

  static const _stepHints = [
    'Datos obligatorios: tipo y numero de documento, nombres, apellidos, '
        'fecha de nacimiento y sexo.',
    'Datos demograficos opcionales (genero, etnia, escolaridad).'
        'Puedes dejarlos en blanco.',
    'Telefono y correo de contacto (opcionales) para ubicar al paciente.',
    'Persona responsable del paciente (madre, padre, cuidador) y su contacto. '
        'Opcional.',
    'Departamento y municipio de residencia (pais: Colombia). Opcional.',
    'Antecedentes medicos relevantes del paciente. Opcional; puedes agregar '
        'varios.',
  ];

  final _identityFormKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _documentNumber = TextEditingController();
  final _birthDate = TextEditingController();

  final _ethnicity = TextEditingController();
  final _educationLevel = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  final _guardianName = TextEditingController();
  final _guardianDocument = TextEditingController();
  final _guardianPhone = TextEditingController();

  final _street = TextEditingController();

  final List<_HistoryDraft> _histories = [];

  String _documentType = 'CC';
  String _sex = 'MALE';
  String? _gender;
  String _guardianRelationship = 'CAREGIVER';
  String _guardianDocumentType = 'CC';
  DateTime? _birth;
  String? _departmentId;
  String? _municipalityId;

  int _step = 0;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _documentNumber.dispose();
    _birthDate.dispose();
    _ethnicity.dispose();
    _educationLevel.dispose();
    _phone.dispose();
    _email.dispose();
    _guardianName.dispose();
    _guardianDocument.dispose();
    _guardianPhone.dispose();
    _street.dispose();
    for (final history in _histories) {
      history.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked == null) return;
    setState(() {
      _birth = picked;
      _birthDate.text = _format(picked);
    });
  }

  static String _format(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _next() async {
    if (_step == 0 && !(_identityFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      if (_step == 4) {
        widget.controller.loadDepartments();
      }
      return;
    }
    await _save();
  }

  void _previous() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  Future<void> _handleBack() async {
    if (_saving) return;
    if (!_hasUnsavedData()) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text(
          'Ya ingresaste datos. Si sales ahora se perderan. '
          '¿Deseas descartar los cambios?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  bool _hasUnsavedData() {
    if (_step > 0 || _birth != null || _gender != null) return true;
    if (_departmentId != null || _municipalityId != null) return true;
    for (final controller in [
      _firstName,
      _lastName,
      _documentNumber,
      _ethnicity,
      _educationLevel,
      _phone,
      _email,
      _guardianName,
      _guardianDocument,
      _guardianPhone,
      _street,
    ]) {
      if (controller.text.trim().isNotEmpty) return true;
    }
    for (final history in _histories) {
      if (history.condition.text.trim().isNotEmpty ||
          history.notes.text.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> _save() async {
    if (_birth == null) {
      setState(() => _step = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de nacimiento.')),
      );
      return;
    }
    setState(() => _saving = true);

    final contacts = <NewPatientContact>[
      if (_phone.text.trim().isNotEmpty)
        NewPatientContact(
          type: 'PHONE',
          value: _phone.text.trim(),
          primary: true,
        ),
      if (_email.text.trim().isNotEmpty)
        NewPatientContact(type: 'EMAIL', value: _email.text.trim()),
    ];

    final guardians = <NewPatientGuardian>[
      if (_guardianName.text.trim().isNotEmpty)
        NewPatientGuardian(
          relationship: _guardianRelationship,
          fullName: _guardianName.text.trim(),
          documentType: _guardianDocument.text.trim().isEmpty
              ? null
              : _guardianDocumentType,
          documentNumber: _guardianDocument.text.trim().isEmpty
              ? null
              : _guardianDocument.text.trim(),
          phone: _guardianPhone.text.trim().isEmpty
              ? null
              : _guardianPhone.text.trim(),
        ),
    ];

    final address = NewPatientAddress(
      street: _street.text.trim().isEmpty ? null : _street.text.trim(),
      departmentId: _departmentId,
      municipalityId: _municipalityId,
    );

    final demographics =
        (_gender == null &&
            _ethnicity.text.trim().isEmpty &&
            _educationLevel.text.trim().isEmpty)
        ? null
        : NewPatientDemographic(
            gender: _gender,
            ethnicity: _ethnicity.text.trim().isEmpty
                ? null
                : _ethnicity.text.trim(),
            educationLevel: _educationLevel.text.trim().isEmpty
                ? null
                : _educationLevel.text.trim(),
          );

    final histories = <NewPatientMedicalHistory>[
      for (final history in _histories)
        if (history.condition.text.trim().isNotEmpty)
          NewPatientMedicalHistory(
            condition: history.condition.text.trim(),
            diagnosedAt: history.diagnosedAt == null
                ? null
                : _format(history.diagnosedAt!),
            notes: history.notes.text.trim().isEmpty
                ? null
                : history.notes.text.trim(),
          ),
    ];

    final input = NewPatientInput(
      documentType: _documentType,
      documentNumber: _documentNumber.text.trim(),
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      birthDate: _format(_birth!),
      sex: _sex,
      demographics: demographics,
      contacts: contacts,
      addresses: [address],
      guardians: guardians,
      medicalHistories: histories,
    );

    final created = await widget.controller.registerPatient(
      offline: widget.offline,
      input: input,
    );
    if (!mounted) return;
    if (created != null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Nuevo paciente')),
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: AnimatedBuilder(
                        animation: widget.controller,
                        builder: (context, _) => _stepContent(),
                      ),
                    ),
                  ),
                ),
              ),
              _navBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    width: double.infinity,
    color: AppColors.surface,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paso ${_step + 1} de ${_steps.length}',
          style: const TextStyle(color: AppColors.slate, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(_steps[_step], style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: (_step + 1) / _steps.length),
        const SizedBox(height: 12),
        _StepHint(_stepHints[_step]),
      ],
    ),
  );

  Widget _stepContent() => switch (_step) {
    0 => _identityStep(),
    1 => _demographicsStep(),
    2 => _contactStep(),
    3 => _guardianStep(),
    4 => _addressStep(),
    _ => _historyStep(),
  };

  Widget _identityStep() => Form(
    key: _identityFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _documentType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final type in const ['CC', 'TI', 'CE', 'PASAPORTE'])
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) =>
                    setState(() => _documentType = value ?? 'CC'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _documentNumber,
                keyboardType: documentKeyboardType(_documentType),
                inputFormatters: documentInputFormatters(_documentType),
                decoration: InputDecoration(
                  labelText: 'Numero de documento',
                  helperText: (_documentType == 'CC' || _documentType == 'TI')
                      ? 'Solo numeros, maximo 10.'
                      : 'Letras y numeros, maximo 10.',
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Ingresa el documento.';
                  final min = _documentType == 'CC' ? 6 : 4;
                  if (v.length < min) {
                    return 'Ingresa al menos $min caracteres.';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _firstName,
          textCapitalization: TextCapitalization.words,
          inputFormatters: maxLengthFormatters(FieldLimits.name),
          decoration: const InputDecoration(
            labelText: 'Nombres',
            helperText: 'Como aparece en el documento.',
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Ingresa los nombres.'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _lastName,
          textCapitalization: TextCapitalization.words,
          inputFormatters: maxLengthFormatters(FieldLimits.name),
          decoration: const InputDecoration(
            labelText: 'Apellidos',
            helperText: 'Como aparece en el documento.',
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Ingresa los apellidos.'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _birthDate,
          readOnly: true,
          onTap: _pickBirthDate,
          decoration: const InputDecoration(
            labelText: 'Fecha de nacimiento',
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _sex,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sexo'),
          items: const [
            DropdownMenuItem(value: 'MALE', child: Text('Masculino')),
            DropdownMenuItem(value: 'FEMALE', child: Text('Femenino')),
          ],
          onChanged: (value) => setState(() => _sex = value ?? 'MALE'),
        ),
      ],
    ),
  );

  Widget _demographicsStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String?>(
        initialValue: _gender,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Genero (dato demografico)',
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('Sin dato')),
          DropdownMenuItem(value: 'MALE', child: Text('Masculino')),
          DropdownMenuItem(value: 'FEMALE', child: Text('Femenino')),
          DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
        ],
        onChanged: (value) => setState(() => _gender = value),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _ethnicity,
        inputFormatters: maxLengthFormatters(FieldLimits.ethnicity),
        decoration: const InputDecoration(labelText: 'Etnia (opcional)'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _educationLevel,
        inputFormatters: maxLengthFormatters(FieldLimits.educationLevel),
        decoration: const InputDecoration(labelText: 'Escolaridad (opcional)'),
      ),
    ],
  );

  Widget _contactStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        inputFormatters: phoneFormatters(),
        decoration: const InputDecoration(
          labelText: 'Telefono (opcional)',
          helperText: 'Solo numeros y simbolos de marcado.',
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        inputFormatters: maxLengthFormatters(FieldLimits.email),
        decoration: const InputDecoration(
          labelText: 'Correo (opcional)',
          helperText: 'Correo de contacto del paciente o acompañante.',
        ),
      ),
    ],
  );

  Widget _guardianStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: _guardianRelationship,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Parentesco'),
        items: const [
          DropdownMenuItem(value: 'MOTHER', child: Text('Madre')),
          DropdownMenuItem(value: 'FATHER', child: Text('Padre')),
          DropdownMenuItem(value: 'CAREGIVER', child: Text('Cuidador')),
          DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
        ],
        onChanged: (value) =>
            setState(() => _guardianRelationship = value ?? 'CAREGIVER'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _guardianName,
        textCapitalization: TextCapitalization.words,
        inputFormatters: maxLengthFormatters(FieldLimits.name),
        decoration: const InputDecoration(labelText: 'Nombre del acompañante'),
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _guardianDocumentType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final type in const ['CC', 'TI', 'CE', 'PASAPORTE'])
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) =>
                  setState(() => _guardianDocumentType = value ?? 'CC'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _guardianDocument,
              keyboardType: documentKeyboardType(_guardianDocumentType),
              inputFormatters: documentInputFormatters(_guardianDocumentType),
              decoration: const InputDecoration(
                labelText: 'Documento',
                helperText: 'Documento del acompañante (opcional).',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _guardianPhone,
        keyboardType: TextInputType.phone,
        inputFormatters: phoneFormatters(),
        decoration: const InputDecoration(
          labelText: 'Telefono del acompañante',
        ),
      ),
    ],
  );

  Widget _addressStep() {
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _departmentId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Departamento'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin dato')),
            for (final GeoDepartment department in controller.departments)
              DropdownMenuItem(
                value: department.id,
                child: Text(department.name),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _departmentId = value;
              _municipalityId = null;
            });
            if (value != null) controller.loadMunicipalities(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: _municipalityId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Municipio'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin dato')),
            for (final GeoMunicipality municipality
                in controller.municipalities)
              DropdownMenuItem(
                value: municipality.id,
                child: Text(municipality.name),
              ),
          ],
          onChanged: (value) => setState(() => _municipalityId = value),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _street,
          inputFormatters: maxLengthFormatters(FieldLimits.street),
          decoration: const InputDecoration(
            labelText: 'Direccion (opcional)',
            helperText: 'Direccion de residencia.',
          ),
        ),
      ],
    );
  }

  Widget _historyStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < _histories.length; i++) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _histories[i].condition,
                  inputFormatters: maxLengthFormatters(
                    FieldLimits.historyCondition,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Antecedente',
                    helperText: 'Ej: asma, alergias, cardiopatia.',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _histories[i].dateText,
                        readOnly: true,
                        onTap: () => _pickHistoryDate(i),
                        decoration: const InputDecoration(labelText: 'Fecha'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar',
                      onPressed: () => setState(() {
                        _histories.removeAt(i).dispose();
                      }),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _histories[i].notes,
                  inputFormatters: maxLengthFormatters(
                    FieldLimits.historyNotes,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      OutlinedButton.icon(
        onPressed: () => setState(() => _histories.add(_HistoryDraft())),
        icon: const Icon(Icons.add),
        label: const Text('Agregar antecedente'),
      ),
    ],
  );

  Future<void> _pickHistoryDate(int index) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _histories[index].diagnosedAt ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _histories[index].diagnosedAt = picked;
      _histories[index].dateText.text = _format(picked);
    });
  }

  Widget _navBar() {
    final isLast = _step == _steps.length - 1;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _previous,
                  child: const Text('Anterior'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving ? null : _next,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLast ? 'Guardar paciente' : 'Siguiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDraft {
  final TextEditingController condition = TextEditingController();
  final TextEditingController dateText = TextEditingController();
  final TextEditingController notes = TextEditingController();
  DateTime? diagnosedAt;

  void dispose() {
    condition.dispose();
    dateText.dispose();
    notes.dispose();
  }
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
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
