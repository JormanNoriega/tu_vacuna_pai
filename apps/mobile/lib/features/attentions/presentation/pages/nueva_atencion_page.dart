import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/device/location_service.dart';
import '../../../../core/presentation/offline_messages.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../catalogs/domain/entities/catalog_entities.dart';
import '../../../patients/domain/entities/new_patient.dart';
import '../../../patients/domain/entities/patient.dart';
import '../attention_controller.dart';
import '../widgets/steps/form_helpers.dart';
import '../widgets/steps/staged_dose_data.dart';
import '../widgets/steps/step1_basic_data_step.dart';
import '../widgets/steps/step2_additional_data_step.dart';
import '../widgets/steps/step3_vaccines_step.dart';
import '../widgets/steps/step4_review_step.dart';

/// Flujo de Atención de Vacunación en 4 Pasos:
/// Paso 1: Datos Básicos del Paciente y fecha de atención.
/// Paso 2: Datos Adicionales (Demográficos, Residencia, EPS, Antecedentes, etc.).
/// Paso 3: Selección de Vacunas y Registro de Dosis.
/// Paso 4: Revisión, Cierre PAIWEB y Confirmación.
class NuevaAtencionPage extends StatefulWidget {
  const NuevaAtencionPage({
    required this.user,
    required this.controller,
    required this.offline,
    this.onFinished,
    this.onSubmittingChanged,
    super.key,
  });

  final AuthUser user;
  final AttentionController controller;
  final OfflineAccess offline;
  final VoidCallback? onFinished;
  final ValueChanged<bool>? onSubmittingChanged;

  @override
  State<NuevaAtencionPage> createState() => _NuevaAtencionPageState();
}

class _NuevaAtencionPageState extends State<NuevaAtencionPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 4;

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  // Ubicación GPS
  final _locationService = const LocationService();
  double? _latitude;
  double? _longitude;

  // Estado Paso 1
  late DateTime _attentionDate;
  String _documentType = 'CC';
  final _documentNumber = TextEditingController();
  final _firstName = TextEditingController();
  final _secondName = TextEditingController();
  final _lastName = TextEditingController();
  final _secondLastName = TextEditingController();
  DateTime? _birthDate;
  bool _completeScheme = false;
  bool _isExistingPatient = false;

  // Estado Paso 2
  String? _sex;
  String? _gender;
  String? _sexualOrientation;
  String? _ethnicity;
  final _educationLevel = TextEditingController();
  String? _birthCountryId;
  final _birthPlace = TextEditingController();
  String _migrationStatus = 'REGULAR';
  String? _vaccinationCardType;
  final _gestationalAge = TextEditingController();
  String? _affiliationRegime;
  HealthInsurer? _selectedInsurer;
  String? _departmentId;
  String? _municipalityId;
  final _street = TextEditingController();
  final _locality = TextEditingController();
  String? _area;
  final _landline = TextEditingController();
  final _cellphone = TextEditingController();
  final _email = TextEditingController();
  bool _authorizeCalls = false;
  bool _authorizeEmail = false;
  bool _displaced = false;
  bool _disabled = false;
  bool _deceased = false;
  bool _armedConflictVictim = false;
  bool _currentlyStudying = false;
  bool _hasContraindication = false;
  final _contraindicationDetails = TextEditingController();
  bool _hasPreviousReaction = false;
  final _reactionDetails = TextEditingController();
  String? _userCondition;
  final _lastMenstrualDate = TextEditingController();
  final _previousPregnancies = TextEditingController();
  final _birthPlaceDelivery = TextEditingController();
  String _guardianRelationship = 'CAREGIVER';
  String _guardianDocumentType = 'CC';
  final _guardianDocument = TextEditingController();
  final _guardianFirstName = TextEditingController();
  final _guardianLastName = TextEditingController();
  final _guardianCellphone = TextEditingController();

  // Estado Paso 3: Dosis configuradas en borrador
  final Map<String, StagedDose> _stagedDoses = {};

  // Estado Paso 4
  bool _paiwebRegistered = true;
  final _paiwebReason = TextEditingController();
  final _observations = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _attentionDate = DateTime.now();
    widget.controller.loadReferenceCatalogs();
    widget.controller.loadEffectiveCatalog();
    widget.controller.clearSearch();
    _fetchLocationInBackground();
  }

  Future<void> _fetchLocationInBackground() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      if (!mounted) return;
      if (loc != null) {
        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _documentNumber.dispose();
    _firstName.dispose();
    _secondName.dispose();
    _lastName.dispose();
    _secondLastName.dispose();
    _educationLevel.dispose();
    _birthPlace.dispose();
    _gestationalAge.dispose();
    _street.dispose();
    _locality.dispose();
    _landline.dispose();
    _cellphone.dispose();
    _email.dispose();
    _contraindicationDetails.dispose();
    _reactionDetails.dispose();
    _lastMenstrualDate.dispose();
    _previousPregnancies.dispose();
    _birthPlaceDelivery.dispose();
    _guardianDocument.dispose();
    _guardianFirstName.dispose();
    _guardianLastName.dispose();
    _guardianCellphone.dispose();
    _paiwebReason.dispose();
    _observations.dispose();
    super.dispose();
  }

  void _onExistingPatientLoaded(Patient patient) {
    setState(() {
      _isExistingPatient = true;
      _documentType = patient.documentType;
      _documentNumber.text = patient.documentNumber;
      _firstName.text = patient.firstName;
      _secondName.text = patient.secondName ?? '';
      _lastName.text = patient.lastName;
      _secondLastName.text = patient.secondLastName ?? '';
      _birthDate = patient.birthDate;
      _sex = patient.sex.isNotEmpty ? patient.sex : null;
      _birthCountryId = patient.birthCountryId;
      _birthPlace.text = patient.birthPlace ?? '';
      _migrationStatus = patient.migrationStatus ?? 'REGULAR';
      _vaccinationCardType = patient.vaccinationCardType;
      _gestationalAge.text = patient.gestationalAgeAtBirth != null
          ? patient.gestationalAgeAtBirth.toString()
          : '';
    });

    widget.controller.selectPatient(patient);
    widget.controller.loadEffectiveCatalog();

    AppSnackbar.success(context, 'Paciente cargado correctamente.');

    // Brindar opción rápida de ir directamente a vacunas o revisar datos
    _goToStep(2);
  }

  void _goToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
      setState(() => _currentStep = step);
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _handleNext() async {
    // Validación Paso 1
    if (_currentStep == 0) {
      if (!(_step1FormKey.currentState?.validate() ?? false)) {
        return;
      }
      if (_birthDate == null) {
        AppSnackbar.warning(
          context,
          'Seleccione la fecha de nacimiento del paciente.',
        );
        return;
      }
      _goToStep(1);
      return;
    }

    // Validación Paso 2
    if (_currentStep == 1) {
      if (!(_step2FormKey.currentState?.validate() ?? false)) {
        return;
      }
      if (_sex == null || _sex!.isEmpty) {
        AppSnackbar.warning(context, 'Seleccione el sexo del paciente.');
        return;
      }

      // Si no ha cargado el catálogo efectivo, cargarlo antes de pasar al paso 3
      if (!widget.controller.effectiveCatalogLoaded) {
        await widget.controller.loadEffectiveCatalog();
      }

      _goToStep(2);
      return;
    }

    // Validación Paso 3 (Registro de Vacunas)
    if (_currentStep == 2) {
      // Descartar borradores que no fueron confirmados con "Confirmar esta dosis"
      setState(() {
        _stagedDoses.removeWhere((_, dose) => !dose.isCompleted);
      });

      if (_stagedDoses.isEmpty) {
        AppSnackbar.show(
          context,
          'Debes registrar y confirmar al menos una vacuna antes de continuar.',
          type: AppSnackbarType.warning,
        );
        return;
      }
      _goToStep(3);
      return;
    }

    // Paso 4: Confirmación Final
    if (_currentStep == 3) {
      await _submitAttention();
    }
  }

  Future<void> _submitAttention() async {
    if (!_paiwebRegistered && _paiwebReason.text.trim().length < 5) {
      AppSnackbar.warning(
        context,
        'Indica el motivo de no ingreso al aplicativo PAIWEB (mínimo 5 caracteres).',
      );
      return;
    }

    setState(() => _submitting = true);
    widget.onSubmittingChanged?.call(true);

    try {
      // 1. Si es paciente nuevo, registrarlo
      Patient? currentPatient = widget.controller.patient;

      if (!_isExistingPatient || currentPatient == null) {
        final newPatientInput = NewPatientInput(
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
          birthDate: formatIsoDate(_birthDate!),
          sex: _sex ?? 'FEMALE',
          birthCountryId: _birthCountryId,
          birthPlace: _birthPlace.text.trim().isEmpty
              ? null
              : _birthPlace.text.trim(),
          migrationStatus: _migrationStatus,
          vaccinationCardType: _vaccinationCardType,
          gestationalAgeAtBirth: int.tryParse(_gestationalAge.text.trim()),
          authorizeCalls: _authorizeCalls,
          authorizeEmail: _authorizeEmail,
          demographics: NewPatientDemographic(
            gender: _gender,
            ethnicity: _ethnicity,
            sexualOrientation: _sexualOrientation,
            educationLevel: _educationLevel.text.trim().isEmpty
                ? null
                : _educationLevel.text.trim(),
          ),
          affiliation: NewPatientAffiliation(
            affiliationRegime: _affiliationRegime,
            insurer: _selectedInsurer?.name,
            insurerCode: _selectedInsurer?.code,
          ),
          specialConditions: NewPatientSpecialConditions(
            displaced: _displaced,
            disabled: _disabled,
            deceased: _deceased,
            armedConflictVictim: _armedConflictVictim,
            currentlyStudying: _currentlyStudying,
          ),
          medicalHistories: (_hasContraindication || _hasPreviousReaction)
              ? [
                  NewPatientMedicalHistory(
                    condition: 'ANTECEDENTE_CLINICO',
                    hasContraindication: _hasContraindication,
                    contraindicationDetails:
                        _contraindicationDetails.text.trim().isEmpty
                        ? null
                        : _contraindicationDetails.text.trim(),
                    hasPreviousReaction: _hasPreviousReaction,
                    reactionDetails: _reactionDetails.text.trim().isEmpty
                        ? null
                        : _reactionDetails.text.trim(),
                  ),
                ]
              : const [],
          userCondition: _userCondition != null
              ? NewPatientUserCondition(
                  userCondition: _userCondition,
                  lastMenstrualDate: _lastMenstrualDate.text.trim().isEmpty
                      ? null
                      : _lastMenstrualDate.text.trim(),
                  previousPregnancies: int.tryParse(
                    _previousPregnancies.text.trim(),
                  ),
                  birthPlaceDelivery: _birthPlaceDelivery.text.trim().isEmpty
                      ? null
                      : _birthPlaceDelivery.text.trim(),
                )
              : null,
          contacts: [
            if (_cellphone.text.trim().isNotEmpty)
              NewPatientContact(
                type: 'PHONE',
                value: _cellphone.text.trim(),
                phoneKind: 'CELLPHONE',
                primary: true,
              ),
            if (_landline.text.trim().isNotEmpty)
              NewPatientContact(
                type: 'PHONE',
                value: _landline.text.trim(),
                phoneKind: 'LANDLINE',
              ),
            if (_email.text.trim().isNotEmpty)
              NewPatientContact(type: 'EMAIL', value: _email.text.trim()),
          ],
          addresses: [
            if (_street.text.trim().isNotEmpty ||
                _departmentId != null ||
                _municipalityId != null ||
                _locality.text.trim().isNotEmpty ||
                _area != null)
              NewPatientAddress(
                street: _street.text.trim().isEmpty
                    ? null
                    : _street.text.trim(),
                locality: _locality.text.trim().isEmpty
                    ? null
                    : _locality.text.trim(),
                departmentId: _departmentId,
                municipalityId: _municipalityId,
                area: _area,
                primary: true,
              ),
          ],
          guardians: [
            if (_guardianDocument.text.trim().isNotEmpty ||
                _guardianFirstName.text.trim().isNotEmpty)
              NewPatientGuardian(
                relationship: _guardianRelationship,
                fullName:
                    '${_guardianFirstName.text.trim()} ${_guardianLastName.text.trim()}'
                        .trim(),
                documentType: _guardianDocumentType,
                documentNumber: _guardianDocument.text.trim().isEmpty
                    ? null
                    : _guardianDocument.text.trim(),
                cellphone: _guardianCellphone.text.trim().isEmpty
                    ? null
                    : _guardianCellphone.text.trim(),
              ),
          ],
        );

        currentPatient = await widget.controller.registerPatient(
          offline: widget.offline,
          input: newPatientInput,
        );

        if (currentPatient == null) {
          if (!mounted) return;
          AppSnackbar.error(
            context,
            widget.controller.error ?? 'No se pudo crear el paciente.',
          );
          return;
        }
      }

      // 2. Asegurar que existe una atención iniciada para el paciente
      final now = DateTime.now();
      final isAttentionToday = _attentionDate.year == now.year &&
          _attentionDate.month == now.month &&
          _attentionDate.day == now.day;
      final attentionDateIso = isAttentionToday
          ? now.toUtc().toIso8601String()
          : DateTime(
              _attentionDate.year,
              _attentionDate.month,
              _attentionDate.day,
              12,
              0,
              0,
            ).toUtc().toIso8601String();
      final currentAttention = await widget.controller.ensureAttentionStarted(
        offline: widget.offline,
        observations: _observations.text.trim(),
        attentionDate: attentionDateIso,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (currentAttention == null) {
        if (!mounted) return;
        AppSnackbar.error(
          context,
          widget.controller.error ?? 'No se pudo iniciar la atención.',
        );
        return;
      }

      // 3. Registrar cada dosis configurada en borrador (únicamente las confirmadas)
      for (final staged in _stagedDoses.values.where((d) => d.isCompleted)) {
        final isDoseToday = staged.applicationDate.year == now.year &&
            staged.applicationDate.month == now.month &&
            staged.applicationDate.day == now.day;
        final applicationDateIso = isDoseToday
            ? now.toUtc().toIso8601String()
            : DateTime(
                staged.applicationDate.year,
                staged.applicationDate.month,
                staged.applicationDate.day,
                12,
                0,
                0,
              ).toUtc().toIso8601String();

        final doseOk = await widget.controller.addDose(
          offline: widget.offline,
          vaccineId: staged.vaccineId,
          doseOptionId: staged.doseOptionId,
          vaccineName: staged.vaccineName,
          doseLabel: staged.doseDisplayName,
          observations: _observations.text.trim(),
          attentionDate: attentionDateIso,
          latitude: _latitude,
          longitude: _longitude,
          pneumococcalTypeOptionId: staged.pneumococcalTypeOptionId,
          lotNumber: staged.lotNumber,
          applicationDate: applicationDateIso,
          selectedLaboratoryId: staged.selectedLaboratoryId,
          selectedSyringeId: staged.selectedSyringeId,
          selectedDropperId: staged.selectedDropperId,
          selectedObservationId: staged.selectedObservationId,
          syringeLot: staged.syringeLot,
          diluent: staged.diluent,
          vialCount: staged.vialCount,
          customObservation: staged.customObservation,
        );

        if (!doseOk) {
          if (!mounted) return;
          AppSnackbar.error(
            context,
            widget.controller.error ??
                'Error registrando dosis de ${staged.vaccineName}.',
          );
          return;
        }
      }

      // 3. Actualizar detalles de cierre (esquema completo y PAIWEB)
      await widget.controller.updateAttentionDetails(
        offline: widget.offline,
        completeScheme: _completeScheme,
        paiwebRegistered: _paiwebRegistered,
        paiwebNotRegisteredReason: _paiwebRegistered
            ? null
            : _paiwebReason.text.trim(),
        observations: _observations.text.trim(),
      );

      // 4. Completar la atención
      final finished = await widget.controller.finishAttention(
        offline: widget.offline,
      );

      if (!mounted) return;

      if (finished) {
        AppSnackbar.success(
          context,
          OfflineMessages.isOffline(widget.offline)
              ? OfflineMessages.savedAttention
              : 'Atención y vacunas registradas correctamente.',
        );
        _resetForm();
        widget.onFinished?.call();
      } else {
        AppSnackbar.error(
          context,
          widget.controller.error ?? 'No se pudo finalizar la atención.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        widget.onSubmittingChanged?.call(false);
      }
    }
  }

  void _resetForm() {
    widget.controller.resetFlow();
    setState(() {
      _currentStep = 0;
      _attentionDate = DateTime.now();
      _documentType = 'CC';
      _documentNumber.clear();
      _firstName.clear();
      _secondName.clear();
      _lastName.clear();
      _secondLastName.clear();
      _birthDate = null;
      _completeScheme = false;
      _isExistingPatient = false;

      _sex = null;
      _gender = null;
      _sexualOrientation = null;
      _ethnicity = null;
      _educationLevel.clear();
      _birthCountryId = null;
      _birthPlace.clear();
      _migrationStatus = 'REGULAR';
      _vaccinationCardType = null;
      _gestationalAge.clear();
      _affiliationRegime = null;
      _selectedInsurer = null;
      _departmentId = null;
      _municipalityId = null;
      _street.clear();
      _locality.clear();
      _area = null;
      _landline.clear();
      _cellphone.clear();
      _email.clear();
      _authorizeCalls = false;
      _authorizeEmail = false;
      _displaced = false;
      _disabled = false;
      _deceased = false;
      _armedConflictVictim = false;
      _currentlyStudying = false;
      _hasContraindication = false;
      _contraindicationDetails.clear();
      _hasPreviousReaction = false;
      _reactionDetails.clear();
      _userCondition = null;
      _lastMenstrualDate.clear();
      _previousPregnancies.clear();
      _birthPlaceDelivery.clear();
      _guardianRelationship = 'CAREGIVER';
      _guardianDocumentType = 'CC';
      _guardianDocument.clear();
      _guardianFirstName.clear();
      _guardianLastName.clear();
      _guardianCellphone.clear();

      _stagedDoses.clear();
      _paiwebRegistered = true;
      _paiwebReason.clear();
      _observations.clear();
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<bool> _onWillPop() async {
    if (_submitting) return false;
    if (_currentStep > 0) {
      _previousStep();
      return false;
    }

    final hasData =
        _documentNumber.text.isNotEmpty ||
        _firstName.text.isNotEmpty ||
        _lastName.text.isNotEmpty ||
        _stagedDoses.values.any((d) => d.isCompleted);

    if (!hasData) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('¿Cancelar registro?'),
        content: const Text(
          'Si sales ahora se perderán los datos ingresados en este formulario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar registrando'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (discard == true) {
      _resetForm();
      widget.onFinished?.call();
      return true;
    }
    return false;
  }

  String _getDepartmentName(String? id) {
    if (id == null) return '';
    final found = widget.controller.departments.where((d) => d.id == id);
    return found.isNotEmpty ? found.first.name : id;
  }

  String _getMunicipalityName(String? id) {
    if (id == null) return '';
    final found = widget.controller.municipalities.where((m) => m.id == id);
    return found.isNotEmpty ? found.first.name : id;
  }

  String _getCountryName(String? id) {
    if (id == null) return 'Colombia';
    final found = widget.controller.countries.where((c) => c.id == id);
    return found.isNotEmpty ? found.first.name : 'Colombia';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            widget.onFinished?.call();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Indicador de Progreso
            _ProgressIndicator(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),

            // Contenido en PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Paso 1
                  Step1BasicDataStep(
                    formKey: _step1FormKey,
                    controller: widget.controller,
                    offline: widget.offline,
                    attentionDate: _attentionDate,
                    onAttentionDateChanged: (d) =>
                        setState(() => _attentionDate = d),
                    documentType: _documentType,
                    onDocumentTypeChanged: (t) =>
                        setState(() => _documentType = t),
                    documentNumberController: _documentNumber,
                    firstNameController: _firstName,
                    secondNameController: _secondName,
                    lastNameController: _lastName,
                    secondLastNameController: _secondLastName,
                    birthDate: _birthDate,
                    onBirthDateChanged: (b) => setState(() => _birthDate = b),
                    completeScheme: _completeScheme,
                    onCompleteSchemeChanged: (s) =>
                        setState(() => _completeScheme = s),
                    onExistingPatientLoaded: _onExistingPatientLoaded,
                    isExistingPatient: _isExistingPatient,
                  ),

                  // Paso 2
                  Step2AdditionalDataStep(
                    formKey: _step2FormKey,
                    controller: widget.controller,
                    offline: widget.offline,
                    birthDate: _birthDate,
                    sex: _sex,
                    onSexChanged: (val) => setState(() => _sex = val),
                    gender: _gender,
                    onGenderChanged: (val) => setState(() => _gender = val),
                    sexualOrientation: _sexualOrientation,
                    onSexualOrientationChanged: (val) =>
                        setState(() => _sexualOrientation = val),
                    ethnicity: _ethnicity,
                    onEthnicityChanged: (val) =>
                        setState(() => _ethnicity = val),
                    educationLevelController: _educationLevel,
                    birthCountryId: _birthCountryId,
                    onBirthCountryChanged: (val) =>
                        setState(() => _birthCountryId = val),
                    birthPlaceController: _birthPlace,
                    migrationStatus: _migrationStatus,
                    onMigrationStatusChanged: (val) =>
                        setState(() => _migrationStatus = val),
                    vaccinationCardType: _vaccinationCardType,
                    onVaccinationCardTypeChanged: (val) =>
                        setState(() => _vaccinationCardType = val),
                    gestationalAgeController: _gestationalAge,
                    affiliationRegime: _affiliationRegime,
                    onAffiliationRegimeChanged: (val) =>
                        setState(() => _affiliationRegime = val),
                    selectedInsurer: _selectedInsurer,
                    onInsurerChanged: (val) =>
                        setState(() => _selectedInsurer = val),
                    departmentId: _departmentId,
                    onDepartmentChanged: (val) => setState(() {
                      _departmentId = val;
                      _municipalityId = null;
                    }),
                    municipalityId: _municipalityId,
                    onMunicipalityChanged: (val) =>
                        setState(() => _municipalityId = val),
                    streetController: _street,
                    localityController: _locality,
                    area: _area,
                    onAreaChanged: (val) => setState(() => _area = val),
                    landlineController: _landline,
                    cellphoneController: _cellphone,
                    emailController: _email,
                    authorizeCalls: _authorizeCalls,
                    onAuthorizeCallsChanged: (val) =>
                        setState(() => _authorizeCalls = val),
                    authorizeEmail: _authorizeEmail,
                    onAuthorizeEmailChanged: (val) =>
                        setState(() => _authorizeEmail = val),
                    displaced: _displaced,
                    onDisplacedChanged: (val) =>
                        setState(() => _displaced = val),
                    disabled: _disabled,
                    onDisabledChanged: (val) => setState(() => _disabled = val),
                    deceased: _deceased,
                    onDeceasedChanged: (val) => setState(() => _deceased = val),
                    armedConflictVictim: _armedConflictVictim,
                    onArmedConflictVictimChanged: (val) =>
                        setState(() => _armedConflictVictim = val),
                    currentlyStudying: _currentlyStudying,
                    onCurrentlyStudyingChanged: (val) =>
                        setState(() => _currentlyStudying = val),
                    hasContraindication: _hasContraindication,
                    onHasContraindicationChanged: (val) =>
                        setState(() => _hasContraindication = val),
                    contraindicationDetailsController: _contraindicationDetails,
                    hasPreviousReaction: _hasPreviousReaction,
                    onHasPreviousReactionChanged: (val) =>
                        setState(() => _hasPreviousReaction = val),
                    reactionDetailsController: _reactionDetails,
                    userCondition: _userCondition,
                    onUserConditionChanged: (val) =>
                        setState(() => _userCondition = val),
                    lastMenstrualDateController: _lastMenstrualDate,
                    previousPregnanciesController: _previousPregnancies,
                    birthPlaceDeliveryController: _birthPlaceDelivery,
                    guardianRelationship: _guardianRelationship,
                    onGuardianRelationshipChanged: (val) =>
                        setState(() => _guardianRelationship = val),
                    guardianDocumentType: _guardianDocumentType,
                    onGuardianDocumentTypeChanged: (val) =>
                        setState(() => _guardianDocumentType = val),
                    guardianDocumentController: _guardianDocument,
                    guardianFirstNameController: _guardianFirstName,
                    guardianLastNameController: _guardianLastName,
                    guardianCellphoneController: _guardianCellphone,
                  ),

                  // Paso 3
                  Step3VaccinesStep(
                    controller: widget.controller,
                    offline: widget.offline,
                    attentionDate: _attentionDate,
                    birthDate: _birthDate,
                    sex: _sex,
                    userCondition: _userCondition,
                    ethnicity: _ethnicity,
                    area: _area,
                    displaced: _displaced,
                    stagedDoses: _stagedDoses,
                    onStagedDoseChanged: (dose) {
                      setState(() {
                        final key = '${dose.vaccineId}_${dose.doseOptionId}';
                        _stagedDoses[key] = dose;
                      });
                    },
                    onStagedDoseRemoved: (key) {
                      setState(() {
                        _stagedDoses.remove(key);
                      });
                    },
                  ),

                  // Paso 4
                  Step4ReviewStep(
                    attentionDate: _attentionDate,
                    documentType: _documentType,
                    documentNumber: _documentNumber.text.trim(),
                    firstName: _firstName.text.trim(),
                    secondName: _secondName.text.trim(),
                    lastName: _lastName.text.trim(),
                    secondLastName: _secondLastName.text.trim(),
                    birthDate: _birthDate,
                    completeScheme: _completeScheme,
                    sex: _sex,
                    birthCountryName: _getCountryName(_birthCountryId),
                    birthPlace: _birthPlace.text.trim(),
                    departmentName: _getDepartmentName(_departmentId),
                    municipalityName: _getMunicipalityName(_municipalityId),
                    address: [
                      _street.text.trim(),
                      _locality.text.trim(),
                    ].where((s) => s.isNotEmpty).join(', '),
                    affiliationRegime: _affiliationRegime,
                    selectedInsurer: _selectedInsurer,
                    vaccinationCardType: _vaccinationCardType,
                    cellphone: _cellphone.text.trim(),
                    email: _email.text.trim(),
                    stagedDoses: _stagedDoses.values
                        .where((d) => d.isCompleted)
                        .toList(),
                    paiwebRegistered: _paiwebRegistered,
                    onPaiwebRegisteredChanged: (val) =>
                        setState(() => _paiwebRegistered = val),
                    paiwebReasonController: _paiwebReason,
                    observationsController: _observations,
                    latitude: _latitude,
                    longitude: _longitude,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomNavigation(
          currentStep: _currentStep,
          totalSteps: _totalSteps,
          submitting: _submitting,
          onPrevious: _previousStep,
          onNext: _handleNext,
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Registro de Vacunación',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Paso ${currentStep + 1} de $totalSteps',
                style: const TextStyle(
                  color: AppColors.slate,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.currentStep,
    required this.totalSteps,
    required this.submitting,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentStep;
  final int totalSteps;
  final bool submitting;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLastStep = currentStep == totalSteps - 1;
    final showBack = currentStep > 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (showBack) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: submitting ? null : onPrevious,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Anterior'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: showBack ? 2 : 1,
                child: ElevatedButton(
                  onPressed: submitting ? null : onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLastStep ? 'Confirmar Atención' : 'Siguiente',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLastStep
                                  ? Icons.check_circle_rounded
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
      ),
    );
  }
}
