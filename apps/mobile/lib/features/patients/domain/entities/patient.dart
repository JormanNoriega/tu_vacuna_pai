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
  });

  final String id;
  final String documentType;
  final String documentNumber;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final String sex;
  final String status;

  String get fullName => '$firstName $lastName'.trim();

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
    id: json['id'].toString(),
    documentType: json['documentType'] as String,
    documentNumber: json['documentNumber'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    birthDate: json['birthDate'] == null
        ? null
        : DateTime.tryParse(json['birthDate'] as String),
    sex: json['sex'] as String? ?? '',
    status: json['status'] as String? ?? 'ACTIVE',
  );
}
