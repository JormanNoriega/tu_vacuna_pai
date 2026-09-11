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
  });

  final Patient patient;
  final PatientDemographics? demographics;
  final List<PatientContact> contacts;
  final List<PatientAddress> addresses;
  final List<PatientGuardian> guardians;
  final List<PatientMedicalHistory> medicalHistories;

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
  );

  static List<T> _list<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) => ((raw as List<dynamic>?) ?? const [])
      .map((item) => fromJson(item as Map<String, dynamic>))
      .toList();
}

class PatientDemographics {
  const PatientDemographics({this.gender, this.ethnicity, this.educationLevel});

  final String? gender;
  final String? ethnicity;
  final String? educationLevel;

  factory PatientDemographics.fromJson(Map<String, dynamic> json) =>
      PatientDemographics(
        gender: json['gender'] as String?,
        ethnicity: json['ethnicity'] as String?,
        educationLevel: json['educationLevel'] as String?,
      );
}

class PatientContact {
  const PatientContact({
    required this.id,
    required this.type,
    required this.value,
    required this.primary,
  });

  final String id;
  final String type;
  final String value;
  final bool primary;

  factory PatientContact.fromJson(Map<String, dynamic> json) => PatientContact(
    id: json['id'].toString(),
    type: json['type'] as String,
    value: json['value'] as String,
    primary: json['primary'] as bool? ?? json['isPrimary'] as bool? ?? false,
  );
}

class PatientAddress {
  const PatientAddress({
    required this.id,
    this.street,
    this.departmentId,
    this.municipalityId,
    this.primary = false,
  });

  final String id;
  final String? street;
  final String? departmentId;
  final String? municipalityId;
  final bool primary;

  factory PatientAddress.fromJson(Map<String, dynamic> json) => PatientAddress(
    id: json['id'].toString(),
    street: json['street'] as String?,
    departmentId: json['departmentId']?.toString(),
    municipalityId: json['municipalityId']?.toString(),
    primary: json['primary'] as bool? ?? json['isPrimary'] as bool? ?? false,
  );
}

class PatientGuardian {
  const PatientGuardian({
    required this.id,
    required this.relationship,
    required this.fullName,
    this.documentType,
    this.documentNumber,
    this.phone,
  });

  final String id;
  final String relationship;
  final String fullName;
  final String? documentType;
  final String? documentNumber;
  final String? phone;

  factory PatientGuardian.fromJson(Map<String, dynamic> json) =>
      PatientGuardian(
        id: json['id'].toString(),
        relationship: json['relationship'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        documentType: json['documentType'] as String?,
        documentNumber: json['documentNumber'] as String?,
        phone: json['phone'] as String?,
      );
}

class PatientMedicalHistory {
  const PatientMedicalHistory({
    required this.id,
    required this.condition,
    this.diagnosedAt,
    this.notes,
  });

  final String id;
  final String condition;
  final DateTime? diagnosedAt;
  final String? notes;

  factory PatientMedicalHistory.fromJson(Map<String, dynamic> json) =>
      PatientMedicalHistory(
        id: json['id'].toString(),
        condition: json['condition'] as String? ?? '',
        diagnosedAt: json['diagnosedAt'] == null
            ? null
            : DateTime.tryParse(json['diagnosedAt'] as String),
        notes: json['notes'] as String?,
      );
}
