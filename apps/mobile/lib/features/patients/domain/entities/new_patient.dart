/// Datos de contacto del alta de paciente.
class NewPatientContact {
  const NewPatientContact({
    required this.type,
    required this.value,
    this.primary = false,
  });

  final String type;
  final String value;
  final bool primary;
}

/// Direccion del alta de paciente (pais fijo Colombia).
class NewPatientAddress {
  const NewPatientAddress({
    this.street,
    this.departmentId,
    this.municipalityId,
    this.primary = true,
  });

  final String? street;
  final String? departmentId;
  final String? municipalityId;
  final bool primary;

  bool get isEmpty =>
      (street == null || street!.isEmpty) &&
      (departmentId == null || departmentId!.isEmpty) &&
      (municipalityId == null || municipalityId!.isEmpty);
}

/// Acompañante / tutor del alta de paciente.
class NewPatientGuardian {
  const NewPatientGuardian({
    required this.relationship,
    required this.fullName,
    this.documentType,
    this.documentNumber,
    this.phone,
  });

  final String relationship;
  final String fullName;
  final String? documentType;
  final String? documentNumber;
  final String? phone;
}

/// Antecedente medico del alta de paciente.
class NewPatientMedicalHistory {
  const NewPatientMedicalHistory({
    required this.condition,
    this.diagnosedAt,
    this.notes,
  });

  final String condition;
  final String? diagnosedAt;
  final String? notes;
}

/// Datos demograficos del alta de paciente (opcionales).
class NewPatientDemographic {
  const NewPatientDemographic({
    this.gender,
    this.ethnicity,
    this.educationLevel,
  });

  final String? gender;
  final String? ethnicity;
  final String? educationLevel;

  bool get isEmpty =>
      (gender == null || gender!.isEmpty) &&
      (ethnicity == null || ethnicity!.isEmpty) &&
      (educationLevel == null || educationLevel!.isEmpty);
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
    this.demographics,
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
  final NewPatientDemographic? demographics;
  final List<NewPatientContact> contacts;
  final List<NewPatientAddress> addresses;
  final List<NewPatientGuardian> guardians;
  final List<NewPatientMedicalHistory> medicalHistories;
}
