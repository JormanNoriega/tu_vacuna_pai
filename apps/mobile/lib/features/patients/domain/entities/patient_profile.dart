import 'patient.dart';

/// Perfil completo de un paciente (`GET /patients/{id}`), con sus tablas hijas.
class PatientProfile {
  const PatientProfile({
    required this.patient,
    this.demographics,
    this.contacts = const [],
    this.addresses = const [],
    this.guardians = const [],
    this.medicalHistories = const [],
    this.affiliation,
    this.specialConditions,
    this.userCondition,
  });

  final Patient patient;
  final PatientDemographics? demographics;
  final List<PatientContact> contacts;
  final List<PatientAddress> addresses;
  final List<PatientGuardian> guardians;
  final List<PatientMedicalHistory> medicalHistories;
  final PatientAffiliation? affiliation;
  final PatientSpecialConditions? specialConditions;
  final PatientUserCondition? userCondition;

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
    patient: Patient.fromJson(json),
    demographics: json['demographics'] == null
        ? null
        : PatientDemographics.fromJson(
            json['demographics'] as Map<String, dynamic>,
          ),
    contacts: _list(json['contacts'], PatientContact.fromJson),
    addresses: _list(json['addresses'], PatientAddress.fromJson),
    guardians: _list(json['guardians'], PatientGuardian.fromJson),
    medicalHistories: _list(
      json['medicalHistories'],
      PatientMedicalHistory.fromJson,
    ),
    affiliation: json['affiliation'] == null
        ? null
        : PatientAffiliation.fromJson(
            json['affiliation'] as Map<String, dynamic>,
          ),
    specialConditions: json['specialConditions'] == null
        ? null
        : PatientSpecialConditions.fromJson(
            json['specialConditions'] as Map<String, dynamic>,
          ),
    userCondition: json['userCondition'] == null
        ? null
        : PatientUserCondition.fromJson(
            json['userCondition'] as Map<String, dynamic>,
          ),
  );

  static List<T> _list<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) => ((raw as List<dynamic>?) ?? const [])
      .map((item) => fromJson(item as Map<String, dynamic>))
      .toList();
}

class PatientDemographics {
  const PatientDemographics({
    this.gender,
    this.ethnicity,
    this.sexualOrientation,
    this.educationLevel,
  });

  final String? gender;
  final String? ethnicity;
  final String? sexualOrientation;
  final String? educationLevel;

  factory PatientDemographics.fromJson(Map<String, dynamic> json) =>
      PatientDemographics(
        gender: json['gender'] as String?,
        ethnicity: json['ethnicity'] as String?,
        sexualOrientation: json['sexualOrientation'] as String?,
        educationLevel: json['educationLevel'] as String?,
      );
}

class PatientContact {
  const PatientContact({
    required this.id,
    required this.type,
    required this.value,
    required this.primary,
    this.phoneKind,
  });

  final String id;
  final String type;
  final String value;
  final bool primary;
  final String? phoneKind;

  factory PatientContact.fromJson(Map<String, dynamic> json) => PatientContact(
    id: json['id'].toString(),
    type: json['type'] as String,
    value: json['value'] as String,
    primary: json['primary'] as bool? ?? json['isPrimary'] as bool? ?? false,
    phoneKind: json['phoneKind'] as String?,
  );
}

class PatientAddress {
  const PatientAddress({
    required this.id,
    this.street,
    this.departmentId,
    this.municipalityId,
    this.countryId,
    this.locality,
    this.area,
    this.primary = false,
  });

  final String id;
  final String? street;
  final String? departmentId;
  final String? municipalityId;
  final String? countryId;
  final String? locality;
  final String? area;
  final bool primary;

  factory PatientAddress.fromJson(Map<String, dynamic> json) => PatientAddress(
    id: json['id'].toString(),
    street: json['street'] as String?,
    departmentId: json['departmentId']?.toString(),
    municipalityId: json['municipalityId']?.toString(),
    countryId: json['countryId']?.toString(),
    locality: json['locality'] as String?,
    area: json['area'] as String?,
    primary: json['primary'] as bool? ?? json['isPrimary'] as bool? ?? false,
  );
}

class PatientGuardian {
  const PatientGuardian({
    required this.id,
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
    this.insurerCode,
    this.ethnicity,
    this.displaced,
  });

  final String id;
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
  final String? insurerCode;
  final String? ethnicity;
  final bool? displaced;

  factory PatientGuardian.fromJson(Map<String, dynamic> json) =>
      PatientGuardian(
        id: json['id'].toString(),
        relationship: json['relationship'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        secondName: json['secondName'] as String?,
        secondLastName: json['secondLastName'] as String?,
        documentType: json['documentType'] as String?,
        documentNumber: json['documentNumber'] as String?,
        phone: json['phone'] as String?,
        landline: json['landline'] as String?,
        cellphone: json['cellphone'] as String?,
        email: json['email'] as String?,
        affiliationRegime: json['affiliationRegime'] as String?,
        insurer: json['insurer'] as String?,
        insurerCode: json['insurerCode'] as String?,
        ethnicity: json['ethnicity'] as String?,
        displaced: json['displaced'] as bool?,
      );
}

class PatientMedicalHistory {
  const PatientMedicalHistory({
    required this.id,
    required this.condition,
    this.diagnosedAt,
    this.notes,
    this.hasContraindication = false,
    this.contraindicationDetails,
    this.hasPreviousReaction = false,
    this.reactionDetails,
    this.historyType,
    this.specialObservations,
  });

  final String id;
  final String condition;
  final DateTime? diagnosedAt;
  final String? notes;
  final bool hasContraindication;
  final String? contraindicationDetails;
  final bool hasPreviousReaction;
  final String? reactionDetails;
  final String? historyType;
  final String? specialObservations;

  factory PatientMedicalHistory.fromJson(Map<String, dynamic> json) =>
      PatientMedicalHistory(
        id: json['id'].toString(),
        condition: json['condition'] as String? ?? '',
        diagnosedAt: json['diagnosedAt'] == null
            ? null
            : DateTime.tryParse(json['diagnosedAt'] as String),
        notes: json['notes'] as String?,
        hasContraindication: json['hasContraindication'] as bool? ?? false,
        contraindicationDetails: json['contraindicationDetails'] as String?,
        hasPreviousReaction: json['hasPreviousReaction'] as bool? ?? false,
        reactionDetails: json['reactionDetails'] as String?,
        historyType: json['historyType'] as String?,
        specialObservations: json['specialObservations'] as String?,
      );
}

class PatientAffiliation {
  const PatientAffiliation({
    this.affiliationRegime,
    this.insurer,
    this.insurerCode,
  });

  final String? affiliationRegime;
  final String? insurer;
  final String? insurerCode;

  factory PatientAffiliation.fromJson(Map<String, dynamic> json) =>
      PatientAffiliation(
        affiliationRegime: json['affiliationRegime'] as String?,
        insurer: json['insurer'] as String?,
        insurerCode: json['insurerCode'] as String?,
      );
}

class PatientSpecialConditions {
  const PatientSpecialConditions({
    this.displaced = false,
    this.disabled = false,
    this.deceased = false,
    this.armedConflictVictim = false,
    this.currentlyStudying,
  });

  final bool displaced;
  final bool disabled;
  final bool deceased;
  final bool armedConflictVictim;
  final bool? currentlyStudying;

  factory PatientSpecialConditions.fromJson(Map<String, dynamic> json) =>
      PatientSpecialConditions(
        displaced: json['displaced'] as bool? ?? false,
        disabled: json['disabled'] as bool? ?? false,
        deceased: json['deceased'] as bool? ?? false,
        armedConflictVictim: json['armedConflictVictim'] as bool? ?? false,
        currentlyStudying: json['currentlyStudying'] as bool?,
      );
}

class PatientUserCondition {
  const PatientUserCondition({
    this.userCondition,
    this.lastMenstrualDate,
    this.gestationWeeks,
    this.probableDeliveryDate,
    this.previousPregnancies,
    this.hasGivenBirth,
    this.birthPlaceDelivery,
  });

  final String? userCondition;
  final DateTime? lastMenstrualDate;
  final int? gestationWeeks;
  final DateTime? probableDeliveryDate;
  final int? previousPregnancies;
  final bool? hasGivenBirth;
  final String? birthPlaceDelivery;

  factory PatientUserCondition.fromJson(Map<String, dynamic> json) =>
      PatientUserCondition(
        userCondition: json['userCondition'] as String?,
        lastMenstrualDate: json['lastMenstrualDate'] == null
            ? null
            : DateTime.tryParse(json['lastMenstrualDate'] as String),
        gestationWeeks: (json['gestationWeeks'] as num?)?.toInt(),
        probableDeliveryDate: json['probableDeliveryDate'] == null
            ? null
            : DateTime.tryParse(json['probableDeliveryDate'] as String),
        previousPregnancies: (json['previousPregnancies'] as num?)?.toInt(),
        hasGivenBirth: json['hasGivenBirth'] as bool?,
        birthPlaceDelivery: json['birthPlaceDelivery'] as String?,
      );
}
