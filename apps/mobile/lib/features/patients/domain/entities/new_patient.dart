/// Datos de contacto del alta de paciente.
class NewPatientContact {
  const NewPatientContact({
    required this.type,
    required this.value,
    this.phoneKind,
    this.primary = false,
  });

  final String type;
  final String value;

  /// `LANDLINE` (fijo) o `CELLPHONE` (celular). Aplica cuando [type] es
  /// `PHONE`.
  final String? phoneKind;
  final bool primary;
}

/// Direccion del alta de paciente.
class NewPatientAddress {
  const NewPatientAddress({
    this.street,
    this.departmentId,
    this.municipalityId,
    this.countryId,
    this.locality,
    this.area,
    this.primary = true,
  });

  final String? street;
  final String? departmentId;
  final String? municipalityId;
  final String? countryId;
  final String? locality;
  final String? area;
  final bool primary;

  bool get isEmpty =>
      (street == null || street!.isEmpty) &&
      (departmentId == null || departmentId!.isEmpty) &&
      (municipalityId == null || municipalityId!.isEmpty) &&
      (countryId == null || countryId!.isEmpty) &&
      (locality == null || locality!.isEmpty) &&
      (area == null || area!.isEmpty);
}

/// Acompañante / tutor del alta de paciente.
class NewPatientGuardian {
  const NewPatientGuardian({
    required this.relationship,
    required this.fullName,
    this.secondName,
    this.secondLastName,
    this.documentType,
    this.documentNumber,
    this.phone,
    this.landline,
    this.cellphone,
    this.email,
    this.affiliationRegime,
    this.insurer,
    this.ethnicity,
    this.displaced,
  });

  final String relationship;
  final String fullName;
  final String? secondName;
  final String? secondLastName;
  final String? documentType;
  final String? documentNumber;
  final String? phone;
  final String? landline;
  final String? cellphone;
  final String? email;
  final String? affiliationRegime;
  final String? insurer;
  final String? ethnicity;
  final bool? displaced;
}

/// Antecedente medico del alta de paciente.
class NewPatientMedicalHistory {
  const NewPatientMedicalHistory({
    required this.condition,
    this.diagnosedAt,
    this.notes,
    this.hasContraindication,
    this.contraindicationDetails,
    this.hasPreviousReaction,
    this.reactionDetails,
    this.historyType,
    this.specialObservations,
  });

  final String condition;
  final String? diagnosedAt;
  final String? notes;
  final bool? hasContraindication;
  final String? contraindicationDetails;
  final bool? hasPreviousReaction;
  final String? reactionDetails;
  final String? historyType;
  final String? specialObservations;
}

/// Datos demograficos del alta de paciente (opcionales).
class NewPatientDemographic {
  const NewPatientDemographic({
    this.gender,
    this.ethnicity,
    this.sexualOrientation,
    this.educationLevel,
  });

  final String? gender;
  final String? ethnicity;
  final String? sexualOrientation;
  final String? educationLevel;

  bool get isEmpty =>
      (gender == null || gender!.isEmpty) &&
      (ethnicity == null || ethnicity!.isEmpty) &&
      (sexualOrientation == null || sexualOrientation!.isEmpty) &&
      (educationLevel == null || educationLevel!.isEmpty);
}

/// Afiliacion en salud del alta de paciente.
class NewPatientAffiliation {
  const NewPatientAffiliation({this.affiliationRegime, this.insurer});

  final String? affiliationRegime;
  final String? insurer;

  bool get isEmpty =>
      (affiliationRegime == null || affiliationRegime!.isEmpty) &&
      (insurer == null || insurer!.isEmpty);
}

/// Condiciones especiales (poblaciones) del alta de paciente.
class NewPatientSpecialConditions {
  const NewPatientSpecialConditions({
    this.displaced,
    this.disabled,
    this.deceased,
    this.armedConflictVictim,
    this.currentlyStudying,
  });

  final bool? displaced;
  final bool? disabled;
  final bool? deceased;
  final bool? armedConflictVictim;
  final bool? currentlyStudying;

  bool get isEmpty =>
      displaced == null &&
      disabled == null &&
      deceased == null &&
      armedConflictVictim == null &&
      currentlyStudying == null;
}

/// Condicion obstetrica / de la usuaria del alta de paciente.
class NewPatientUserCondition {
  const NewPatientUserCondition({
    this.userCondition,
    this.lastMenstrualDate,
    this.gestationWeeks,
    this.probableDeliveryDate,
    this.previousPregnancies,
    this.hasGivenBirth,
    this.birthPlaceDelivery,
  });

  final String? userCondition;
  final String? lastMenstrualDate;
  final int? gestationWeeks;
  final String? probableDeliveryDate;
  final int? previousPregnancies;
  final bool? hasGivenBirth;
  final String? birthPlaceDelivery;

  bool get isEmpty =>
      (userCondition == null || userCondition!.isEmpty) &&
      lastMenstrualDate == null &&
      gestationWeeks == null &&
      probableDeliveryDate == null &&
      previousPregnancies == null &&
      hasGivenBirth == null &&
      (birthPlaceDelivery == null || birthPlaceDelivery!.isEmpty);
}

/// Alta completa de un paciente capturada por el wizard. Solo la identidad es
/// obligatoria; el resto del perfil es opcional.
class NewPatientInput {
  const NewPatientInput({
    required this.documentType,
    required this.documentNumber,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.sex,
    this.secondName,
    this.secondLastName,
    this.birthCountryId,
    this.birthPlace,
    this.migrationStatus,
    this.gestationalAgeAtBirth,
    this.vaccinationCardType,
    this.authorizeCalls,
    this.authorizeEmail,
    this.demographics,
    this.affiliation,
    this.specialConditions,
    this.userCondition,
    this.contacts = const [],
    this.addresses = const [],
    this.guardians = const [],
    this.medicalHistories = const [],
  });

  final String documentType;
  final String documentNumber;
  final String firstName;
  final String lastName;

  /// Fecha en formato ISO (yyyy-MM-dd).
  final String birthDate;
  final String sex;

  final String? secondName;
  final String? secondLastName;
  final String? birthCountryId;
  final String? birthPlace;
  final String? migrationStatus;
  final int? gestationalAgeAtBirth;
  final String? vaccinationCardType;
  final bool? authorizeCalls;
  final bool? authorizeEmail;
  final NewPatientDemographic? demographics;
  final NewPatientAffiliation? affiliation;
  final NewPatientSpecialConditions? specialConditions;
  final NewPatientUserCondition? userCondition;
  final List<NewPatientContact> contacts;
  final List<NewPatientAddress> addresses;
  final List<NewPatientGuardian> guardians;
  final List<NewPatientMedicalHistory> medicalHistories;
}
