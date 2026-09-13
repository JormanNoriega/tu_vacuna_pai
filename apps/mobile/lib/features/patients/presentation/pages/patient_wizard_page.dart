import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/clinical_components.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/utils/document_input.dart';
import '../../../../core/utils/field_input.dart';
import '../../../attentions/presentation/attention_controller.dart';
import '../../../catalogs/domain/entities/catalog_entities.dart';
import '../../../catalogs/domain/entities/geo.dart';
import '../../domain/entities/new_patient.dart';

/// Asistente de registro de paciente por secciones del formato PAI. Guarda
/// todo en un solo `POST /patients` al final; solo el paso 1 es obligatorio.
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
    'Datos basicos',
    'Datos complementarios',
    'Afiliacion',
    'Residencia y contacto',
    'Condiciones especiales',
    'Antecedentes medicos',
    'Condicion de la usuaria',
    'Madre / cuidador',
  ];

  static const _stepHints = [
    'Obligatorios: tipo y numero de documento, nombres, apellidos, fecha de '
        'nacimiento y sexo.',
    'Genero, orientacion sexual, etnia, tipo de carnet, pais de nacimiento y '
        'estatus migratorio.',
    'Regimen de afiliacion y aseguradora/EPS del paciente.',
    'Residencia, direccion y datos de contacto (telefono fijo, celular, '
        'correo y autorizaciones).',
    'Poblaciones especiales: desplazado, discapacitado, fallecido, victima del '
        'conflicto y estudia actualmente.',
    'Contraindicaciones, reacciones previas y antecedentes medicos.',
    'Solo para mujeres desde 9 anos: condicion de la usuaria y datos '
        'obstetricos.',
    'Datos de la madre o del cuidador responsable (para menores de edad).',
  ];

  final _identityFormKey = GlobalKey<FormState>();

  // Identidad
  final _documentNumber = TextEditingController();
  final _firstName = TextEditingController();
  final _secondName = TextEditingController();
  final _lastName = TextEditingController();
  final _secondLastName = TextEditingController();
  final _birthDate = TextEditingController();

  // Complementarios
  final _educationLevel = TextEditingController();
  final _birthPlace = TextEditingController();
  final _gestationalAge = TextEditingController();

  // Residencia y contacto
  final _locality = TextEditingController();
  final _street = TextEditingController();
  final _landline = TextEditingController();
  final _cellphone = TextEditingController();
  final _email = TextEditingController();

  // Antecedentes
  final _contraindicationDetails = TextEditingController();
  final _reactionDetails = TextEditingController();

  // Condicion usuaria
  final _lastMenstrualDate = TextEditingController();
  final _previousPregnancies = TextEditingController();
  final _birthPlaceDelivery = TextEditingController();

  // Madre / cuidador
  final _guardianFirstName = TextEditingController();
  final _guardianSecondName = TextEditingController();
  final _guardianLastName = TextEditingController();
  final _guardianSecondLastName = TextEditingController();
  final _guardianDocument = TextEditingController();
  final _guardianLandline = TextEditingController();
  final _guardianCellphone = TextEditingController();
  final _guardianEmail = TextEditingController();

  final List<_HistoryDraft> _histories = [];

  String _documentType = 'CC';
  String _sex = 'MALE';
  String? _gender;
  String? _sexualOrientation;
  String? _ethnicity;
  String? _carnetType;
  String? _birthCountryId;
  String _migrationStatus = 'REGULAR';

  String? _affiliationRegime;
  final _insurer = TextEditingController();

  String? _departmentId;
  String? _municipalityId;
  String? _area;
  bool _authorizeCalls = false;
  bool _authorizeEmail = false;

  bool? _displaced;
  bool? _disabled;
  bool? _deceased;
  bool? _armedConflictVictim;
  bool? _currentlyStudying;

  bool _hasContraindication = false;
  bool _hasPreviousReaction = false;

  String? _userCondition;
  DateTime? _lastMenstrual;

  String _guardianRelationship = 'CAREGIVER';
  String _guardianDocumentType = 'CC';
  bool? _guardianDisplaced;

  DateTime? _birth;
  int _step = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.controller.loadReferenceCatalogs();
    // Colombia viene preseleccionada como pais de nacimiento (editable). Hoy el
    // catalogo solo tiene Colombia; al sembrar mas paises el campo se amplia.
    widget.controller.loadCountries().then((_) {
      if (!mounted) return;
      if (_birthCountryId == null && widget.controller.countries.isNotEmpty) {
        setState(() => _birthCountryId = widget.controller.countries.first.id);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _documentNumber,
      _firstName,
      _secondName,
      _lastName,
      _secondLastName,
      _birthDate,
      _educationLevel,
      _birthPlace,
      _gestationalAge,
      _locality,
      _street,
      _landline,
      _cellphone,
      _email,
      _contraindicationDetails,
      _reactionDetails,
      _lastMenstrualDate,
      _previousPregnancies,
      _birthPlaceDelivery,
      _guardianFirstName,
      _guardianSecondName,
      _guardianLastName,
      _guardianSecondLastName,
      _guardianDocument,
      _guardianLandline,
      _guardianCellphone,
      _guardianEmail,
      _insurer,
    ]) {
      controller.dispose();
    }
    for (final history in _histories) {
      history.dispose();
    }
    super.dispose();
  }

  // ---------- helpers de catalogo ----------

  List<ReferenceOption> _ref(
    String code, {
    List<ReferenceOption> fallback = const [],
  }) {
    final options = widget.controller.referenceOptions(code);
    return options.isEmpty ? fallback : options;
  }

  List<DropdownMenuItem<String>> _refItems(
    String code, {
    List<ReferenceOption> fallback = const [],
  }) => [
    for (final option in _ref(code, fallback: fallback))
      DropdownMenuItem(value: option.code, child: Text(option.label)),
  ];

  /// Tipo de identificacion con etiqueta "CODIGO - Nombre" (ej. "CC - Cedula
  /// de Ciudadania"), tomado del catalogo `document_type`.
  List<DropdownMenuItem<String>> _documentTypeItems() => [
    for (final option in _ref('document_type', fallback: documentTypeFallback))
      DropdownMenuItem(
        value: option.code,
        child: Text('${option.code} - ${option.label}'),
      ),
  ];

  List<DropdownMenuItem<String?>> _refItemsN(
    String code, {
    List<ReferenceOption> fallback = const [],
  }) => [
    const DropdownMenuItem(value: null, child: Text('Sin dato')),
    for (final option in _ref(code, fallback: fallback))
      DropdownMenuItem(value: option.code, child: Text(option.label)),
  ];

  static const _sexFallback = [
    ReferenceOption(code: 'MALE', label: 'Masculino', sortOrder: 1),
    ReferenceOption(code: 'FEMALE', label: 'Femenino', sortOrder: 2),
    ReferenceOption(
      code: 'INDETERMINATE',
      label: 'Indeterminado',
      sortOrder: 3,
    ),
  ];

  bool get _showUserCondition {
    final age = _ageYears;
    return _sex == 'FEMALE' && age != null && age >= 9;
  }

  int? get _ageYears {
    final birth = _birth;
    if (birth == null) return null;
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  /// Pais por defecto (Colombia) tomado del catalogo. Se usa para el pais de
  /// residencia (fijo) y como respaldo del pais de nacimiento.
  String? get _defaultCountryId => widget.controller.countries.isEmpty
      ? null
      : widget.controller.countries.first.id;

  /// Campo de pais de solo lectura: la vacunacion ocurre en Colombia.
  Widget _lockedCountryField(String label) {
    final name = widget.controller.countries.isEmpty
        ? 'Colombia'
        : widget.controller.countries.first.name;
    return TextFormField(
      initialValue: name,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Pais fijo mientras la vacunacion sea en Colombia.',
        suffixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: AppColors.hint,
        ),
      ),
    );
  }

  // ---------- navegacion ----------

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

  Future<void> _pickDate(
    TextEditingController target,
    DateTime? current,
    void Function(DateTime) onPicked,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      onPicked(picked);
      target.text = _format(picked);
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
      if (_step == 3) {
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
    for (final controller in [
      _documentNumber,
      _firstName,
      _secondName,
      _lastName,
      _secondLastName,
      _educationLevel,
      _birthPlace,
      _gestationalAge,
      _locality,
      _street,
      _landline,
      _cellphone,
      _email,
      _contraindicationDetails,
      _reactionDetails,
      _lastMenstrualDate,
      _previousPregnancies,
      _birthPlaceDelivery,
      _guardianFirstName,
      _guardianSecondName,
      _guardianLastName,
      _guardianSecondLastName,
      _guardianDocument,
      _guardianLandline,
      _guardianCellphone,
      _guardianEmail,
      _insurer,
    ]) {
      if (controller.text.trim().isNotEmpty) return true;
    }
    return _histories.isNotEmpty;
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
      if (_landline.text.trim().isNotEmpty)
        NewPatientContact(
          type: 'PHONE',
          value: _landline.text.trim(),
          phoneKind: 'LANDLINE',
          primary: _cellphone.text.trim().isEmpty,
        ),
      if (_cellphone.text.trim().isNotEmpty)
        NewPatientContact(
          type: 'PHONE',
          value: _cellphone.text.trim(),
          phoneKind: 'CELLPHONE',
          primary: true,
        ),
      if (_email.text.trim().isNotEmpty)
        NewPatientContact(type: 'EMAIL', value: _email.text.trim()),
    ];

    final guardians = <NewPatientGuardian>[
      if (_guardianFirstName.text.trim().isNotEmpty ||
          _guardianLastName.text.trim().isNotEmpty)
        NewPatientGuardian(
          relationship: _guardianRelationship,
          fullName: [
            _guardianFirstName.text.trim(),
            _guardianSecondName.text.trim(),
          ].where((part) => part.isNotEmpty).join(' '),
          secondName: _guardianSecondName.text.trim().isEmpty
              ? null
              : _guardianSecondName.text.trim(),
          secondLastName: _guardianSecondLastName.text.trim().isEmpty
              ? null
              : _guardianSecondLastName.text.trim(),
          documentType: _guardianDocument.text.trim().isEmpty
              ? null
              : _guardianDocumentType,
          documentNumber: _guardianDocument.text.trim().isEmpty
              ? null
              : _guardianDocument.text.trim(),
          landline: _guardianLandline.text.trim().isEmpty
              ? null
              : _guardianLandline.text.trim(),
          cellphone: _guardianCellphone.text.trim().isEmpty
              ? null
              : _guardianCellphone.text.trim(),
          email: _guardianEmail.text.trim().isEmpty
              ? null
              : _guardianEmail.text.trim(),
          displaced: _guardianDisplaced,
        ),
    ];

    final address = NewPatientAddress(
      street: _street.text.trim().isEmpty ? null : _street.text.trim(),
      departmentId: _departmentId,
      municipalityId: _municipalityId,
      countryId: _defaultCountryId,
      locality: _locality.text.trim().isEmpty ? null : _locality.text.trim(),
      area: _area,
    );

    final demographics =
        (_gender == null &&
            _sexualOrientation == null &&
            _ethnicity == null &&
            _educationLevel.text.trim().isEmpty)
        ? null
        : NewPatientDemographic(
            gender: _gender,
            ethnicity: _ethnicity,
            sexualOrientation: _sexualOrientation,
            educationLevel: _educationLevel.text.trim().isEmpty
                ? null
                : _educationLevel.text.trim(),
          );

    final affiliation =
        (_affiliationRegime == null && _insurer.text.trim().isEmpty)
        ? null
        : NewPatientAffiliation(
            affiliationRegime: _affiliationRegime,
            insurer: _insurer.text.trim().isEmpty ? null : _insurer.text.trim(),
          );

    final specialConditions =
        (_displaced == null &&
            _disabled == null &&
            _deceased == null &&
            _armedConflictVictim == null &&
            _currentlyStudying == null)
        ? null
        : NewPatientSpecialConditions(
            displaced: _displaced,
            disabled: _disabled,
            deceased: _deceased,
            armedConflictVictim: _armedConflictVictim,
            currentlyStudying: _currentlyStudying,
          );

    final userCondition =
        (_userCondition == null &&
            _lastMenstrual == null &&
            _previousPregnancies.text.trim().isEmpty &&
            _birthPlaceDelivery.text.trim().isEmpty)
        ? null
        : NewPatientUserCondition(
            userCondition: _userCondition,
            lastMenstrualDate: _lastMenstrual == null
                ? null
                : _format(_lastMenstrual!),
            previousPregnancies: int.tryParse(_previousPregnancies.text.trim()),
            birthPlaceDelivery: _birthPlaceDelivery.text.trim().isEmpty
                ? null
                : _birthPlaceDelivery.text.trim(),
          );

    final contraindicationDetails = _contraindicationDetails.text.trim();
    final reactionDetails = _reactionDetails.text.trim();
    final histories = <NewPatientMedicalHistory>[];
    var flagsAssigned = false;
    for (final history in _histories) {
      if (history.condition.text.trim().isEmpty) continue;
      // Contraindicacion y reaccion son del paciente, no de una fila puntual:
      // se adjuntan a la primera fila de antecedentes.
      final isFirstRow = !flagsAssigned;
      histories.add(
        NewPatientMedicalHistory(
          condition: history.condition.text.trim(),
          diagnosedAt: history.diagnosedAt == null
              ? null
              : _format(history.diagnosedAt!),
          notes: history.observations.text.trim().isEmpty
              ? null
              : history.observations.text.trim(),
          historyType: history.type.text.trim().isEmpty
              ? null
              : history.type.text.trim(),
          hasContraindication: isFirstRow ? _hasContraindication : null,
          contraindicationDetails: isFirstRow && _hasContraindication
              ? (contraindicationDetails.isEmpty
                    ? null
                    : contraindicationDetails)
              : null,
          hasPreviousReaction: isFirstRow ? _hasPreviousReaction : null,
          reactionDetails: isFirstRow && _hasPreviousReaction
              ? (reactionDetails.isEmpty ? null : reactionDetails)
              : null,
        ),
      );
      flagsAssigned = true;
    }
    // Si no hubo filas de antecedentes pero si contraindicacion/reaccion, se
    // crea una fila que las transporte (el backend exige `condition`).
    if (!flagsAssigned && (_hasContraindication || _hasPreviousReaction)) {
      histories.add(
        NewPatientMedicalHistory(
          condition: 'Antecedentes de vacunacion',
          hasContraindication: _hasContraindication,
          contraindicationDetails:
              _hasContraindication && contraindicationDetails.isNotEmpty
              ? contraindicationDetails
              : null,
          hasPreviousReaction: _hasPreviousReaction,
          reactionDetails: _hasPreviousReaction && reactionDetails.isNotEmpty
              ? reactionDetails
              : null,
        ),
      );
    }

    final input = NewPatientInput(
      documentType: _documentType,
      documentNumber: _documentNumber.text.trim(),
      firstName: _firstName.text.trim(),
      secondName: _secondName.text.trim().isEmpty
          ? null
          : _secondName.text.trim(),
      lastName: _lastName.text.trim(),
      secondLastName: _secondLastName.text.trim().isEmpty
          ? null
          : _secondLastName.text.trim(),
      birthDate: _format(_birth!),
      sex: _sex,
      birthCountryId: _birthCountryId ?? _defaultCountryId,
      birthPlace: _birthPlace.text.trim().isEmpty
          ? null
          : _birthPlace.text.trim(),
      migrationStatus: _migrationStatus,
      gestationalAgeAtBirth: int.tryParse(_gestationalAge.text.trim()),
      vaccinationCardType: _carnetType,
      authorizeCalls: _authorizeCalls,
      authorizeEmail: _authorizeEmail,
      demographics: demographics,
      affiliation: affiliation,
      specialConditions: specialConditions,
      userCondition: userCondition,
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

  // ---------- build ----------

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
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PASO ${_step + 1} DE ${_steps.length}',
              style: AppTextStyles.overline.copyWith(color: AppColors.slate),
            ),
            const Spacer(),
            Text(
              'Registro de paciente',
              style: AppTextStyles.overline.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FolioRail(count: _steps.length, current: _step),
        const SizedBox(height: 12),
        _StepHint(_stepHints[_step]),
      ],
    ),
  );

  Widget _stepContent() {
    final body = switch (_step) {
      0 => _identityStep(),
      1 => _demographicsStep(),
      2 => _affiliationStep(),
      3 => _residenceStep(),
      4 => _specialConditionsStep(),
      5 => _historyStep(),
      6 => _userConditionStep(),
      _ => _guardianStep(),
    };
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(
            index: (_step + 1).toString().padLeft(2, '0'),
            title: _steps[_step],
            subtitle: _step == 0 ? 'Solo esta seccion es obligatoria' : null,
          ),
          const SizedBox(height: 18),
          body,
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? helper,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    bool readOnly = false,
    VoidCallback? onTap,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      readOnly: readOnly,
      onTap: onTap,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixIcon: readOnly ? const Icon(Icons.calendar_today_outlined) : null,
      ),
    ),
  );

  Widget _yesNoDropdown(
    bool? value,
    String label,
    ValueChanged<bool?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<bool?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem(value: null, child: Text('Sin dato')),
        DropdownMenuItem(value: true, child: Text('Si')),
        DropdownMenuItem(value: false, child: Text('No')),
      ],
      onChanged: onChanged,
    ),
  );

  Widget _identityStep() => Form(
    key: _identityFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _documentType,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo de documento'),
          items: _documentTypeItems(),
          onChanged: (value) => setState(() => _documentType = value ?? 'CC'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _documentNumber,
          keyboardType: documentKeyboardType(_documentType),
          inputFormatters: documentInputFormatters(_documentType),
          onChanged: (_) => setState(() {}),
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
        const SizedBox(height: 16),
        TextFormField(
          controller: _firstName,
          textCapitalization: TextCapitalization.words,
          inputFormatters: maxLengthFormatters(FieldLimits.name),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Primer nombre'),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _secondName,
          textCapitalization: TextCapitalization.words,
          inputFormatters: maxLengthFormatters(FieldLimits.name),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Segundo nombre'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _lastName,
          textCapitalization: TextCapitalization.words,
          inputFormatters: maxLengthFormatters(FieldLimits.name),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Primer apellido'),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _secondLastName,
          textCapitalization: TextCapitalization.words,
          inputFormatters: maxLengthFormatters(FieldLimits.name),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Segundo apellido'),
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
          items: _refItems('sex', fallback: _sexFallback),
          onChanged: (value) => setState(() => _sex = value ?? 'MALE'),
        ),
        const SizedBox(height: 8),
        _identityPreview(),
      ],
    ),
  );

  /// Vista previa en vivo del registro: ayuda al vacunador a verificar que el
  /// documento y el nombre son los correctos antes de continuar.
  Widget _identityPreview() {
    final name = [
      _firstName.text.trim(),
      _secondName.text.trim(),
      _lastName.text.trim(),
      _secondLastName.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (_documentNumber.text.trim().isEmpty && name.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IdentityStrip(
        documentType: _documentType,
        documentNumber: _documentNumber.text.trim().isEmpty
            ? 'sin documento'
            : _documentNumber.text.trim(),
        name: name.isEmpty ? 'Sin nombre' : name.toUpperCase(),
      ),
    );
  }

  Widget _demographicsStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String?>(
        initialValue: _gender,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Genero'),
        items: _refItemsN('gender'),
        onChanged: (value) => setState(() => _gender = value),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        initialValue: _sexualOrientation,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Orientacion sexual'),
        items: _refItemsN('sexual_orientation'),
        onChanged: (value) => setState(() => _sexualOrientation = value),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        initialValue: _ethnicity,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Pertenencia etnica'),
        items: _refItemsN('ethnicity'),
        onChanged: (value) => setState(() => _ethnicity = value),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        initialValue: _carnetType,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Tipo de carnet'),
        items: _refItemsN('carnet_type'),
        onChanged: (value) => setState(() => _carnetType = value),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        initialValue: _birthCountryId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Pais de nacimiento'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Sin dato')),
          for (final GeoCountry country in widget.controller.countries)
            DropdownMenuItem(value: country.id, child: Text(country.name)),
        ],
        onChanged: (value) => setState(() => _birthCountryId = value),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _migrationStatus,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Estatus migratorio'),
        items: _refItems(
          'migration_status',
          fallback: const [
            ReferenceOption(code: 'REGULAR', label: 'Regular', sortOrder: 1),
            ReferenceOption(
              code: 'IRREGULAR',
              label: 'Irregular',
              sortOrder: 2,
            ),
          ],
        ),
        onChanged: (value) =>
            setState(() => _migrationStatus = value ?? 'REGULAR'),
      ),
      const SizedBox(height: 16),
      _textField(
        _birthPlace,
        'Lugar de nacimiento',
        helper: 'Institucion o municipio donde nacio.',
        formatters: maxLengthFormatters(FieldLimits.name),
      ),
      _textField(
        _gestationalAge,
        'Edad gestacional al nacer (semanas)',
        keyboardType: TextInputType.number,
      ),
      _textField(
        _educationLevel,
        'Escolaridad',
        formatters: maxLengthFormatters(FieldLimits.educationLevel),
      ),
    ],
  );

  Widget _affiliationStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String?>(
        initialValue: _affiliationRegime,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Regimen de afiliacion'),
        items: _refItemsN('affiliation_regime'),
        onChanged: (value) => setState(() => _affiliationRegime = value),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        initialValue: null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Aseguradora / EPS'),
        items: _refItemsN('insurer'),
        onChanged: (value) => setState(() {
          if (value != null) {
            final options = _ref('insurer');
            final match = options.where((o) => o.code == value).toList();
            _insurer.text = match.isEmpty ? value : match.first.label;
          }
        }),
      ),
      const SizedBox(height: 16),
      _textField(_insurer, 'Nombre de la aseguradora (si no esta en la lista)'),
    ],
  );

  Widget _residenceStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _lockedCountryField('Pais de residencia'),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        initialValue: _departmentId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Departamento'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Sin dato')),
          for (final GeoDepartment department in widget.controller.departments)
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
      const SizedBox(height: 16),
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
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        initialValue: _area,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Area'),
        items: _refItemsN('area'),
        onChanged: (value) => setState(() => _area = value),
      ),
      const SizedBox(height: 16),
      _textField(
        _locality,
        'Comuna / Localidad',
        formatters: maxLengthFormatters(FieldLimits.name),
      ),
      _textField(
        _street,
        'Direccion con nomenclatura',
        formatters: maxLengthFormatters(FieldLimits.street),
      ),
      _textField(
        _landline,
        'Telefono fijo',
        keyboardType: TextInputType.phone,
        formatters: phoneFormatters(),
      ),
      _textField(
        _cellphone,
        'Celular',
        keyboardType: TextInputType.phone,
        formatters: phoneFormatters(),
      ),
      _textField(
        _email,
        'Correo electronico',
        keyboardType: TextInputType.emailAddress,
        formatters: maxLengthFormatters(FieldLimits.email),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('¿Autoriza llamadas telefonicas?'),
        value: _authorizeCalls,
        onChanged: (value) => setState(() => _authorizeCalls = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('¿Autoriza envio de correo?'),
        value: _authorizeEmail,
        onChanged: (value) => setState(() => _authorizeEmail = value),
      ),
    ],
  );

  Widget _specialConditionsStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _yesNoDropdown(
        _displaced,
        '¿Desplazado?',
        (value) => setState(() => _displaced = value),
      ),
      _yesNoDropdown(
        _disabled,
        '¿Discapacitado?',
        (value) => setState(() => _disabled = value),
      ),
      _yesNoDropdown(
        _deceased,
        '¿Fallecido?',
        (value) => setState(() => _deceased = value),
      ),
      _yesNoDropdown(
        _armedConflictVictim,
        '¿Victima del conflicto armado?',
        (value) => setState(() => _armedConflictVictim = value),
      ),
      _yesNoDropdown(
        _currentlyStudying,
        '¿Estudia actualmente?',
        (value) => setState(() => _currentlyStudying = value),
      ),
    ],
  );

  Widget _historyStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          '¿Sufre o ha sufrido alguna enfermedad que contraindique la vacunacion?',
        ),
        value: _hasContraindication,
        onChanged: (value) => setState(() => _hasContraindication = value),
      ),
      if (_hasContraindication)
        _textField(
          _contraindicationDetails,
          '¿Cual?',
          formatters: maxLengthFormatters(FieldLimits.name),
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          '¿Ha presentado reaccion moderada o severa a biologico anteriores?',
        ),
        value: _hasPreviousReaction,
        onChanged: (value) => setState(() => _hasPreviousReaction = value),
      ),
      if (_hasPreviousReaction)
        _textField(
          _reactionDetails,
          '¿Cual?',
          formatters: maxLengthFormatters(FieldLimits.name),
        ),
      const SizedBox(height: 8),
      _sectionTitle('Historico de antecedentes'),
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
                    labelText: 'Descripcion',
                    helperText: 'Ej: asma, alergias, cardiopatia.',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _histories[i].type,
                  inputFormatters: maxLengthFormatters(FieldLimits.name),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _histories[i].dateText,
                        readOnly: true,
                        onTap: () => _pickHistoryDate(i),
                        decoration: const InputDecoration(
                          labelText: 'Fecha de registro',
                        ),
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
                  controller: _histories[i].observations,
                  inputFormatters: maxLengthFormatters(
                    FieldLimits.historyNotes,
                  ),
                  decoration: const InputDecoration(labelText: 'Notas'),
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
      const SizedBox(height: 10),
    ],
  );

  Widget _userConditionStep() {
    if (!_showUserCondition) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'La condicion de la usuaria aplica para mujeres desde los 9 anos. '
          'Puedes continuar.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _userCondition,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Condicion de la usuaria',
          ),
          items: _refItemsN('user_condition'),
          onChanged: (value) => setState(() => _userCondition = value),
        ),
        const SizedBox(height: 16),
        _textField(
          _lastMenstrualDate,
          'Fecha de ultima menstruacion',
          readOnly: true,
          onTap: () => _pickDate(
            _lastMenstrualDate,
            _lastMenstrual,
            (d) => _lastMenstrual = d,
          ),
        ),
        _textField(
          _previousPregnancies,
          'Cantidad de embarazos previos',
          keyboardType: TextInputType.number,
        ),
        _textField(
          _birthPlaceDelivery,
          'Lugar de atencion del parto',
          formatters: maxLengthFormatters(FieldLimits.name),
        ),
      ],
    );
  }

  Widget _guardianStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: _guardianRelationship,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Parentesco'),
        items: _refItems(
          'guardian_relationship',
          fallback: const [
            ReferenceOption(code: 'MOTHER', label: 'Madre', sortOrder: 1),
            ReferenceOption(code: 'FATHER', label: 'Padre', sortOrder: 2),
            ReferenceOption(code: 'CAREGIVER', label: 'Cuidador', sortOrder: 3),
            ReferenceOption(code: 'OTHER', label: 'Otro', sortOrder: 4),
          ],
        ),
        onChanged: (value) =>
            setState(() => _guardianRelationship = value ?? 'CAREGIVER'),
      ),
      const SizedBox(height: 16),
      _textField(
        _guardianFirstName,
        'Primer nombre',
        textCapitalization: TextCapitalization.words,
        formatters: maxLengthFormatters(FieldLimits.name),
      ),
      _textField(
        _guardianSecondName,
        'Segundo nombre',
        textCapitalization: TextCapitalization.words,
        formatters: maxLengthFormatters(FieldLimits.name),
      ),
      _textField(
        _guardianLastName,
        'Primer apellido',
        textCapitalization: TextCapitalization.words,
        formatters: maxLengthFormatters(FieldLimits.name),
      ),
      _textField(
        _guardianSecondLastName,
        'Segundo apellido',
        textCapitalization: TextCapitalization.words,
        formatters: maxLengthFormatters(FieldLimits.name),
      ),
      DropdownButtonFormField<String>(
        initialValue: _guardianDocumentType,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Tipo de identificacion'),
        items: _documentTypeItems(),
        onChanged: (value) =>
            setState(() => _guardianDocumentType = value ?? 'CC'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _guardianDocument,
        keyboardType: documentKeyboardType(_guardianDocumentType),
        inputFormatters: documentInputFormatters(_guardianDocumentType),
        decoration: const InputDecoration(labelText: 'Numero de documento'),
      ),
      const SizedBox(height: 16),
      _textField(
        _guardianLandline,
        'Telefono fijo',
        keyboardType: TextInputType.phone,
        formatters: phoneFormatters(),
      ),
      _textField(
        _guardianCellphone,
        'Celular',
        keyboardType: TextInputType.phone,
        formatters: phoneFormatters(),
      ),
      _textField(
        _guardianEmail,
        'Correo electronico',
        keyboardType: TextInputType.emailAddress,
        formatters: maxLengthFormatters(FieldLimits.email),
      ),
      _yesNoDropdown(
        _guardianDisplaced,
        '¿Desplazado?',
        (value) => setState(() => _guardianDisplaced = value),
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _previous,
                  child: const Text(
                    'Anterior',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isLast ? 'Guardar paciente' : 'Siguiente'),
                          const SizedBox(width: 6),
                          Icon(
                            isLast
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                        ],
                      ),
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
  final TextEditingController type = TextEditingController();
  final TextEditingController dateText = TextEditingController();
  final TextEditingController observations = TextEditingController();
  DateTime? diagnosedAt;

  void dispose() {
    condition.dispose();
    type.dispose();
    dateText.dispose();
    observations.dispose();
  }
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

/// Riel de folios: marca el avance del wizard sin ruido (segmentos, no numeros).
class _FolioRail extends StatelessWidget {
  const _FolioRail({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: i == current ? 5 : 3,
              decoration: BoxDecoration(
                color: i == current
                    ? AppColors.primary
                    : i < current
                    ? AppColors.primary.withValues(alpha: .35)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (i < count - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
