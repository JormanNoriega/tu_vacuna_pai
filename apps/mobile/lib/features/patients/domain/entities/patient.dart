/// Paciente dentro del alcance de la institucion del usuario autenticado.
class Patient {
  const Patient({
    required this.id,
    required this.documentType,
    required this.documentNumber,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.sex,
    required this.status,
    this.secondName,
    this.secondLastName,
    this.birthCountryId,
    this.birthPlace,
    this.migrationStatus,
    this.gestationalAgeAtBirth,
    this.vaccinationCardType,
    this.authorizeCalls = false,
    this.authorizeEmail = false,
  });

  final String id;
  final String documentType;
  final String documentNumber;
  final String firstName;
  final String? secondName;
  final String lastName;
  final String? secondLastName;
  final DateTime? birthDate;
  final String sex;
  final String status;
  final String? birthCountryId;
  final String? birthPlace;
  final String? migrationStatus;
  final int? gestationalAgeAtBirth;
  final String? vaccinationCardType;
  final bool authorizeCalls;
  final bool authorizeEmail;

  String get fullName => [
    firstName,
    secondName,
    lastName,
    secondLastName,
  ].where((part) => part != null && part.trim().isNotEmpty).join(' ').trim();

  /// Edad en anos cumplidos, o null si no hay fecha de nacimiento.
  int? get ageYears {
    final birth = birthDate;
    if (birth == null) return null;
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
    id: json['id'].toString(),
    documentType: json['documentType'] as String,
    documentNumber: json['documentNumber'] as String,
    firstName: json['firstName'] as String,
    secondName: json['secondName'] as String?,
    lastName: json['lastName'] as String,
    secondLastName: json['secondLastName'] as String?,
    birthDate: json['birthDate'] == null
        ? null
        : DateTime.tryParse(json['birthDate'] as String),
    sex: json['sex'] as String? ?? '',
    status: json['status'] as String? ?? 'ACTIVE',
    birthCountryId: json['birthCountryId']?.toString(),
    birthPlace: json['birthPlace'] as String?,
    migrationStatus: json['migrationStatus'] as String?,
    gestationalAgeAtBirth: (json['gestationalAgeAtBirth'] as num?)?.toInt(),
    vaccinationCardType: json['vaccinationCardType'] as String?,
    authorizeCalls: json['authorizeCalls'] as bool? ?? false,
    authorizeEmail: json['authorizeEmail'] as bool? ?? false,
  );
}
