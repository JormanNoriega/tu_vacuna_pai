import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../../../core/auth/offline_access.dart';
import '../../../../../core/utils/document_input.dart';
import '../../../../../core/utils/field_input.dart';
import '../../../../catalogs/domain/entities/catalog_entities.dart';
import '../../attention_controller.dart';
import 'form_helpers.dart';

/// Paso 2: Datos Adicionales del Paciente (Demografía, Origen, Afiliación,
/// Residencia/Contacto, Condiciones Especiales, Antecedentes, Condición Obstétrica y Cuidador).
class Step2AdditionalDataStep extends StatefulWidget {
  const Step2AdditionalDataStep({
    required this.formKey,
    required this.controller,
    required this.offline,
    required this.birthDate,
    required this.sex,
    required this.onSexChanged,
    required this.gender,
    required this.onGenderChanged,
    required this.sexualOrientation,
    required this.onSexualOrientationChanged,
    required this.ethnicity,
    required this.onEthnicityChanged,
    required this.educationLevelController,
    required this.birthCountryId,
    required this.onBirthCountryChanged,
    required this.birthPlaceController,
    required this.migrationStatus,
    required this.onMigrationStatusChanged,
    required this.vaccinationCardType,
    required this.onVaccinationCardTypeChanged,
    required this.gestationalAgeController,
    required this.affiliationRegime,
    required this.onAffiliationRegimeChanged,
    required this.selectedInsurer,
    required this.onInsurerChanged,
    required this.departmentId,
    required this.onDepartmentChanged,
    required this.municipalityId,
    required this.onMunicipalityChanged,
    required this.streetController,
    required this.localityController,
    required this.area,
    required this.onAreaChanged,
    required this.landlineController,
    required this.cellphoneController,
    required this.emailController,
    required this.authorizeCalls,
    required this.onAuthorizeCallsChanged,
    required this.authorizeEmail,
    required this.onAuthorizeEmailChanged,
    required this.displaced,
    required this.onDisplacedChanged,
    required this.disabled,
    required this.onDisabledChanged,
    required this.deceased,
    required this.onDeceasedChanged,
    required this.armedConflictVictim,
    required this.onArmedConflictVictimChanged,
    required this.currentlyStudying,
    required this.onCurrentlyStudyingChanged,
    required this.hasContraindication,
    required this.onHasContraindicationChanged,
    required this.contraindicationDetailsController,
    required this.hasPreviousReaction,
    required this.onHasPreviousReactionChanged,
    required this.reactionDetailsController,
    required this.userCondition,
    required this.onUserConditionChanged,
    required this.lastMenstrualDateController,
    required this.previousPregnanciesController,
    required this.birthPlaceDeliveryController,
    required this.guardianRelationship,
    required this.onGuardianRelationshipChanged,
    required this.guardianDocumentType,
    required this.onGuardianDocumentTypeChanged,
    required this.guardianDocumentController,
    required this.guardianFirstNameController,
    required this.guardianLastNameController,
    required this.guardianCellphoneController,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final AttentionController controller;
  final OfflineAccess offline;
  final DateTime? birthDate;

  // Demográficos
  final String? sex;
  final ValueChanged<String?> onSexChanged;
  final String? gender;
  final ValueChanged<String?> onGenderChanged;
  final String? sexualOrientation;
  final ValueChanged<String?> onSexualOrientationChanged;
  final String? ethnicity;
  final ValueChanged<String?> onEthnicityChanged;
  final TextEditingController educationLevelController;

  // Origen
  final String? birthCountryId;
  final ValueChanged<String?> onBirthCountryChanged;
  final TextEditingController birthPlaceController;
  final String migrationStatus;
  final ValueChanged<String> onMigrationStatusChanged;
  final String? vaccinationCardType;
  final ValueChanged<String?> onVaccinationCardTypeChanged;
  final TextEditingController gestationalAgeController;

  // Afiliación
  final String? affiliationRegime;
  final ValueChanged<String?> onAffiliationRegimeChanged;
  final HealthInsurer? selectedInsurer;
  final ValueChanged<HealthInsurer?> onInsurerChanged;

  // Residencia
  final String? departmentId;
  final ValueChanged<String?> onDepartmentChanged;
  final String? municipalityId;
  final ValueChanged<String?> onMunicipalityChanged;
  final TextEditingController streetController;
  final TextEditingController localityController;
  final String? area;
  final ValueChanged<String?> onAreaChanged;
  final TextEditingController landlineController;
  final TextEditingController cellphoneController;
  final TextEditingController emailController;
  final bool authorizeCalls;
  final ValueChanged<bool> onAuthorizeCallsChanged;
  final bool authorizeEmail;
  final ValueChanged<bool> onAuthorizeEmailChanged;

  // Condiciones Especiales
  final bool displaced;
  final ValueChanged<bool> onDisplacedChanged;
  final bool disabled;
  final ValueChanged<bool> onDisabledChanged;
  final bool deceased;
  final ValueChanged<bool> onDeceasedChanged;
  final bool armedConflictVictim;
  final ValueChanged<bool> onArmedConflictVictimChanged;
  final bool currentlyStudying;
  final ValueChanged<bool> onCurrentlyStudyingChanged;

  // Antecedentes
  final bool hasContraindication;
  final ValueChanged<bool> onHasContraindicationChanged;
  final TextEditingController contraindicationDetailsController;
  final bool hasPreviousReaction;
  final ValueChanged<bool> onHasPreviousReactionChanged;
  final TextEditingController reactionDetailsController;

  // Condición Obstétrica
  final String? userCondition;
  final ValueChanged<String?> onUserConditionChanged;
  final TextEditingController lastMenstrualDateController;
  final TextEditingController previousPregnanciesController;
  final TextEditingController birthPlaceDeliveryController;

  // Cuidador
  final String guardianRelationship;
  final ValueChanged<String> onGuardianRelationshipChanged;
  final String guardianDocumentType;
  final ValueChanged<String> onGuardianDocumentTypeChanged;
  final TextEditingController guardianDocumentController;
  final TextEditingController guardianFirstNameController;
  final TextEditingController guardianLastNameController;
  final TextEditingController guardianCellphoneController;

  @override
  State<Step2AdditionalDataStep> createState() =>
      _Step2AdditionalDataStepState();
}

class _Step2AdditionalDataStepState extends State<Step2AdditionalDataStep>
    with AutomaticKeepAliveClientMixin {
  late bool _hasGuardian;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _hasGuardian = widget.guardianDocumentController.text.isNotEmpty ||
        widget.guardianFirstNameController.text.isNotEmpty ||
        widget.guardianLastNameController.text.isNotEmpty ||
        widget.guardianCellphoneController.text.isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadReferenceCatalogs();
      widget.controller.loadCountries();
      widget.controller.loadDepartments();
      widget.controller.loadInsurers();
      if (widget.departmentId != null) {
        widget.controller.loadMunicipalities(widget.departmentId!);
      }
    });
  }

  bool get _isUnderOneYear {
    if (widget.birthDate == null) return false;
    final now = DateTime.now();
    final diffDays = now.difference(widget.birthDate!).inDays;
    return diffDays < 365;
  }

  bool get _isFemaleAtLeastNineYears {
    if (widget.sex != 'FEMALE' || widget.birthDate == null) return false;
    final age = calculateDetailedAge(widget.birthDate!);
    return age['years']! >= 9;
  }

  List<ReferenceOption> _refOptions(String code) =>
      widget.controller.referenceOptions(code);

  static const _educationLevelOptions = [
    'Ninguno',
    'Preescolar',
    'Primaria',
    'Secundaria',
    'Media / Bachillerato',
    'Técnico / Tecnológico',
    'Universitario',
    'Posgrado',
    'No informa',
  ];

  List<String> get _effectiveEducationLevels {
    final list = List<String>.from(_educationLevelOptions);
    final current = widget.educationLevelController.text.trim();
    if (current.isNotEmpty &&
        !list.any((e) => e.toLowerCase() == current.toLowerCase())) {
      list.insert(0, current);
    }
    return list;
  }

  String? _selectedEducationLevel() {
    final current = widget.educationLevelController.text.trim();
    if (current.isEmpty) return null;
    return _effectiveEducationLevels.cast<String?>().firstWhere(
      (opt) => opt?.toLowerCase() == current.toLowerCase(),
      orElse: () => null,
    );
  }

  static const _carnetTypeFallbacks = [
    ReferenceOption(
      code: 'CARNE_VACUNACION_INFANTIL',
      label: 'Carné de Vacunación Infantil',
      sortOrder: 1,
    ),
    ReferenceOption(
      code: 'CARNE_VACUNACION_ADULTOS',
      label: 'Carné/Certificado de Vacunación de Adultos',
      sortOrder: 2,
    ),
    ReferenceOption(
      code: 'CARNE_VACUNACION_INTERNACIONAL',
      label: 'Carné/Certificado Internacional de Vacunación',
      sortOrder: 3,
    ),
    ReferenceOption(
      code: 'TARJETAS_UNIFICADAS_VACUNACION_ADULTOS',
      label: 'Tarjetas Unificadas de Vacunación - TUV Adultos',
      sortOrder: 4,
    ),
    ReferenceOption(
      code: 'TARJETAS_UNIFICADAS_VACUNACION_NINOS',
      label: 'Tarjetas Unificadas de Vacunación - TUV Niños',
      sortOrder: 5,
    ),
  ];

  List<ReferenceOption> get _carnetOptions {
    final catalog = _refOptions('carnet_type');
    return catalog.isNotEmpty ? catalog : _carnetTypeFallbacks;
  }

  String? _resolveCarnetValue(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final options = _carnetOptions;
    for (final opt in options) {
      if (opt.code == raw ||
          opt.code.replaceAll('_', '').toLowerCase() ==
              raw.replaceAll('_', '').toLowerCase()) {
        return opt.code;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
                  'Datos Adicionales',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Información sociodemográfica, residencia, EPS y antecedentes. Los campos con asterisco (*) son obligatorios.',
                  style: TextStyle(color: AppColors.slate, fontSize: 13.5),
                ),
              ],
            ),
          ),

          // SECCIÓN 1: DATOS DEMOGRÁFICOS
          FormCard(
            title: '1. Datos Demográficos',
            icon: Icons.badge_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sexo (Requerido)
                FormField<String>(
                  initialValue: widget.sex,
                  validator: (_) => widget.sex == null || widget.sex!.isEmpty
                      ? 'Seleccione el sexo'
                      : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      requiredFieldLabel(
                        'Sexo',
                        style: const TextStyle(
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
                              label: 'Mujer',
                              icon: Icons.female_rounded,
                              isSelected: widget.sex == 'FEMALE',
                              hasError: field.hasError,
                              onTap: () {
                                widget.onSexChanged('FEMALE');
                                field.didChange('FEMALE');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectionOptionButton(
                              label: 'Hombre',
                              icon: Icons.male_rounded,
                              isSelected: widget.sex == 'MALE',
                              hasError: field.hasError,
                              onTap: () {
                                widget.onSexChanged('MALE');
                                field.didChange('MALE');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectionOptionButton(
                              label: 'Indet.',
                              icon: Icons.help_outline_rounded,
                              isSelected: widget.sex == 'INDETERMINATE',
                              hasError: field.hasError,
                              onTap: () {
                                widget.onSexChanged('INDETERMINATE');
                                field.didChange('INDETERMINATE');
                              },
                            ),
                          ),
                        ],
                      ),
                      if (field.hasError) ...[
                        const SizedBox(height: 6),
                        Text(
                          field.errorText!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Género
                DropdownButtonFormField<String>(
                  initialValue: widget.gender,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Género'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No especificado'),
                    ),
                    for (final opt in _refOptions('gender'))
                      DropdownMenuItem(value: opt.code, child: Text(opt.label)),
                  ],
                  onChanged: widget.onGenderChanged,
                ),
                const SizedBox(height: 16),

                // Orientación Sexual
                DropdownButtonFormField<String>(
                  initialValue: widget.sexualOrientation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Orientación Sexual',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No especificada'),
                    ),
                    for (final opt in _refOptions('sexual_orientation'))
                      DropdownMenuItem(value: opt.code, child: Text(opt.label)),
                  ],
                  onChanged: widget.onSexualOrientationChanged,
                ),
                const SizedBox(height: 16),

                // Etnia
                DropdownButtonFormField<String>(
                  initialValue: widget.ethnicity,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pertenencia Étnica',
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    final opts = _refOptions('ethnicity');
                    return [
                      const Text(
                        'No aplica / Ninguna',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      for (final opt in opts)
                        Text(
                          opt.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ];
                  },
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No aplica / Ninguna'),
                    ),
                    for (final opt in _refOptions('ethnicity'))
                      DropdownMenuItem(
                        value: opt.code,
                        child: Text(
                          opt.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: widget.onEthnicityChanged,
                ),
                const SizedBox(height: 16),

                // Nivel Educativo / Escolaridad (Dropdown con opciones estándar)
                DropdownButtonFormField<String>(
                  initialValue: _selectedEducationLevel(),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Nivel Educativo / Escolaridad',
                    prefixIcon: Icon(Icons.school_outlined, size: 20),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Seleccione escolaridad'),
                    ),
                    for (final opt in _effectiveEducationLevels)
                      DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt),
                      ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      widget.educationLevelController.text = val ?? '';
                    });
                  },
                ),
              ],
            ),
          ),

          // SECCIÓN 2: ORIGEN Y MIGRACIÓN
          FormCard(
            title: '2. Origen y Migración',
            icon: Icons.flight_land_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // País de Nacimiento
                DropdownButtonFormField<String>(
                  initialValue:
                      widget.birthCountryId ??
                      (widget.controller.countries.isNotEmpty
                          ? widget.controller.countries.first.id
                          : null),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'País de Nacimiento',
                  ),
                  items: [
                    for (final country in widget.controller.countries)
                      DropdownMenuItem(
                        value: country.id,
                        child: Text('${country.code} - ${country.name}'),
                      ),
                  ],
                  onChanged: widget.onBirthCountryChanged,
                ),
                const SizedBox(height: 16),

                // Lugar de Nacimiento
                TextFormField(
                  controller: widget.birthPlaceController,
                  inputFormatters: maxLengthFormatters(FieldLimits.birthPlace),
                  decoration: const InputDecoration(
                    labelText: 'Lugar de Nacimiento (Hospital o Institución)',
                    hintText: 'Ej: Hospital Rosario Pumarejo',
                    prefixIcon: Icon(Icons.local_hospital_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),

                // Estatus Migratorio
                DropdownButtonFormField<String>(
                  initialValue: widget.migrationStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Estatus Migratorio',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'REGULAR', child: Text('Regular')),
                    DropdownMenuItem(
                      value: 'IRREGULAR',
                      child: Text('Irregular'),
                    ),
                    DropdownMenuItem(
                      value: 'MIGRANTE_REFUGIADO',
                      child: Text('Migrante / Refugiado'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) widget.onMigrationStatusChanged(val);
                  },
                ),
                const SizedBox(height: 16),

                // Tipo de Carnet
                DropdownButtonFormField<String?>(
                  initialValue: _resolveCarnetValue(widget.vaccinationCardType),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Carnet de Vacunación',
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    return [
                      const Text(
                        'No especificado',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      for (final opt in _carnetOptions)
                        Text(
                          opt.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ];
                  },
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No especificado'),
                    ),
                    for (final opt in _carnetOptions)
                      DropdownMenuItem(
                        value: opt.code,
                        child: Text(
                          opt.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (val) => widget.onVaccinationCardTypeChanged(val),
                ),

                // Edad Gestacional al nacer (Obligatoria para menores de 1 año)
                if (_isUnderOneYear) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: widget.gestationalAgeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: digitsOnlyFormatters(max: 2),
                    decoration: InputDecoration(
                      label: requiredFieldLabel('Edad Gestacional al Nacer (Semanas)'),
                      helperText:
                          'Obligatoria para menores de 1 año (0-45 sem).',
                    ),
                    validator: (val) {
                      if (_isUnderOneYear) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Ingresa las semanas de gestación al nacer';
                        }
                        final parsed = int.tryParse(val.trim());
                        if (parsed == null || parsed < 0 || parsed > 45) {
                          return 'Debe ser entre 0 y 45 semanas';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),

          // SECCIÓN 3: ATENCIÓN Y SEGURIDAD SOCIAL
          FormCard(
            title: '3. Afiliación y Seguridad Social',
            icon: Icons.health_and_safety_outlined,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: widget.affiliationRegime,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Régimen de Afiliación',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('No especificado'),
                    ),
                    for (final opt in _refOptions('affiliation_regime'))
                      DropdownMenuItem(value: opt.code, child: Text(opt.label)),
                  ],
                  onChanged: (val) {
                    widget.onAffiliationRegimeChanged(val);
                    widget.onInsurerChanged(null);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<HealthInsurer>(
                  initialValue: widget.selectedInsurer,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Aseguradora / EPS',
                    helperText: 'Filtra según el régimen seleccionado',
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    final insurers = widget.controller.insurersForRegime(
                      widget.affiliationRegime,
                    );
                    return [
                      const Text(
                        'Sin EPS / No aplica',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      for (final ins in insurers)
                        Text(
                          '${ins.code} - ${ins.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ];
                  },
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin EPS / No aplica'),
                    ),
                    for (final ins in widget.controller.insurersForRegime(
                      widget.affiliationRegime,
                    ))
                      DropdownMenuItem(
                        value: ins,
                        child: Text(
                          '${ins.code} - ${ins.name}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: widget.onInsurerChanged,
                ),
              ],
            ),
          ),

          // SECCIÓN 4: CONTACTO Y RESIDENCIA
          FormCard(
            title: '4. Residencia y Contacto',
            icon: Icons.home_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Departamento
                DropdownButtonFormField<String>(
                  initialValue: widget.departmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Departamento de Residencia',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Seleccione departamento'),
                    ),
                    for (final dep in widget.controller.departments)
                      DropdownMenuItem(value: dep.id, child: Text(dep.name)),
                  ],
                  onChanged: (depId) {
                    widget.onDepartmentChanged(depId);
                    if (depId != null) {
                      widget.controller.loadMunicipalities(depId);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Municipio
                DropdownButtonFormField<String>(
                  initialValue: widget.municipalityId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Municipio de Residencia',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Seleccione municipio'),
                    ),
                    for (final mun in widget.controller.municipalities)
                      DropdownMenuItem(value: mun.id, child: Text(mun.name)),
                  ],
                  onChanged: widget.onMunicipalityChanged,
                ),
                const SizedBox(height: 16),

                // Dirección y Barrio
                TextFormField(
                  controller: widget.streetController,
                  inputFormatters: maxLengthFormatters(FieldLimits.street),
                  decoration: const InputDecoration(
                    labelText: 'Dirección de Residencia',
                    hintText: 'Ej: Carrera 10 # 20 - 30',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: widget.localityController,
                  inputFormatters: maxLengthFormatters(FieldLimits.locality),
                  decoration: const InputDecoration(
                    labelText: 'Barrio / Localidad',
                    hintText: 'Ej: San Fernando',
                  ),
                ),
                const SizedBox(height: 16),

                // Área (Urbana / Rural)
                requiredFieldLabel('Área'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AreaOptionCard(
                        label: 'Urbana',
                        icon: Icons.apartment_rounded,
                        isSelected: widget.area == 'URBANA',
                        onTap: () => widget.onAreaChanged(
                          widget.area == 'URBANA' ? null : 'URBANA',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: AreaOptionCard(
                        label: 'Rural',
                        icon: Icons.park_rounded,
                        isSelected: widget.area == 'RURAL',
                        onTap: () => widget.onAreaChanged(
                          widget.area == 'RURAL' ? null : 'RURAL',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Teléfonos
                TextFormField(
                  controller: widget.cellphoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: digitsOnlyFormatters(max: 10),
                  decoration: const InputDecoration(
                    labelText: 'Teléfono Celular',
                    prefixIcon: Icon(Icons.phone_android_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: widget.landlineController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: digitsOnlyFormatters(max: 10),
                  decoration: const InputDecoration(
                    labelText: 'Teléfono Fijo',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),

                // Correo Electrónico
                TextFormField(
                  controller: widget.emailController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: maxLengthFormatters(FieldLimits.email),
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                // Autorizaciones
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Autoriza contacto por llamadas telefónicas',
                  ),
                  value: widget.authorizeCalls,
                  onChanged: widget.onAuthorizeCallsChanged,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Autoriza contacto por correo electrónico'),
                  value: widget.authorizeEmail,
                  onChanged: widget.onAuthorizeEmailChanged,
                ),
              ],
            ),
          ),

          // SECCIÓN 5: CONDICIONES ESPECIALES (POBLACIONES)
          FormCard(
            title: '5. Condiciones Especiales',
            icon: Icons.groups_outlined,
            child: Column(
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Población Desplazada'),
                  value: widget.displaced,
                  onChanged: (v) => widget.onDisplacedChanged(v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Persona con Discapacidad'),
                  value: widget.disabled,
                  onChanged: (v) => widget.onDisabledChanged(v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Víctima del Conflicto Armado'),
                  value: widget.armedConflictVictim,
                  onChanged: (v) =>
                      widget.onArmedConflictVictimChanged(v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Estudia Actualmente'),
                  value: widget.currentlyStudying,
                  onChanged: (v) =>
                      widget.onCurrentlyStudyingChanged(v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Paciente Fallecido'),
                  value: widget.deceased,
                  onChanged: (v) => widget.onDeceasedChanged(v ?? false),
                ),
              ],
            ),
          ),

          // SECCIÓN 6: ANTECEDENTES MÉDICOS
          FormCard(
            title: '6. Antecedentes Médicos',
            icon: Icons.medical_services_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('¿Tiene alguna contraindicación médica?'),
                  value: widget.hasContraindication,
                  onChanged: widget.onHasContraindicationChanged,
                ),
                if (widget.hasContraindication) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: widget.contraindicationDetailsController,
                    maxLines: 2,
                    inputFormatters: maxLengthFormatters(
                      FieldLimits.contraindicationDetails,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Detalle de la contraindicación',
                      hintText: 'Describa la contraindicación médica',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '¿Ha presentado reacciones previas a biológicos?',
                  ),
                  value: widget.hasPreviousReaction,
                  onChanged: widget.onHasPreviousReactionChanged,
                ),
                if (widget.hasPreviousReaction) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: widget.reactionDetailsController,
                    maxLines: 2,
                    inputFormatters: maxLengthFormatters(
                      FieldLimits.reactionDetails,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Detalle de la reacción adversa previa',
                      hintText: 'Describa la reacción presentada',
                    ),
                  ),
                ],
              ],
            ),
          ),

          // SECCIÓN 7: CONDICIÓN CLÍNICA (Solo mujeres >= 9 años)
          if (_isFemaleAtLeastNineYears)
            FormCard(
              title: '7. Condición de la Usuaria (Mujeres ≥ 9 años)',
              icon: Icons.pregnant_woman_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: widget.userCondition,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Condición de la usuaria',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('No especificada'),
                      ),
                      DropdownMenuItem(
                        value: 'NOT_PREGNANT',
                        child: Text('No gestante'),
                      ),
                      DropdownMenuItem(
                        value: 'PREGNANT',
                        child: Text('Gestante'),
                      ),
                      DropdownMenuItem(
                        value: 'POSTPARTUM',
                        child: Text('Puerperio / En lactancia'),
                      ),
                    ],
                    onChanged: widget.onUserConditionChanged,
                  ),
                  if (widget.userCondition == 'PREGNANT') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: widget.lastMenstrualDateController,
                      readOnly: true,
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now.subtract(const Duration(days: 300)),
                          lastDate: now,
                        );
                        if (picked != null) {
                          widget.lastMenstrualDateController.text =
                              formatIsoDate(picked);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Fecha de Última Menstruación (FUM)',
                        hintText: 'yyyy-MM-dd',
                        prefixIcon: Icon(Icons.calendar_today, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: widget.previousPregnanciesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: digitsOnlyFormatters(max: 2),
                      decoration: const InputDecoration(
                        labelText: 'Número de Gestaciones Previas',
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // SECCIÓN 8: DATOS DE LA MADRE / CUIDADOR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos del Cuidador / Madre',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¿Desea agregar datos del cuidador?',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Madre, tutor o responsable del paciente',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _hasGuardian,
                            activeTrackColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() => _hasGuardian = val);
                              if (!val) {
                                widget.guardianDocumentController.clear();
                                widget.guardianFirstNameController.clear();
                                widget.guardianLastNameController.clear();
                                widget.guardianCellphoneController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                      if (_hasGuardian) ...[
                        const SizedBox(height: 14),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: widget.guardianRelationship,
                          isExpanded: true,
                          decoration: InputDecoration(
                            label: requiredFieldLabel('Parentesco / Rol'),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'MOTHER',
                              child: Text('Madre'),
                            ),
                            DropdownMenuItem(
                              value: 'CAREGIVER',
                              child: Text('Cuidador responsable'),
                            ),
                            DropdownMenuItem(
                              value: 'FATHER',
                              child: Text('Padre'),
                            ),
                            DropdownMenuItem(
                              value: 'OTHER',
                              child: Text('Otro familiar / tutor'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              widget.onGuardianRelationshipChanged(val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: widget.guardianDocumentType,
                          isExpanded: true,
                          decoration: InputDecoration(
                            label: requiredFieldLabel('Tipo de Documento'),
                          ),
                          items: [
                            for (final opt
                                in _refOptions('document_type').isNotEmpty
                                    ? _refOptions('document_type')
                                    : documentTypeFallback)
                              DropdownMenuItem(
                                value: opt.code,
                                child: Text('${opt.code} - ${opt.label}'),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              widget.onGuardianDocumentTypeChanged(val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: widget.guardianDocumentController,
                          keyboardType: documentKeyboardType(
                            widget.guardianDocumentType,
                          ),
                          inputFormatters: [
                            ...documentInputFormatters(
                              widget.guardianDocumentType,
                            ),
                            ...maxLengthFormatters(FieldLimits.patientDocument),
                          ],
                          decoration: InputDecoration(
                            label: requiredFieldLabel('Número de Documento'),
                            hintText: 'Ej: 1234567890',
                          ),
                          validator: (val) {
                            if (_hasGuardian) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Número de identificación del cuidador requerido';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: widget.guardianFirstNameController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: nameFormatters(
                            max: FieldLimits.name,
                          ),
                          decoration: InputDecoration(
                            label: requiredFieldLabel('Primer Nombre'),
                            hintText: 'Ej: María',
                          ),
                          validator: (val) {
                            if (_hasGuardian) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Primer nombre del cuidador requerido';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: widget.guardianLastNameController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: nameFormatters(
                            max: FieldLimits.name,
                          ),
                          decoration: InputDecoration(
                            label: requiredFieldLabel('Apellidos'),
                            hintText: 'Ej: Pérez Gómez',
                          ),
                          validator: (val) {
                            if (_hasGuardian) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Apellidos del cuidador requeridos';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: widget.guardianCellphoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: digitsOnlyFormatters(max: 10),
                          decoration: const InputDecoration(
                            labelText: 'Teléfono / Celular',
                            hintText: 'Ej: 3001234567',
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
