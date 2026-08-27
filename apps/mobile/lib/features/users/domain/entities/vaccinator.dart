/// Usuario vacunador (VACCINATOR) de una institucion.
class Vaccinator {
  const Vaccinator({
    required this.id,
    required this.email,
    required this.fullName,
    required this.institutionId,
    required this.roles,
    required this.status,
    this.documentType,
    this.documentNumber,
    this.phone,
    this.birthDate,
    this.gender,
    this.professionCode,
    this.professionalRegistrationNumber,
    this.professionalRegistrationType,
  });

  factory Vaccinator.fromJson(Map<String, dynamic> json) {
    return Vaccinator(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      institutionId: json['institutionId'] as String,
      roles: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
      status: json['status'] as String,
      documentType: json['documentType'] as String?,
      documentNumber: json['documentNumber'] as String?,
      phone: json['phone'] as String?,
      birthDate: json['birthDate'] as String?,
      gender: json['gender'] as String?,
      professionCode: json['professionCode'] as String?,
      professionalRegistrationNumber:
          json['professionalRegistrationNumber'] as String?,
      professionalRegistrationType:
          json['professionalRegistrationType'] as String?,
    );
  }

  final String id;
  final String email;
  final String fullName;
  final String institutionId;
  final List<String> roles;
  final String status;
  final String? documentType;
  final String? documentNumber;
  final String? phone;
  final String? birthDate;
  final String? gender;
  final String? professionCode;
  final String? professionalRegistrationNumber;
  final String? professionalRegistrationType;

  bool get isActive => status == 'ACTIVE';
}