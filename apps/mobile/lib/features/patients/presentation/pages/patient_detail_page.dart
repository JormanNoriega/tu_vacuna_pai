import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/utils/field_input.dart';
import '../../../catalogs/domain/entities/geo.dart';
import '../../domain/entities/new_patient.dart';
import '../../domain/entities/patient_profile.dart';
import '../patient_detail_controller.dart';

/// Ficha del paciente: ve el perfil completo y permite editar demografia,
/// contacto/direccion y antecedentes.
class PatientDetailPage extends StatefulWidget {
  const PatientDetailPage({
    required this.controller,
    required this.offline,
    required this.patientId,
    super.key,
  });

  final PatientDetailController controller;
  final OfflineAccess offline;
  final String patientId;

  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  static String _formatIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.patientId).then((_) {
      if (!mounted) return;
      final profile = widget.controller.profile;
      final departmentId = (profile != null && profile.addresses.isNotEmpty)
          ? profile.addresses.first.departmentId
          : null;
      widget.controller.loadDepartments();
      if (departmentId != null) {
        widget.controller.loadMunicipalities(departmentId);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ficha del paciente')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final profile = controller.profile;
          if (controller.isLoading && profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profile == null) {
            return _errorView(
              controller.error ?? 'No se pudo cargar el paciente.',
            );
          }
          return _content(profile);
        },
      ),
    );
  }

  Widget _errorView(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.warning, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => widget.controller.load(widget.patientId),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );

  Widget _content(PatientProfile profile) {
    final patient = profile.patient;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(
              patient.fullName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${patient.documentType} ${patient.documentNumber} · '
              '${patient.sex == 'FEMALE' ? 'Femenino' : 'Masculino'}'
              '${patient.birthDate != null ? ' · ${PatientDetailPage._formatDate(patient.birthDate!)}' : ''}',
            ),
          ),
        ),
        _section(
          'Demografia',
          _demographicsBody(profile),
          onEdit: _editDemographics,
        ),
        _section('Contacto', _contactBody(profile), onEdit: _editContact),
        _section('Direccion', _addressBody(profile), onEdit: _editAddress),
        _section('Acompañante', _guardianBody(profile)),
        _section(
          'Antecedentes',
          _historiesBody(profile),
          onEdit: _editHistories,
        ),
      ],
    );
  }

  Widget _section(String title, Widget body, {VoidCallback? onEdit}) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          body,
        ],
      ),
    ),
  );

  Widget _demographicsBody(PatientProfile profile) {
    final demographics = profile.demographics;
    if (demographics == null) {
      return const Text('Sin datos.', style: TextStyle(color: AppColors.slate));
    }
    return _rows([
      ('Genero', _genderLabel(demographics.gender)),
      ('Etnia', demographics.ethnicity),
      ('Escolaridad', demographics.educationLevel),
    ]);
  }

  Widget _contactBody(PatientProfile profile) {
    if (profile.contacts.isEmpty) {
      return const Text('Sin datos.', style: TextStyle(color: AppColors.slate));
    }
    return _rows([
      for (final contact in profile.contacts)
        (_contactLabel(contact.type), contact.value),
    ]);
  }

  Widget _addressBody(PatientProfile profile) {
    if (profile.addresses.isEmpty) {
      return const Text('Sin datos.', style: TextStyle(color: AppColors.slate));
    }
    final address = profile.addresses.first;
    return _rows([
      ('Departamento', _departmentName(address.departmentId)),
      ('Municipio', _municipalityName(address.municipalityId)),
      ('Direccion', address.street),
    ]);
  }

  Widget _guardianBody(PatientProfile profile) {
    if (profile.guardians.isEmpty) {
      return const Text('Sin datos.', style: TextStyle(color: AppColors.slate));
    }
    return _rows([
      for (final guardian in profile.guardians)
        (_relationshipLabel(guardian.relationship), guardian.fullName),
    ]);
  }

  Widget _historiesBody(PatientProfile profile) {
    if (profile.medicalHistories.isEmpty) {
      return const Text('Sin datos.', style: TextStyle(color: AppColors.slate));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final history in profile.medicalHistories)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${history.condition}'
              '${history.diagnosedAt != null ? ' (${PatientDetailPage._formatDate(history.diagnosedAt!)})' : ''}'
              '${history.notes != null && history.notes!.isNotEmpty ? ' · ${history.notes}' : ''}',
            ),
          ),
      ],
    );
  }

  Widget _rows(List<(String, String?)> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  row.$1,
                  style: const TextStyle(color: AppColors.slate),
                ),
              ),
              Expanded(
                child: Text(
                  (row.$2 == null || row.$2!.isEmpty) ? '—' : row.$2!,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  // ---------- edicion ----------

  Future<void> _editDemographics() async {
    final current = widget.controller.profile?.demographics;
    final result = await showDialog<_DemographicsResult>(
      context: context,
      builder: (_) => _DemographicsDialog(
        gender: current?.gender,
        ethnicity: current?.ethnicity,
        educationLevel: current?.educationLevel,
      ),
    );
    if (result == null || !mounted) return;
    final ok = await widget.controller.saveDemographics(
      offline: widget.offline,
      gender: result.gender,
      ethnicity: result.ethnicity,
      educationLevel: result.educationLevel,
    );
    if (mounted) _notify(ok, 'Demografia actualizada.');
  }

  Future<void> _editContact() async {
    final profile = widget.controller.profile!;
    final phone = _firstContact(profile, 'PHONE');
    final email = _firstContact(profile, 'EMAIL');
    final result = await showDialog<_ContactResult>(
      context: context,
      builder: (_) => _ContactDialog(phone: phone, email: email),
    );
    if (result == null || !mounted) return;
    final contacts = <NewPatientContact>[
      if (result.phone != null && result.phone!.isNotEmpty)
        NewPatientContact(type: 'PHONE', value: result.phone!, primary: true),
      if (result.email != null && result.email!.isNotEmpty)
        NewPatientContact(type: 'EMAIL', value: result.email!),
    ];
    final ok = await widget.controller.saveContact(
      offline: widget.offline,
      contacts: contacts,
      addresses: _currentAddresses(profile),
    );
    if (mounted) _notify(ok, 'Contacto actualizado.');
  }

  Future<void> _editAddress() async {
    final profile = widget.controller.profile!;
    final current = profile.addresses.isEmpty ? null : profile.addresses.first;
    await widget.controller.loadDepartments();
    if (!mounted) return;
    final result = await showDialog<_AddressResult>(
      context: context,
      builder: (_) => _AddressDialog(
        controller: widget.controller,
        departmentId: current?.departmentId,
        municipalityId: current?.municipalityId,
        street: current?.street,
      ),
    );
    if (result == null || !mounted) return;
    final ok = await widget.controller.saveContact(
      offline: widget.offline,
      contacts: _currentContacts(profile),
      addresses: [
        NewPatientAddress(
          street: result.street,
          departmentId: result.departmentId,
          municipalityId: result.municipalityId,
        ),
      ],
    );
    if (mounted) _notify(ok, 'Direccion actualizada.');
  }

  Future<void> _editHistories() async {
    final profile = widget.controller.profile!;
    final result = await showDialog<List<NewPatientMedicalHistory>>(
      context: context,
      builder: (_) => _HistoriesDialog(histories: profile.medicalHistories),
    );
    if (result == null || !mounted) return;
    final ok = await widget.controller.saveMedicalHistories(
      offline: widget.offline,
      histories: result,
    );
    if (mounted) _notify(ok, 'Antecedentes actualizados.');
  }

  void _notify(bool ok, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? message : 'No se pudo guardar el cambio.')),
    );
  }

  List<NewPatientContact> _currentContacts(PatientProfile profile) => [
    for (final contact in profile.contacts)
      NewPatientContact(
        type: contact.type,
        value: contact.value,
        primary: contact.primary,
      ),
  ];

  List<NewPatientAddress> _currentAddresses(PatientProfile profile) => [
    for (final address in profile.addresses)
      NewPatientAddress(
        street: address.street,
        departmentId: address.departmentId,
        municipalityId: address.municipalityId,
        primary: address.primary,
      ),
  ];

  String? _firstContact(PatientProfile profile, String type) {
    for (final contact in profile.contacts) {
      if (contact.type == type) return contact.value;
    }
    return null;
  }

  String? _departmentName(String? id) {
    if (id == null) return null;
    for (final department in widget.controller.departments) {
      if (department.id == id) return department.name;
    }
    return null;
  }

  String? _municipalityName(String? id) {
    if (id == null) return null;
    for (final municipality in widget.controller.municipalities) {
      if (municipality.id == id) return municipality.name;
    }
    return null;
  }

  static String? _genderLabel(String? gender) => switch (gender) {
    'MALE' => 'Masculino',
    'FEMALE' => 'Femenino',
    'OTHER' => 'Otro',
    _ => gender,
  };

  static String _contactLabel(String type) => switch (type) {
    'PHONE' => 'Telefono',
    'EMAIL' => 'Correo',
    _ => 'Otro',
  };

  static String _relationshipLabel(String relationship) =>
      switch (relationship) {
        'MOTHER' => 'Madre',
        'FATHER' => 'Padre',
        'CAREGIVER' => 'Cuidador',
        'OTHER' => 'Otro',
        _ => relationship,
      };
}

// ---------- dialogs ----------

class _DemographicsResult {
  const _DemographicsResult(this.gender, this.ethnicity, this.educationLevel);
  final String? gender;
  final String? ethnicity;
  final String? educationLevel;
}

class _DemographicsDialog extends StatefulWidget {
  const _DemographicsDialog({this.gender, this.ethnicity, this.educationLevel});

  final String? gender;
  final String? ethnicity;
  final String? educationLevel;

  @override
  State<_DemographicsDialog> createState() => _DemographicsDialogState();
}

class _DemographicsDialogState extends State<_DemographicsDialog> {
  late String? _gender = widget.gender;
  late final TextEditingController _ethnicity = TextEditingController(
    text: widget.ethnicity,
  );
  late final TextEditingController _education = TextEditingController(
    text: widget.educationLevel,
  );

  @override
  void dispose() {
    _ethnicity.dispose();
    _education.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Demografia'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _gender,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Genero'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Sin dato')),
            DropdownMenuItem(value: 'MALE', child: Text('Masculino')),
            DropdownMenuItem(value: 'FEMALE', child: Text('Femenino')),
            DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
          ],
          onChanged: (value) => setState(() => _gender = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ethnicity,
          inputFormatters: maxLengthFormatters(FieldLimits.ethnicity),
          decoration: const InputDecoration(labelText: 'Etnia'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _education,
          inputFormatters: maxLengthFormatters(FieldLimits.educationLevel),
          decoration: const InputDecoration(labelText: 'Escolaridad'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _DemographicsResult(
            _gender,
            _ethnicity.text.trim().isEmpty ? null : _ethnicity.text.trim(),
            _education.text.trim().isEmpty ? null : _education.text.trim(),
          ),
        ),
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _ContactResult {
  const _ContactResult(this.phone, this.email);
  final String? phone;
  final String? email;
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.phone, this.email});

  final String? phone;
  final String? email;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final TextEditingController _phone = TextEditingController(
    text: widget.phone,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.email,
  );

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Contacto'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: phoneFormatters(),
          decoration: const InputDecoration(labelText: 'Telefono'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          inputFormatters: maxLengthFormatters(FieldLimits.email),
          decoration: const InputDecoration(labelText: 'Correo'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _ContactResult(
            _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            _email.text.trim().isEmpty ? null : _email.text.trim(),
          ),
        ),
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _AddressResult {
  const _AddressResult(this.departmentId, this.municipalityId, this.street);
  final String? departmentId;
  final String? municipalityId;
  final String? street;
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({
    required this.controller,
    this.departmentId,
    this.municipalityId,
    this.street,
  });

  final PatientDetailController controller;
  final String? departmentId;
  final String? municipalityId;
  final String? street;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late String? _departmentId = widget.departmentId;
  late String? _municipalityId = widget.municipalityId;
  late final TextEditingController _street = TextEditingController(
    text: widget.street,
  );

  @override
  void dispose() {
    _street.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Direccion'),
    content: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _departmentId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Departamento'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin dato')),
              for (final GeoDepartment department
                  in widget.controller.departments)
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
              if (value != null) widget.controller.loadMunicipalities(value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _municipalityId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Municipio'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin dato')),
              for (final GeoMunicipality municipality
                  in widget.controller.municipalities)
                DropdownMenuItem(
                  value: municipality.id,
                  child: Text(municipality.name),
                ),
            ],
            onChanged: (value) => setState(() => _municipalityId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _street,
            inputFormatters: maxLengthFormatters(FieldLimits.street),
            decoration: const InputDecoration(labelText: 'Direccion'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _AddressResult(
            _departmentId,
            _municipalityId,
            _street.text.trim().isEmpty ? null : _street.text.trim(),
          ),
        ),
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _HistoriesDialog extends StatefulWidget {
  const _HistoriesDialog({required this.histories});

  final List<PatientMedicalHistory> histories;

  @override
  State<_HistoriesDialog> createState() => _HistoriesDialogState();
}

class _HistoriesDialogState extends State<_HistoriesDialog> {
  late final List<_HistoryEdit> _edits = [
    for (final history in widget.histories)
      _HistoryEdit(
        condition: history.condition,
        diagnosedAt: history.diagnosedAt,
        notes: history.notes,
      ),
  ];

  @override
  void dispose() {
    for (final edit in _edits) {
      edit.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Antecedentes'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _edits.length; i++) ...[
              TextField(
                controller: _edits[i].condition,
                inputFormatters: maxLengthFormatters(
                  FieldLimits.historyCondition,
                ),
                decoration: const InputDecoration(labelText: 'Antecedente'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _edits[i].dateText,
                      readOnly: true,
                      onTap: () => _pickDate(i),
                      decoration: const InputDecoration(labelText: 'Fecha'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar',
                    onPressed: () =>
                        setState(() => _edits.removeAt(i).dispose()),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _edits[i].notes,
                inputFormatters: maxLengthFormatters(FieldLimits.historyNotes),
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
              const Divider(height: 24),
            ],
            OutlinedButton.icon(
              onPressed: () => setState(() => _edits.add(_HistoryEdit())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar antecedente'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, [
          for (final edit in _edits)
            if (edit.condition.text.trim().isNotEmpty)
              NewPatientMedicalHistory(
                condition: edit.condition.text.trim(),
                diagnosedAt: edit.diagnosedAt == null
                    ? null
                    : PatientDetailPage._formatIso(edit.diagnosedAt!),
                notes: edit.notes.text.trim().isEmpty
                    ? null
                    : edit.notes.text.trim(),
              ),
        ]),
        child: const Text('Guardar'),
      ),
    ],
  );

  Future<void> _pickDate(int index) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _edits[index].diagnosedAt ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _edits[index].diagnosedAt = picked;
      _edits[index].dateText.text = PatientDetailPage._formatDate(picked);
    });
  }
}

class _HistoryEdit {
  _HistoryEdit({String? condition, this.diagnosedAt, String? notes})
    : condition = TextEditingController(text: condition),
      notes = TextEditingController(text: notes),
      dateText = TextEditingController(
        text: diagnosedAt == null
            ? ''
            : PatientDetailPage._formatDate(diagnosedAt),
      );

  final TextEditingController condition;
  final TextEditingController notes;
  final TextEditingController dateText;
  DateTime? diagnosedAt;

  void dispose() {
    condition.dispose();
    notes.dispose();
    dateText.dispose();
  }
}
